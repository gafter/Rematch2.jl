#
# A data structure representing information about a match case in one
# state of the decision automaton for a @match block statement.
# Given a statement
#
# @match expression begin
#     pattern => result
#     ....
# end
#
# The bound pattern represents the remaining operations needed to
# decide if the pattern matches.
#
struct CasePartialResult
    # The index of the case, starting with 1 for the first => in the @match
    case_number::Int

    # Its location for error reporting purposes
    location::LineNumberNode

    # Its source for error reporting
    pattern_source

    # The set of remaining operations required to perform the match.
    # In this state, some operations may have already been done, and they
    # are removed from the bound pattern.  When the bound pattern is simply
    # `true`, it has matched.
    pattern::BoundPattern

    # The set of user variables to assign when the match succeeds;
    # they might be used in the result expression.
    assigned::ImmutableDict{Symbol, Symbol}

    # The user's result expression for this case.
    result_expression::Any

    _cached_hash::UInt64
    function CasePartialResult(
        case_number::Int,
        location::LineNumberNode,
        pattern_source,
        pattern::BoundPattern,
        assigned::ImmutableDict{Symbol, Symbol},
        result_expression::Any)
        _hash = hash((case_number, pattern, assigned), 0x1cdd9657bfb1e645)
        new(case_number, location, pattern_source, pattern, assigned, result_expression, _hash)
    end
end
function with_pattern(
    case::CasePartialResult,
    new_pattern::BoundPattern)
    CasePartialResult(
        case.case_number,
        case.location,
        case.pattern_source,
        new_pattern,
        case.assigned,
        case.result_expression)
end
function Base.hash(case::CasePartialResult, h::UInt64)
    hash(case._cached_hash, h)
end
Base.hash(case::CasePartialResult) = case._cached_hash
function Base.:(==)(a::CasePartialResult, b::CasePartialResult)
    a._cached_hash == b._cached_hash &&
    isequal(a.case_number, b.case_number) &&
        isequal(a.pattern, b.pattern) &&
        isequal(a.assigned, b.assigned)
end
function pretty(io::IO, case::CasePartialResult, state::BinderState)
    print(io, case.case_number, ": ")
    pretty(io, case.pattern, state)
    print(io, " => ")
    pretty(io, case.result_expression)
    println(io)
end

abstract type AbstractCodePoint end

#
# A state of the decision automaton (i.e. a point in the generated code),
# which is represented a set of partially matched cases.
#
mutable struct CodePoint <: AbstractCodePoint
    # The state of the cases.  Impossible cases, which are designated by a
    # `false` `bound_pattern`, are removed from this array.  Cases are always
    # ordered by `case_number`.
    @_const cases::ImmutableVector{CasePartialResult}

    # The selected action to take from this state: either
    # - Nothing, before it has been computed, or
    # - Case whose tests have all passed, or
    # - A bound pattern to perform and then move on to the next state, or
    # - An Expr to insert into the code when all else is exhausted
    #   (which throws MatchFailure)
    action::Union{Nothing, CasePartialResult, BoundPattern, Expr}

    # The next code point(s):
    # - Nothing before being computed
    # - Tuple{} if the action is a case which was matched or a MatchFailure
    # - Tuple{CodePoint} if the action was a fetch pattern. It designates
    #   the code to perform after the fetch.
    # - Tuple{CodePoint, CodePoint} if the action is a test.  These are the states
    #   to go to if the result of the test is true ([1]) or false ([2]).
    next::Union{Nothing, Tuple{}, Tuple{CodePoint}, Tuple{CodePoint, CodePoint}}

    @_const _cached_hash::UInt64

    function CodePoint(cases::Vector{CasePartialResult})
        new(ImmutableVector(cases), nothing, nothing, hash(cases, 0xc98a9a23c2d4d915))
    end
end
Base.hash(case::CodePoint, h::UInt64) = hash(case._cached_hash, h)
function Base.:(==)(a::CodePoint, b::CodePoint)
    a === b ||
        a._cached_hash == b._cached_hash &&
        isequal(a.cases, b.cases)
end
function with_cases(code::CodePoint, cases::Vector{CasePartialResult})
    cases = filter(case -> !(case.pattern isa BoundFalsePattern), cases)
    for i in eachindex(cases)
        if is_irrefutable(cases[i].pattern)
            cases = cases[1:i]
            break
        end
    end
    CodePoint(cases)
end
function name(code::T, id::IdDict{T, Int}) where { T <: AbstractCodePoint }
    "State $(id[code])"
end
function successors(c::T)::Vector{T} where { T <: AbstractCodePoint }
    @assert !(c.next isa Nothing)
    collect(c.next)
end
function reachable_states(root::T)::Vector{T} where { T <: AbstractCodePoint}
    topological_sort(successors, [root])
end

#
# Support for pretty-printing
#
function dumpall(io::IO, all::Vector{T}, state::BinderState, long::Bool) where { T <: AbstractCodePoint }
    long = long && T <: CodePoint

    # Make a map from each CodePoint to its index
    id = IdDict{T, Int}(map(((i,s),) -> s => i, enumerate(all))...)
    long && println(io)
    print(io, "State Machine: ($(length(all)) states) input ")
    pretty(io, state.input_variable)
    println(io)
    for code in all
        pretty(io, code, state, id, long)
        println(io)
    end
    println(io, "end # of state machine")
    long && println(io)
    length(all)
end

