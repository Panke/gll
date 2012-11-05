import std.algorithm, std.range, std.array, std.container, std.traits,
       std.functional, std.stdio, std.file, std.format;

import grammar;

struct Generator(Sink)
    if(isOutputRange!(Sink, char))
{
    struct Indent
    {
        int n;
        this(int n_) { n = n_; curIndent += n; }
        ~this() { curIndent -= n; }
    }


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
        genGrammarSlotEnum();
    }

    void genGrammarSlotEnum(Sink sink)
    {
        put("enum Label\n{\n");
        foreach(prod; gram.productions)
        {
            Indent indent1 = Indent(4);
            foreach(i; iota(0, prod.rhs.length))
            {
                string[] parts = [prod.sym];
                put(joiner(parts ~ prod.rhs[0..i], '_').array);
                put("\n");
            }
        }
        put("}\n");
    }

    void put(Range)(Range range)
        if(isInputRange!(Range) && is(ElementType!Range : char))
    {
        string indent = repeat(' ', curIndent).array;
        foreach(line; split(range, '\n'))
        {
            sink.put(indent);
            sink.put.line;
        }
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
    auto app = appender!string();
    gen.genGrammarSlotEnum(app);
    writeln(app.data);
}
void main() {}
