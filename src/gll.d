module gll.gll;

import std.algorithm, std.range, std.array, std.traits,
       std.functional, std.stdio, std.file, std.format, std.conv, std.string,
       std.typecons, std.traits;

import gll.grammar;

enum TokenKind {a, b, c};

struct Generator(G)
{
    alias G.Symbol Symbol;
    alias G.Production Production;
    alias G.TokenKind TK;
    G.Sets sets;
    G* gram;
    size_t curIndent;

    
    this(G* grammar)
    {
        gram = grammar;
        sets = grammar.firstFallowSets;
    }
    
    void generateParser(Sink)(Sink sink)
    {
        genParserStruct(sink, gram);
    }
    
    string labelName(Production prod, size_t position)
    {
        static string[Tuple!(Production, size_t)] cache;
        string result = cache.get(tuple(prod, position), "");
        if(result != "")
            return result;
        
        auto app = appender!string();
        app.wDotItem(prod, position);
        string orig = app.data;
        result = std.array.replace(orig, "•", "0");
        result = std.array.replace(result, " ", "_");
        result = std.array.replace(result, "⇒", "");
        result = std.array.replace(result, "__", "_");
        result = std.array.replace(result, "ε", "Epsi");
        
        cache[tuple(prod, position)] = result;
        
        return result;
    }
    
    void genGrammarSlotEnum(Sink)(Sink sink)
    {
        
        string templ = q"<
        enum Label
        {
            Loop,
            %-(%s,
            %)
        };
        >".outdent;
        string[] replacements;
        foreach(sym; gram.nonterminals)
            replacements ~= format("_%s", sym.name);
        
        foreach(prod; gram.productions)
            foreach(pos; 0 .. prod.rhs.length+1)
            {
                if(pos == 0)
                    replacements ~= labelName(prod, pos); 
                else if(pos != prod.rhs.length && !prod.rhs[pos].isTerminal)
                    replacements ~= labelName(prod, pos); 
                else if(pos == prod.rhs.length && !prod.rhs[pos-1].isTerminal)
                    replacements ~= labelName(prod, pos); 
            }
        formattedWrite(sink, templ, replacements);
    }

    void genCodeForRule(Sink)(Sink sink, Symbol nonterm)
    {
        string ifCond = q"<
            if(compare(input[curIdx], %-(TK.%s,%)))
            {
                context.add(%s, curIdx, curTop);
            }
            >".outdent;
        
        sink.put(format("case _%s:\n", nonterm.name));
        foreach(prod; gram.productions.filter!(x => x.sym == nonterm))
        {
            string[] toTestAgainst;
            foreach(sym; (*(*sets.firstPlus)[prod])[])
                toTestAgainst ~= sym.name;
            
            string label = labelName(prod, 0);
            sink.put(format(ifCond, toTestAgainst, label));
        }
        sink.put(format("curLabel = Loop; break;\n"));
        
        foreach(prod; gram.productions.filter!(x => x.sym == nonterm))
        {
            sink.formattedWrite("case %s:\n", labelName(prod, 0));
            genCodeForAlternative(sink, prod);
        }
    }
    
    void genCodeForAlternative(Sink)(Sink sink, Production prod)
    {
        if(prod.rhs.length == 1 && prod.rhs[0] == G.Epsilon)
            genCodeForEpsilonAlt(sink, prod);
        else if(prod.rhs.length == 1 && prod.rhs[0].isTerminal)
            genCodeForSingleTerminalAlt(sink, prod);
        else if(prod.rhs.length > 1 && prod.rhs[0].isTerminal)
            genCodeForTerminalAlt(sink, prod);
        else if(prod.rhs.length >= 1 && !prod.rhs[0].isTerminal)
            genCodeForNonTermAlt(sink, prod);
        else
            assert(false);
    }
    
    void genCodeForEpsilonAlt(Sink)(Sink sink, Production prod)
    {
        string templ = q"<
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        >";
        
        sink.put(templ);
    }
    
