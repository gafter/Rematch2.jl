struct MatchCaseResult
    assigned::Dict{Symbol, Symbol}
    matched_expression::Any
    result_expression::Any
end

function bind_pattern(
    mod::Module,
    location::LineNumberNode,
    pattern::Any,
    input_variable::Symbol)
    state = BinderState(mod)
    assigned = ImmutableDict{Symbol,Symbol}()

    (pattern, assigned) = bind_pattern!(
        location, pattern, input_variable, state, assigned)
    (pattern, assigned, state)
end

function handle_match_case(
    location::LineNumberNode,
    input_variable::Symbol,
    case,
    state::BinderState)
    assigned = ImmutableDict{Symbol,Symbol}()
    if @capture(case, pattern_ => result_)
        (bound_pattern, assigned) = bind_pattern!(
            location, pattern, input_variable, state, assigned)
        matched = lower_pattern(bound_pattern, state)
    else
        locstring = string(location.file, ":", location.line)
        matchstring = string(case)
        message = "$locstring: Unrecognized @match case syntax: `$matchstring`"
        return MatchCaseResult(assigned, :(error($message)), nothing)
    end

    return MatchCaseResult(assigned, matched, result)
end

function handle_match_cases(location::LineNumberNode, mod::Module, value, match)
    if (match isa Expr && match.head == :call && match.args[1] == :(=>))
        # previous version of @match supports `@match(expr, pattern => value)`
        match = Expr(:block, match)
    elseif !(match isa Expr) || match.head != :block
        locstring = string(location.file, ":", location.line)
        matchstring = string(match)
        message = "$locstring: Unrecognized @match block syntax: `$matchstring`"
        return :(error($message))
    end
    state = BinderState(mod)
    input_variable::Symbol = gensym("input_value")
    cases = MatchCaseResult[]

    for case in match.args
        if case isa LineNumberNode
            location = case
        else
            push!(cases, handle_match_case(location, input_variable, case, state))
        end
    end
    if !isempty(state.errors)
        errors = join(state.errors, "\n")
        return :(error($errors))
    end

    tail = :(throw(MatchFailure($input_variable)))
    n = length(cases)
    for (i, case) in enumerate(reverse(cases))
        assigned = case.assigned
        # assign to pattern variables
        patassigns = (:($(esc(patvar)) = $resultsym) for (patvar, resultsym) in case.assigned)
        eval = esc(case.result_expression)
        result = Expr(:let, Expr(:block, patassigns...), eval)
        tail = Expr(i == n ? :if : :elseif, case.matched_expression, result, tail)
    end
    Expr(:block, state.assertions..., :($input_variable = $(esc(value))), tail)
end
