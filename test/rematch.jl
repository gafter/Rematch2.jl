# Note we do not use `@eval` to define a struct within a @testset
# because we need the types to be defined during macro expansion,
# which is earlier than evaluation.  types are looked up during
# expansion of the @__match__ macro.

@testset "Rematch2.@__match__ tests" begin

@testset "Assignments in the value do not leak out" begin
    @__match__ Foo(1, 2) begin
        Foo(x, 2) => begin
            new_variable = 3
        end
    end
    @test !(@isdefined x)
    @test !(@isdefined new_variable)
end

@testset "Assignments in a where clause do not leak to the rule's result" begin
    @__match__ Foo(1, 2) begin
        Foo(x, 2) where begin
            new_variable = 3
            true
        end => begin
            @test !(@isdefined new_variable)
            1
        end
    end
    @test !(@isdefined x)
    @test !(@isdefined new_variable)
end

file = Symbol(@__FILE__)

@testset "diagnostics produced are excellent" begin

    @testset "could not bind a type" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    ::Unknown => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Could not bind `Unknown` as a type (due to `UndefVarError(:Unknown)`)."
            end
        end
    end

    @testset "attempt to match non-type" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    ::1 => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Invalid type name: `1`."
            end
        end
    end

    @testset "location of error for redundant field patterns 1" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    Foo(x = x1,x = x2) => (x1, x2)
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Pattern `Foo(x = x1, x = x2)` has duplicate named arguments [:x, :x]."
            end
        end
    end

    @testset "location of error for redundant field patterns 2" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    Foo(x = x1, x = x2) => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Pattern `Foo(x = x1, x = x2)` has duplicate named arguments [:x, :x]."
            end
        end
    end

    @testset "mix positional and named field patterns" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    Foo(x = x1, x2) => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Pattern `Foo(x = x1, x2)` mixes named and positional arguments."
            end
        end
    end

    @testset "wrong field count" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    Foo(x, y, z) => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: The type `$Foo` has 2 fields but the pattern expects 3 fields."
            end
        end
    end

    @testset "field not found" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ Foo(1, 2) begin
                    Foo(z = 1) => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Type `$Foo` has no field `z`."
            end
        end
    end

    @testset "multiple splats" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ [1, 2, 3] begin
                    [x..., y, z...] => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: More than one `...` in pattern `[x..., y, z...]`."
            end
        end
    end

    @testset "unrecognized pattern syntax" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ 1 begin
                    (x + y) => 1
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Unrecognized pattern syntax `x + y`."
            end
        end
    end

    @testset "type binding changed 1" begin
        let line = 0
            try
                local String = Int64
                line = (@__LINE__) + 2
                @__match__ 1 begin
                    ::String => 1
                end
                @test false
            catch e
                @test e isa AssertionError
                @test e.msg == "$file:$line: The type syntax `::String` bound to type String at macro expansion time but Int64 later."
            end
        end
    end

    @testset "type binding changed 2" begin
        let line = 0
            try
                line = (@__LINE__) + 3
                function f(x::String) where { String }
                    @__match__ x begin
                        ::String => 1
                    end
                end
                f(Int64(1))
                @test false
            catch e
                @test e isa AssertionError
                @test e.msg == "$file:$line: The type syntax `::String` bound to type String at macro expansion time but Int64 later."
            end
        end
    end

    @testset "bad match block syntax" begin
        let line = 0
            try
                line = (@__LINE__) + 1
                @eval @__match__ a (b + c)
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test e.msg == "$file:$line: Unrecognized @match block syntax: `b + c`."
            end
        end
    end

    @testset "bad match case syntax" begin
        let line = 0
            try
                line = (@__LINE__) + 2
                @eval @__match__ 1 begin
                    (2 + 2) = 4
                end
                @test false
            catch ex
                @test ex isa LoadError
                e = ex.error
                @test e isa ErrorException
                @test startswith(e.msg, "$file:$line: Unrecognized @match case syntax: `2 + 2 =")
            end
        end
    end

end

# Tests inherited from Rematch below

