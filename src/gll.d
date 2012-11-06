module gll.gll;

import std.algorithm, std.range, std.array, std.container, std.traits,
       std.functional, std.stdio, std.file, std.format, std.conv;

import gll.grammar;

struct Generator(Sink)
    if(isOutputRange!(Sink, char))
{
    const(Grammar)* gram;
    Sink sink;
    size_t curIndent;

    this(const(Grammar)* gram_, Sink sink_)
    {
        gram = gram_;
        sink = sink_;
    }

    void generateParser(Sink sink)
    {
        // generate preamble
        //genGrammarSlotEnum(sink);
    }

//     void genGrammarSlotEnum(Sink sink)
//     {
//         put("enum Label\n{\n");
//         foreach(prod; gram.productions)
//         {
//             enum in_ = indent();
// //             mixin(indent());
//             foreach(i; iota(0, prod.rhs.length))
//             {
//                 string[] parts = [prod.sym];
//                 put(joiner(parts ~ prod.rhs[0..i], '_').array);
//                 put("\n");
//             }
//         }
//         put("}\n");
//     }
// //
    void put(Range)(Range range)
        if(isInputRange!(Range) && is(ElementType!Range : dchar))
    {
        string indent = cast(string) repeat(' ', curIndent).array;
        foreach(line; split(range, "\n"))
        {
            sink.put(indent);
            sink.put(line);
        }
    }

    string indent(uint width=4)
    {
        string result = "curIndent += " ~ to!string(width) ~ ";\n";
        result ~= "scope(exit) curIndent -= " ~ to!string(width) ~ ";\n";
        return result;
    }
}


unittest {
    immutable Symbol A = Symbol( "A" );
    immutable Symbol B = Symbol( "B" );
    immutable Symbol C = Symbol( "C" );
    immutable Symbol a = Symbol( "a", IsTerminal.yes );
    immutable Symbol b = Symbol( "b", IsTerminal.yes );
    immutable Symbol c = Symbol( "c", IsTerminal.yes );

    Production prd5 = Production( C, [A, B, C] );
    Production prd3 = Production( B, [b] );
    Production prd1 = Production( A, [ a ] );
    Production prd2 = Production( B, [B, A ]);
    Production prd4 = Production( B, [Epsilon] );
    Production prd6 = Production( A, [Epsilon] );
    Production prd7 = Production( C, [ c ] );

    Grammar g = Grammar(C, []);
    g.addProductions([prd1, prd2, prd3, prd4, prd5, prd6, prd7]);

    auto app = appender!(string)();
    auto gen = Generator!(typeof(app))(&g, app);
    //gen.genGrammarSlotEnum(app);
}