    void genCodeForSingleTerminalAlt(Sink)(Sink sink, Production prod)
    {
        string templ = 
        q"<curIdx += 1;
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        >".outdent;
        
        sink.put(templ);
    }
    
    void genCodeForTerminalAlt(Sink)(Sink sink, Production prod)
    {
        string templ = q"<
        curIdx += 1;
        %(%s
        )%
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        >".outdent;
        
        string[] gramSlotCode;
        foreach(pos; 1 .. prod.rhs.length)
        {
            string tmp = codeForGrammarSlot(prod, pos);
            gramSlotCode ~= tmp;
        }
        writeln(gramSlotCode);
        formattedWrite(sink, templ, gramSlotCode);
    }
    
    string codeForGrammarSlot(Production prod, size_t pos)
    {
        if(prod.rhs[pos].isTerminal)
        {
            string templTerm = q"<
            if(compare(input[curIdx], %s))
                curIdx += 1;
            >".outdent;
            string compareAgainst = prod.rhs[pos].name;
            
            return format(templTerm, compareAgainst);
        }
        else
        {
            string templNonTerm = q"<
            if(compare(input[curIdx], %-3$(TK.%s,%)))
            {
                curTop = context.create(%1$s, curIdx, curTop);
                curLabel = _%2$s; break;
            }
            else
            {
                curLabel = Loop; break;
            }
            case %4$s:
            >".outdent;
            
            string[] compareAgainst;
            auto set = G.fsReduce(prod.rhs[pos .. $], sets.first);
            if(G.Epsilon in *set)
                set.insert((*(*sets.follow)[prod.sym])[]);
            foreach(sym; (*set)[].filter!(G.NoEpsilon))
                compareAgainst ~= sym.name;
            
            return format(templNonTerm, labelName(prod, pos+1),
                                        prod.rhs[pos].name,
                                        compareAgainst,labelName(prod, pos+1));
        }
    }
    
    void genCodeForNonTermAlt(Sink)(Sink sink, Production prod)
    {
        string templ = q"<
        curTop = context.create(%1$s, curIdx, curTop);
        curLabel = _%2$s; break;
        case %1$s:
            %-3$(%s
            %)
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        >".outdent;
        
        string[] grammarSlotCodes;
        foreach(pos; 1 .. prod.rhs.length)
        {
            grammarSlotCodes ~= codeForGrammarSlot(prod, pos);
        }
        
        sink.formattedWrite(templ, labelName(prod, 1), prod.rhs[0].name, grammarSlotCodes);
    }
    
    void genParseFunction(Sink)(Sink sink, G* gram)
    {
        string templ = q"<
        
        bool parse()
        {
            InputPos curIdx;
            GssId curTop;
            Label curLabel = Label._%s;
            //add start symbol to pending set
            with(Label) {
            
            /* setup for data structures .. ? */
            while(true)
            {
                final switch(curLabel)
                {
                    case Loop:
                    if(context.pending.empty)
                        return (curIdx == input.length);
                    else
                    {
                        auto desc = context.pending.pop;
                        curIdx = desc.pos;
                        curTop = desc.top;
                        curLabel = to!Label(desc.slot);
                        break;
                    }
                    %s
                }
            }
            }
        }
        >".outdent;
        
        auto app = appender!string();
        foreach(sym; gram.nonterminals)
        {
            genCodeForRule(app, sym);
        }
        
        sink.formattedWrite(templ, gram.startSymbol.name, app.data);
    }
    
    void genParserStruct(Sink)(Sink sink, G* gram)
    {
        string templ = q"<
        struct Recognizer(Token, TK, alias compare)
        {
            %1$s
            Token[] input;
            GllContext context;
        this(Token[] _input)
        {
            input = _input;
            context = new GllContext();
        }
        %2$s
        }
        >".outdent;
        
        auto code = appender!string();
        genParseFunction(code, gram);
        
        auto app = appender!string();
        genGrammarSlotEnum(app);
        sink.formattedWrite(templ, app.data, code.data, gram.startSymbol.name);
    }
}
