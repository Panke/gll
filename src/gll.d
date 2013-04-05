module gll.gll;

import std.algorithm, std.range, std.array, std.traits,
       std.functional, std.stdio, std.file, std.format, std.conv, std.string,
       std.typecons, std.traits;

import gll.grammar;

enum TokenKind {a, b, c};

struct Generator(Grammar)
{
    alias Grammar G;
    alias G.Symbol Symbol;
    alias G.Production Production;
    alias G.Epsilon Epsilon;
    alias G.TokenKind TokenKind;

    Grammar* gram;
    size_t curIndent;
    alias Tuple!(string, "tag", int, "num") TagAndNum;
    alias Tuple!(Production, "prod", ulong, "pos") DottedItem;
    TagAndNum[DottedItem] prodData;

    this(Grammar* gram_)
    {
        gram = gram_;
    }

    void generateParser(Sink)(Sink sink)
    {
        precalc();
        genGrammarSlotEnum(sink);
        genParserStruct(sink);
    }

    void precalc()
    {
//         sets = gram.firstFallowSets;
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


    void genGrammarSlotEnum(Sink)(Sink sink)
    {
        sink.put("enum Label\n{\n");
        {
            mixin(indent(4));
            foreach(prod; gram.productions)
                foreach(pos; 0 .. prod.rhs.length+1)
                {
                    if(pos == 0)
                        sink.put(xformat("%s,\n", prodData[DottedItem(prod, pos)].tag));
                    else if(pos != prod.rhs.length && !prod.rhs[pos].isTerminal)
                        sink.put(xformat("%s,\n", prodData[DottedItem(prod, pos)].tag));
                    else if(pos == prod.rhs.length && !prod.rhs[pos-1].isTerminal)
                        sink.put(xformat("%s,\n", prodData[DottedItem(prod,pos)].tag));
                }
            foreach(sym; gram.nonterminals)
            {
                sink.put(xformat("_%s,\n", sym.name));
            }
        }
        sink.put("}\n");
    }

    void genParserStruct(Sink)(Sink sink)
    {
        sink.put(ParserStructStart);
        {
            mixin(indent(12));
            foreach(sym; gram.nonterminals)
            {
                mixin(indent(4));
                genNonTerminalCase(sink, sym);
            }
        }
        sink.put(ParserWhileEnd);
            genTestFunctions(sink);
        sink.put("}}");
    }

    void genNonTerminalCase(Sink)(Sink sink, Symbol sym)
    {

        sink.put(xformat("case %s:\n", "_"~sym.name));
        auto prods = filter!(x => x.sym == sym)(gram.productions);
        foreach(prod; prods)
        {
            mixin(indent(4));
            sink.put(xformat("if(test!(_%s, %s)(curIdx))\n",
                sym.name, prodData[DottedItem(prod, 0)].tag));
            sink.put(xformat("    context.add(%s, curIdx, curTop);\n",
                          prodData[DottedItem(prod, 0)].tag));
        }
        sink.put("    curLabel = Loop; break;\n");
        foreach(prod; prods)
        {
            genProductionCase(sink, prod);
        }
    }

    void genProductionCase(Sink)(Sink sink, in Production prod)
    {
        if(prod.rhs.length == 1 && prod.rhs[0] == Epsilon)
            genEpsilonProduction(sink, prod);
        else if(prod.rhs.length == 1 && prod.rhs[0].isTerminal)
            genSingleTerminalProd(sink, prod);
        else if(prod.rhs.length > 1 && prod.rhs[0].isTerminal)
            genTerminalProduction(sink, prod);
        else
        {
            assert(!prod.rhs[0].isTerminal);
            genNonTerminalProduction(sink, prod);
        }
    }

    void genEpsilonProduction(Sink)(Sink sink, in Production prod)
    {
        sink.put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        mixin(indent(4));
        sink.put("context.pop(curTop, curIdx);\ncurLabel = Loop; break;\n");
    }

    void genSingleTerminalProd(Sink)(Sink sink, in Production prod)
    {

        sink.put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        mixin(indent(4));
        sink.put("curIdx++;\n");
        sink.put("context.pop(curTop, curIdx);\ncurLabel = Loop; break;\n");
    }

    void genTerminalProduction(Sink)(Sink sink, in Production prod)
    {
        sink.put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        sink.put("    curIdx++;\n");
        foreach(dottedItem; map!(x => DottedItem(prod, x))(iota(1, prod.rhs.length)))
        {
            generateDottedItem(sink, dottedItem);
        }
        mixin(indent(4));
        sink.put("context.pop(curTop, curIdx);\n");
        sink.put("curLabel = Loop; break;\n");
    }

    void generateDottedItem(Sink)(Sink sink, DottedItem item)
    {
        auto front = item.prod.rhs[item.pos];
        if(front.isTerminal)
            generateDottedItemTerminal(sink, item, front);
        else
            generateDottedItemNonTerminal(sink, item, front);
    }

    void generateDottedItemTerminal(Sink)(Sink sink, DottedItem item, Symbol front)
    {
        sink.put(xformat("if(!input[curidx] == %s)\n{\n", front.kind));
        sink.put("    curLabel = Loop; break;\n");
        sink.put("}\n");
        sink.put("curIdx++;\n");
    }

    void generateDottedItemNonTerminal(Sink)(Sink sink, DottedItem item, Symbol front)
    {
        auto retItem = DottedItem(item.prod, item.pos+1);
        {
            mixin(indent(4));
            sink.put(xformat("if(test!(_%s, %s)(curIdx))\n{\n",
                        item.prod.sym.name, prodData[item].tag));
            { mixin(indent(4));
                sink.put(xformat("curTop = context.create(%s, curIdx, curTop);\n",
                    prodData[retItem].tag));
                sink.put(xformat("curLabel = _%s; break;\n", item.prod.rhs[item.pos].name));
            }
            sink.put("}\nelse\n{\n");
            sink.put("    curLabel = Loop; break;\n}\n");
        }
        sink.put(xformat("case %s:\n", prodData[retItem].tag));
    }

    void genNonTerminalProduction(Sink)(Sink sink, in Production prod)
    {
        sink.put(xformat("case %s:\n", prodData[DottedItem(prod, 0)].tag));
        auto label = prodData[DottedItem(prod, 1)].tag;
        {
            mixin(indent(4));
            sink.put(xformat("curTop = context.create(%s, curIdx, curTop);\n",
                        label));
            sink.put(xformat("curLabel = %s; break;\n", prod.sym.name));
        }
        sink.put(xformat("case %s:\n", label));
        foreach(item; map!(x => DottedItem(prod, x))(iota(1, prod.rhs.length)))
        {
            generateDottedItem(sink, item);
        }
        mixin(indent(4));
        sink.put("pop(curTop, curIdx);\n");
        sink.put("curLabel = Loop; break;\n");
    }


    void genTestFunctions(Sink)(Sink sink)
    {
        Grammar.Sets sets = gram.firstFallowSets;
        foreach(prod; gram.productions)
        {
            foreach(idx; 1 .. prod.rhs.length)
            {
                genTestFunction(sink, prod, idx, sets);
            }
        }
    }

    void genTestFunction(Sink)(Sink sink, in Production prod, size_t idx,
                                Grammar.Sets sets)
    {
        pragma(msg, typeof(prod.sym.kind));
        sink.put(xformat("void test(Tags A, Tags B)(size_t idx)\n"));
        {
            mixin(indent(4));
             sink.put(xformat("if(A == %s && B == %s)\n",
                              "_"~prod.sym.name,
                              prodData[DottedItem(prod, idx)].tag));
        }
        sink.put("{\n");
        {
            mixin(indent(4));
            sink.put("return (\n false ");
            enum enumName = fullyQualifiedName!(typeof(prod.sym.kind));
            foreach(elem; sets.firstPlus[prod])
            {
                sink.put(xformat("|| \n input[idx] == %s.%s ",
                                 enumName,
                                 elem.kind));
            }
            sink.put(");\n");
        }
        sink.put("}\n");
    }

    bool _needsIndent = false;
    void put(Sink, Range)(Sink sink, Range range)
        if(isForwardRange!(Range) && is(ElementType!Range : dchar)
            && isOutputRange!(Sink, dchar))
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

        while(true)
        {
            final switch(curLabel)
            {
EOS";

string ParserWhileEnd= q"EOS
            }
        }
    }
EOS";