@testset "Match Struct by field names" begin
    # match one struct field by name
    let x = nothing
        x1 = nothing
        @test (@__match__ Foo(1,2) begin
               Foo(x=x1) => x1
        end) == 1
        @test x == nothing
        @test x1 == nothing
    end

    # match struct with mix of by-value and by-field name
    let x1 = nothing
        @test (@__match__ Foo(1,2) begin
               Foo(0,2) => nothing
               Foo(x=x1) => x1
        end) == 1
    end

    # match multiple struct fields by name
    let x1 = nothing, y1 = nothing
        @test (@__match__ Foo(1,2) begin
               Foo(x=x1,y=y1) => (x1,y1)
        end) == (1,2)
    end

    # match struct field by name redundantly
    let x1 = nothing, x2 = nothing
        @test_throws LoadError (@eval @__match__ Foo(1,2) begin
               Foo(x=x1,x=x2) => (x1,x2)
        end)
    end

    # variables in patterns are local, and can match multiple positions
    let z = 0
        @test z == 0
        @test (@__match__ Foo(1,1) begin
               Foo(x=z, y=z) => z # inner z matches both x and y
               end) == 1
        @test z == 0 # no change to outer z
    end

    # variable in a pattern can match multiple positions
    @test_throws MatchFailure(Foo(1,2)) (@__match__ Foo(1,2) begin
                                     Foo(x=x1, y=x1) => true
                                     end)
end

@testset "non-struct Matches" begin
    # throw MatchFailure if no matches
    @test_throws MatchFailure(:this) @__match__ :this begin
        :that => :ok
    end

    # match against symbols
    @test (@__match__ :this begin
        :this => :ok
    end) == :ok

    # treat macros as constants
    @test (@__match__ v"1.2.0" begin
      v"1.2.0" => :ok
    end) == :ok

    ###
    ### We do not support `QuoteNode` or `Expr` in `@__match__` blocks like `Rematch.jl`.
    ### There, they were treated as literals, but they could contain
    ### interpolated expressions, which we would want to handle properly.
    ### It would be nice to support some kind of pattern-matching on them.
    ###
    # QuoteNodes
    # @test (@__match__ :(:x) begin
    #   :(:x) => :ok
    # end) == :ok
    # @test (@__match__ :(:x+:y) begin
    #   :(:x + :y) => :ok
    # end) == :ok
end

@testset "logical expressions with branches" begin
    # disjunction
    @test (@__match__ (1,(2,3)) begin
      (1, (x,:nope) || (2,x)) => x
    end) == 3

    # disjunction and repeated variables
    @test (@__match__ (1,(2,3), 3) begin
      (1, (x,:nope) || (2,x), x) => x
    end) == 3
    @test (@__match__ (1,(2,3), 4) begin
      (1, (x,:nope) || (2,x), x) => x
      _ => :ok
    end) == :ok
    @test (@__match__ (3,(2,3), 3) begin
      (x, (x,:nope) || (2,x), 3) => x
    end) == 3
    @test (@__match__ (1,(2,3), 3) begin
      (x, (x,:nope) || (2,x), 3) => x
      _ => :ok
    end) == :ok
    @test (@__match__ (3,(2,3), 3) begin
      (x, (x,:nope) || (2,x), x) => x
    end) == 3
    @test (@__match__ (3,(2,3), 1) begin
      (x, (x,:nope) || (2,x), x) => x
      _ => :ok
    end) == :ok

    # conjunction
    @test (@__match__ (1,(2,3)) begin
        (1, a && (2,b)) => (a,b)
    end) == ((2,3),3)
    @test_throws MatchFailure((1,(2,3))) (@__match__ (1,(2,3)) begin
        (1, a && (1,b)) => (a,b)
    end) == ((2,3),3)

    # only vars that exist in all branches can be accessed
    @test_throws UndefVarError(:y) @__match__ (1,(2,3)) begin
      (1, (x,:nope) || (2,y)) => y
    end
end

@testset "Splats" begin
    # splats
    test0(x) = @__match__ x begin
        [a] => [a]
        [a,b,c...] => [a,b,c]
        (a,) => (a,)
        (a...,b,c,d) => (a,b,c,d)
        (a,b...,c) => (a,b,c)
        _ => false
    end
    @test test0([1]) == [1]
    @test test0([1,2]) == [1,2,[]]
    @test test0([1,2,3]) == [1,2,[3]]
    @test test0([1,2,3,4]) == [1,2,[3,4]]
    @test test0((1,)) == (1,)
    @test test0((1,2)) == (1, (), 2)
    @test test0((1,2,3)) == ((), 1, 2, 3)
    @test test0((1,2,3,4)) == ((1,), 2, 3, 4)
    @test test0((1,2,3,4,5)) == ((1,2), 3, 4, 5)

    # no splats allowed in structs (would be nice, but need to implement getfield(struct, range))
    @test_throws LoadError @eval @__match__ foo begin
        Foo(x...) => :nope
    end

    # at most one splat in tuples/arrays
    @test_throws LoadError @eval @__match__ [1,2,3] begin
        [a...,b,c...] => :nope
    end
    @test_throws LoadError @eval @__match__ [1,2,3] begin
        (a...,b,c...) => :nope
    end

    # inference for splats
    infer1(x) = @__match__ x begin
        (a, b..., c) => a
    end
    @test @inferred(infer1((:ok,2,3,4))) == :ok

    infer2(x) = @__match__ x begin
        (a, b..., c) => c
    end

    @test @inferred(infer2((1,2,3,:ok))) == :ok