# Pretty-print either a CodePoint or a DeduplicatedCodePoint
function pretty(
    io::IO,
    code::T,
    state::BinderState,
    id::IdDict{T, Int},
    long::Bool = true) where { T <: AbstractCodePoint }
    long = long && code isa CodePoint
    print(io, name(code, id))
    if long
        println(io)
        for case in code.cases
            print(io, "  ")
            pretty(io, case, state)
        end
    end
    action = code.action
    long && print(io, "   ")
    if action isa CasePartialResult
        print(io, " MATCH ", action.case_number, " with value ")
        pretty(io, action.result_expression)
    elseif action isa BoundPattern
        if action isa BoundTestPattern
            print(io, " TEST ")
        elseif action isa BoundFetchPattern
            print(io, " FETCH ")
        else
            print(io, " UNKNOWN ")
        end
        pretty(io, action, state)
    elseif action isa Expr
        print(io, " FAIL ")
        pretty(io, action)
    else
        error(" UNKNOWN ")
    end
    next = code.next
    if next isa Tuple{T}
        fall_through = id[next[1]] == id[code] + 1
        if long || !fall_through
            long && print(io, "\n   ")
            print(io, " NEXT: $(name(next[1], id))")
            if id[next[1]] == id[code] + 1
                print(io, " (fall through)")
            end
        end
    elseif next isa Tuple{T, T}
        fall_through = id[next[1]] == id[code] + 1
        if long || !fall_through
            long && print(io, "\n   ")
            print(io, " THEN: $(name(next[1], id))")
            if id[next[1]] == id[code] + 1
                print(io, " (fall through)")
            end
            long && println(io)
        end
        long && print(io, "   ")
        print(io, " ELSE: $(name(next[2], id))")
    elseif next isa Tuple{}
    else
        error(" UNKNOWN ")
    end
end

# We merge states with identical behavior, bottom-up, to minimize the size of
# the state machine.  We define `hash` and `==` to take account of only what matters.
# Specifically, we ignore the `cases::ImmutableVector{CasePartialResult}` of `CodePoint`.
mutable struct DeduplicatedCodePoint <: AbstractCodePoint
    # A label to produce in the code at entry to the code where
    # this state is implemented, if one is needed.  This is not produced
    # when this struct is created, but later during code generation.
    label::Union{Nothing, Symbol}

    # The selected action to take from this state: either
    # - Case whose tests have all passed, or
    # - A bound pattern to perform and then move on to the next state, or
    # - An Expr to insert into the code when all else is exhausted
    #   (which throws MatchFailure)
    @_const action::Union{CasePartialResult, BoundPattern, Expr}

    # The next code point(s):
    # - Tuple{} if the action is a case which was matched or a MatchFailure
    # - Tuple{DeduplicatedCodePoint} if the action was a fetch pattern. It designates
    #   the code to perform after the fetch.
    # - Tuple{DeduplicatedCodePoint, DeduplicatedCodePoint} if the action is a test.  These are the states
    #   to go to if the result of the test is true ([1]) or false ([2]).
    @_const next::Union{Tuple{}, Tuple{DeduplicatedCodePoint}, Tuple{DeduplicatedCodePoint, DeduplicatedCodePoint}}

    @_const _cached_hash::UInt64
    function DeduplicatedCodePoint(action, next)
        action isa CasePartialResult && @assert action.pattern isa BoundTruePattern
        new(nothing, action, next, hash((action, next)))
    end
end
Base.hash(code::DeduplicatedCodePoint, h::UInt64) = hash(code._cached_hash, h)
Base.hash(code::DeduplicatedCodePoint) = code._cached_hash
function Base.:(==)(a::DeduplicatedCodePoint, b::DeduplicatedCodePoint)
    a === b ||
        a._cached_hash == b._cached_hash &&
        isequal(a.action, b.action) &&
        isequal(a.next, b.next)
end
function ensure_label!(code::DeduplicatedCodePoint, state::BinderState)
    if code.label isa Nothing
        code.label = gensym("label", state)
    end
end

#
# Deduplicate a code point, given the deduplications of the downstream code points.
#
function dedup(
    dict::Dict{DeduplicatedCodePoint, DeduplicatedCodePoint},
    code::CodePoint,
    state::BinderState)
    next = if code.next isa Tuple{}
        code.next
    elseif code.next isa Tuple{CodePoint}
        (dedup(dict, code.next[1], state),)
    elseif code.next isa Tuple{CodePoint, CodePoint}
        t = dedup(dict, code.next[1], state)
        f = dedup(dict, code.next[2], state)
        # we might fall through to the true label, but we always jump to the false label
        ensure_label!(f, state)
        (t, f)
    else
        error("Unknown next type: $(code.next)")
    end
    key = DeduplicatedCodePoint(code.action, next)
    result = get!(dict, key, key)
    if result !== key
        # The state already existed, so it must have had two predecessors
        # We will need a label for one of them to use in the generated code
        ensure_label!(result, state)
    end
    result
end

#
# Deduplicate the state machine by collapsing behaviorally identical states.
#
function deduplicate_state_machine(entry::CodePoint, state::BinderState)
    dedup_map = Dict{DeduplicatedCodePoint, DeduplicatedCodePoint}()
    result = Vector{DeduplicatedCodePoint}()
    top_down_states = reachable_states(entry)
    bottom_up_states = Iterators.reverse(top_down_states)
    for e in bottom_up_states
        d = dedup(dedup_map, e, state)
        if d.label === nothing
            # It is a newly seen state
            push!(result, d)
        end
    end
    new_entry = dedup(dedup_map, entry, state)
    return reachable_states(new_entry)
end
