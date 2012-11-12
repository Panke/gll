module gll.gll;

import std.algorithm, std.range, std.array, std.container, std.traits,
       std.functional, std.stdio, std.file, std.format, std.conv, std.string,
       std.typecons;

import gll.grammar;

struct Generator(Sink)
    if(isOutputRange!(Sink, char))
{
    const(Grammar)* gram;
    Sink sink;
    size_t curIndent;
    alias Tuple!(string, "tag", int, "num") TagAndNum;
    alias Tuple!(const Production, "prod", ulong, "pos") DottedItem;
    TagAndNum[DottedItem] prodData;

    this(const(Grammar)* gram_, Sink sink_)
    {
        gram = gram_;
        sink = sink_;
    }

    void generateParser(Sink sink)
    {
        this.sink = sink;
        precalc();
        genGrammarSlotEnum();
        genParserStruct();
    }

    void precalc()
    {
        int num = 1;
        foreach(prod; gram.productions)
            foreach(pos; 0 .. prod.rhs.length+1)
        {
            auto app = appender!string();
            app.wDotItem(prod, pos);
            string orig = app.data;
            string name = std.array.replace(orig, "•", "0");
            name = std.array.replace(name, " ", "_");
            name = std.array.replace(name, "⇒", "");
            name = std.array.replace(name, "__", "_");
            name = std.array.replace(name, "ε", "Epsi");
            auto item = TagAndNum(name, num);
            prodData[DottedItem(prod, pos)] = item;
            num++;
        }
    }


    void genGrammarSlotEnum()
    {
        put("enum Label\n{\n");
        {
            mixin(indent(4));
            foreach(prod; gram.productions)
                foreach(pos; 0 .. prod.rhs.length+1)
                {
                    if(pos == 0)
                        put(xformat("%s,\n", prodData[DottedItem(prod, pos)].tag));
                    else if(pos != prod.rhs.length && !prod.rhs[pos].isTerminal)
                        put(xformat("%s,\n", prodData[DottedItem(prod, pos)].tag));
                    else if(pos == prod.rhs.length && !prod.rhs[pos-1].isTerminal)
                        put(xformat("%s,\n", prodData[DottedItem(prod,pos)].tag));
                }
            foreach(sym; gram.nonterminals)
            {
                put(xformat("_%s,\n", sym.name));
            }
        }
        put("}\n");
    }

    void genParserStruct()
    {
        put(ParserStructStart);
        {mixin(indent(12));
        foreach(sym; gram.nonterminals)
        {
            mixin(indent(4));
            genNonTerminalCase(sym);
        }
        }
        put(ParserStructEnd);
    }

    void genNonTerminalCase(Symbol sym)
    {

        put(xformat("case %s:\n", "_"~sym.name));
        auto prods = filter!(x => x.sym == sym)(gram.productions);
        foreach(prod; prods)
        {
            mixin(indent(4));
            put(xformat("if(test!(_%s, %s)(curIdx))\n",
                sym.name, prodData[DottedItem(prod, 0)].tag));
            put(xformat("    context.add(%s, curIdx, curTop);\n",
                          prodData[DottedItem(prod, 0)].tag));
        }
        put("    curLabel = Loop; break;\n");
        foreach(prod; prods)
        {
            genProductionCase(prod);
        }
    }

    void genProductionCase(in Production prod)
    {
        if(prod.rhs.length == 1 && prod.rhs[0] == Epsilon)
            genEpsilonProduction(prod);
        else if(prod.rhs.length == 1 && prod.rhs[0].isTerminal)
            genSingleTerminalProd(prod);
        else if(prod.rhs.length > 1 && prod.rhs[0].isTerminal)
            genTerminalProduction(prod);
        else
        {
            assert(!prod.rhs[0].isTerminal);
            genNonTerminalProduction(prod);
        }
    }

    void genEpsilonProduction(in Production prod)
    {
        put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        mixin(indent(4));
        put("context.pop(curTop, curIdx);\ncurLabel = Loop; break;\n");
    }

    void genSingleTerminalProd(in Production prod)
    {

        put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        mixin(indent(4));
        put("curIdx++;\n");
        put("context.pop(curTop, curIdx);\ncurLabel = Loop; break;\n");
    }

    void genTerminalProduction(in Production prod)
    {
        put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        put("    curIdx++;\n");
        foreach(dottedItem; map!(x => DottedItem(prod, x))(iota(1, prod.rhs.length)))
        {
            generateDottedItem(dottedItem);
        }
        mixin(indent(4));
        put("context.pop(curTop, curIdx);\n");
        put("curLabel = Loop; break;\n");
    }

    void generateDottedItem(DottedItem item)
    {
        auto front = item.prod.rhs[item.pos];
        if(front.isTerminal)
            generateDottedItemTerminal(item, front);
        else
            generateDottedItemNonTerminal(item, front);
    }

    void generateDottedItemTerminal(DottedItem item, Symbol front)
    {
        put(xformat("if(!input[curidx] == %s)\n{\n", front.name));
        put("    curLabel = Loop; break;\n");
        put("}\n");
        put("curIdx++;\n");
    }

    void generateDottedItemNonTerminal(DottedItem item, Symbol front)
    {
        auto retItem = DottedItem(item.prod, item.pos+1);
        {
            mixin(indent(4));
            put(xformat("if(test!(_%s, %s)(curIdx))\n{\n",
                        item.prod.sym.name, prodData[item].tag));
            { mixin(indent(4));
                put(xformat("curTop = context.create(%s, curIdx, curTop);\n",
                    prodData[retItem].tag));
                put(xformat("curLabel = _%s; break;\n", item.prod.rhs[item.pos].name));
            }
            put("}\nelse\n{\n");
            put("    curLabel = Loop; break;\n}\n");
        }
        put(xformat("case %s:\n", prodData[retItem].tag));
    }

    void genNonTerminalProduction(in Production prod)
    {
        put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        auto label = prodData[DottedItem(prod, 1)].tag;
        {
            mixin(indent(4));
            put(xformat("curTop = context.create(%s, curIdx, curTop);\n",
                        label));
            put(xformat("curLabel = %s; break;\n", prod.sym.name));
        }
        put(xformat("case %s:\n", label));
        foreach(item; map!(x => DottedItem(prod, x))(iota(1, prod.rhs.length)))
        {
            generateDottedItem(item);
        }
        mixin(indent(4));
        put("pop(curTop, curIdx);\n");
        put("curLabel = Loop; break;\n");
    }

    bool _needsIndent = false;
    void put(Range)(Range range)
        if(isForwardRange!(Range) && is(ElementType!Range : dchar))
    {
        auto indentstring = std.range.repeat(' ', curIndent);
        while(!range.empty)
        {
            if(_needsIndent)
            {
                sink.put(indentstring);
                _needsIndent = false;
            }
            auto last = range.front;
            sink.put(last);
            if(last == '\n')
                _needsIndent=true;
            range.popFront();
        }
    }

    static string indent(uint width=4)
    {
        string result = "curIndent += " ~ to!string(width) ~ ";\n";
        result ~= "scope(exit) curIndent -= " ~ to!string(width) ~ ";\n";
        return result;
    }
}

string ParserStructStart = q"EOS
struct Parser
{
    dstring input;
    GllContext context;
    this(dstring _input)
    {
        input = _input;
        context = new GllContext();
    }

    bool parse()
    {
        InputPos curIdx;
        GssId curTop;
        Tags curLabel = Loop;
        with(Tags) {
        if(input[0] == "n" || input.length == 0)
            curLabel = _S;
        else
            throw new Exception("Näääh");

        while(true)
        {
            final switch(curLabel)
            {
EOS";

string ParserStructEnd = q"EOS
            }
        }
    }
}
EOS";
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
    gen.generateParser(app);
    writeln(app.data);
}
