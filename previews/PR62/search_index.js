var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = Rematch2","category":"page"},{"location":"#Rematch2","page":"Home","title":"Rematch2","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for Rematch2.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [Rematch2]","category":"page"},{"location":"#Rematch2.@ismatch-Tuple{Any, Any}","page":"Home","title":"Rematch2.@ismatch","text":"Usage:\n\n    @ismatch value pattern\n\nReturn true if value matches pattern, false otherwise.  When returning true, binds the pattern variables in the enclosing scope.  Typically, it would be used like this:\n\n    if @ismatch value pattern\n        # use the pattern variables\n    end\n\nor\n\n    if (@ismatch value pattern) && (some_other_condition)\n        # use the pattern variables\n    end\n\nguarded patterns ought not be used with @ismatch, as you can just use && instead.\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match","page":"Home","title":"Rematch2.@match","text":"This macro has two forms.\n\nThe single-pattern form:\n\n    @match2 pattern = value\n\nIf value matches pattern, bind variables and return value.   Otherwise, throw MatchFailure.\n\nThe multi-pattern form:\n\n    @match2 value begin\n        pattern1 => result1\n        pattern2 => result2\n        ...\n    end\n\nReturn result for the first matching pattern.   If there are no matches, throw MatchFailure.\n\nPatterns:\n\n_ matches anything\nfoo matches anything, binds value to foo\nFoo(x,y,z) matches structs of type Foo with fields matching x,y,z\nFoo(y=1) matches structs of type Foo whose y field equals 1\n[x,y,z] matches AbstractArrays with 3 entries matching x,y,z\n(x,y,z) matches Tuples with 3 entries matching x,y,z\n[x,y...,z] matches AbstractArrays with at least 2 entries, where x matches the first entry, z matches the last entry and y matches the remaining entries.\n(x,y...,z) matches Tuples with at least 2 entries, where x matches the first entry, z matches the last entry and y matches the remaining entries.\n_::T matches any subtype (isa) of T\nx || y matches values which match either x or y (only variables which exist in both branches will be bound)\nx && y matches values which match both x and y\nx where condition matches only if condition is true (condition may use any variables that occur earlier in the pattern eg (x, y, z where x + y > z))\nAnything else is treated as a constant and tested for equality\nExpressions can be interpolated in as constants via standard interpolation syntax $(x)\n\nPatterns can be nested arbitrarily.\n\nRepeated variables only match if they are equal (==). For example (x,x) matches (1,1) but not (1,2).\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match-Tuple{Any, Any}","page":"Home","title":"Rematch2.@match","text":"Usage:\n\n    @match value begin\n        pattern1 => result1\n        pattern2 => result2\n        ...\n    end\n\nReturn result for the first matching pattern. If there are no matches, throw MatchFailure. This uses a brute-force code gen strategy, like using a series of if-else statements. It is used for testing purposes, as a reference for correct semantics.\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match-Tuple{Any}","page":"Home","title":"Rematch2.@match","text":"Usage:\n\n    @match pattern = value\n\nIf value matches pattern, bind variables and return value. Otherwise, throw MatchFailure.\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match2-Tuple{Any, Any}","page":"Home","title":"Rematch2.@match2","text":"Usage:\n\n    @match2 value begin\n        pattern1 => result1\n        pattern2 => result2\n        ...\n    end\n\nReturn result for the first matching pattern. If there are no matches, throw MatchFailure. This is like @match, but generaties more efficient code.\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match2-Tuple{Any}","page":"Home","title":"Rematch2.@match2","text":"Usage:\n\n    @match2 pattern = value\n\nIf value matches pattern, bind variables and return value. Otherwise, throw MatchFailure.\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match_fail-Tuple{}","page":"Home","title":"Rematch2.@match_fail","text":"@match_fail\n\nThis statement permits early-exit from the value of a @match2 case. The programmer may write the value as a begin ... end and then, within the value, the programmer may write\n\n@match_fail\n\nto cause the case to terminate as if its pattern had failed. This permits cases to perform some computation before deciding if the rule \"really\" matched.\n\n\n\n\n\n","category":"macro"},{"location":"#Rematch2.@match_return-Tuple{Any}","page":"Home","title":"Rematch2.@match_return","text":"@match_return value\n\nThis statement permits early-exit from the value of a @match2 case. The programmer may write the value as a begin ... end and then, within the value, the programmer may write\n\n@match_return value\n\nto terminate the value expression early with success, with the given value.\n\n\n\n\n\n","category":"macro"}]
}