end

@testset "Inference in branches" begin
    # inference in branches
    infer3(foo) = @__match__ foo begin
        Foo(_,y::Symbol) => y
        Foo(x::Symbol,_) => x
    end
    if VERSION >= v"1.6"
        @test @inferred(infer3(Foo(1,:ok))) == :ok
    end
    infer4(foo) = @__match__ foo begin
        Foo(x,y::Symbol) => y
        Foo(x::Symbol,y) => x
    end
    if VERSION >= v"1.6"
        @test @inferred(infer4(Foo(1,:ok))) == :ok
    end
end

@testset "Nested Guards" begin
    # nested guards can use earlier bindings
    @test (@__match__ [1,2] begin
      [x, y where y > x] => (x,y)
    end) == (1,2)
    @test_throws MatchFailure([2,1]) @__match__ [2,1] begin
      [x, y where y > x] => (x,y)
    end

    # nested guards can't use later bindings
    @test_throws UndefVarError(:y) @__match__ [2,1] begin
      [x where y > x, y ] => (x,y)
    end
end

@testset "structs matching all fields" begin
    # detect incorrect numbers of fields
    @test_throws LoadError (@eval @__match__ Foo(x) = Foo(1,2)) == (1,2)
    @test_throws LoadError @eval @__match__ Foo(x) = Foo(1,2)
    @test_throws LoadError @eval @__match__ Foo(x,y,z) = Foo(1,2)

    # ...even if the pattern is not reached
    @test_throws LoadError (@eval @__match__ Foo(1,2) begin
        Foo(x,y) => :ok
        Foo(x) => :nope
    end)
end

@testset "Miscellanea" begin
    # match against fiddly symbols (https://github.com/kmsquire/Match.jl/issues/32)
    @test (@__match__ :(@when a < b) begin
            Expr(_, [Symbol("@when"), _, _]) => :ok
            Expr(_, [other, _, _]) => other
            end) == :ok

    # match against single tuples (https://github.com/kmsquire/Match.jl/issues/43)
    @test (@__match__ (:x,) begin
      (:x,) => :ok
    end) == :ok

    # match against empty structs (https://github.com/kmsquire/Match.jl/issues/43)
    e = (True(), 1)
    @test (@__match__ e begin
        (True(), x) => x
    end) == 1

    # symbols are not interpreted as variables (https://github.com/kmsquire/Match.jl/issues/45)
    let x = 42
        @test (@__match__ (:x,) begin
          (:x,) => x
        end) == 42
    end

    # allow & and | for conjunction/disjunction (https://github.com/RelationalAI-oss/Rematch.jl/issues/1)
    @test (@__match__ (1,(2,3)) begin
      (1, (x,:nope) | (2,x)) => x
    end) == 3
    @test (@__match__ (1,(2,3)) begin
        (1, a & (2,b)) => (a,b)
    end) == ((2,3),3)

    @test_throws LoadError @eval @__match__ a + b = x
end

@testset "Interpolated Values" begin
    # match against interpolated values
    test_interp_pattern = let a=1, b=2, c=3,
                              arr=[10,20,30], tup=(100,200,300)
        _t(x) = @__match__ x begin
            # scalars
            [$a,$b,$c,out] => out
            [fronts..., $a,$b,$c, back] => [fronts...,back]
            # arrays & tuples
            [fronts..., $arr, back] => [fronts...,back]
            [fronts..., $tup, back] => [fronts...,back]
            # complex expressions
            [$(a+b+c), out] => out
            # splatting existing values not supported
            # [fronts..., $(arr...), back] => [fronts...,back]
        end
    end
    # scalars
    @test test_interp_pattern([1,2,3,4]) == 4
    @test test_interp_pattern([4,3,2,1, 1,2,3, 4]) == [4,3,2,1,4]
    # arrays & tuples
    @test test_interp_pattern([0,1, [10,20,30], 2]) == [0,1,2]
    @test test_interp_pattern([0,1, (100,200,300), 2]) == [0,1,2]
    # complex expressions
    @test test_interp_pattern([6,1]) == 1
    # TODO: splatting existing values into pattern isn't suported
    # @test_broken test_interp_pattern([0,1, 10,20,30, 2]) == [0,1,2]
end

end
