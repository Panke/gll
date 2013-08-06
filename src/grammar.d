module gll.grammar;
/**
 *
 * This modules includes functionality to deal with grammars.
 *
 * Will include: * algorithm to compute first and follow sets
 *               * ...
 */

import std.algorithm, std.range, std.array, std.stdio,
       std.typecons, std.conv, std.format, std.traits,
       std.typetuple;
       
import org.panke.container.set;
import org.panke.container.map : TreeMap = Map;
import org.panke.meta.meta;
import gll.util;

enum IsTerminal : bool { yes = true, no = false }
enum IsEpsilon : bool { yes = true, no = false }


struct Grammar(TK)
{
    Symbol startSymbol;
    Production[] productions;
    alias TK TokenKind;
    this(Symbol start, Production[] prods=[])
    {
        startSymbol = start;
        if(prods.length)
            productions = prods;
    }

    alias CritBitTree!(Symbol) Set; 
    alias TreeMap!(Symbol, Set*) SSMap;
    alias TreeMap!(Production, Set*) PSMap;
    alias Tuple!(SSMap*, "first", SSMap*, "follow",
                 PSMap*, "firstPlus") Sets;
    
    bool isLL1( Symbol nonterm, Sets sets = Sets.init)
    {
        if(sets.first is null)
            sets = firstFallowSets();
        
        // productions for sym
        auto prods = productions.filter!(x => x.sym == nonterm);
        foreach(pair; subsets!(false)(prods, 2))
        {
            auto first = pair.front; pair.popFront;
            auto second = pair.front;
            if(ambigious(firstFallowSets, first, second))
                return false;
        }
        return true;
    }

    bool isLL1(Sets sets = Sets.init)
    {
        auto ffSets = sets == Sets.init ? firstFallowSets : sets;
        auto m = map!((Symbol x) => isLL1(x, ffSets))(this.nonterminals);
        return ! m.canFind(false);
    }

    bool ambigious(Sets sets, Production lhs, Production rhs)
    {
        Set* lhsFsp = (*sets.firstPlus)[lhs];
        auto rhsFsp = (*sets.firstPlus)[rhs];
        return setIntersection((*lhsFsp)[], (*rhsFsp)[]).walkLength > 0;
    }

    SSMap* firstSets()
        out(result) { assert(result !is null); }
    body
    {
        SSMap* sets = new SSMap;
        // initialize sets
        foreach(Symbol sym; this.symbols)
        {
            auto set = new Set;
            if( sym.isTerminal )
                set.insert(sym);
            (*sets)[sym] = set;
        }
        // fix point iterate
        bool changes;
        do {
            changes = false;
            foreach(prod; productions)
            {
                auto sym = prod.sym;
                auto rhs = prod.rhs;
                auto fS = (*sets)[sym];
                size_t count = fS.length;
                foreach(i, part; rhs)
                {
                    auto firstSetPart = (*sets)[part];
                    if(Epsilon in *firstSetPart)
                    {
                        fS.insert((*firstSetPart)[].filter!(NoEpsilon));
                        // if it's the last item and it derives the empty string,
                        // add the empty string
                        if(i == rhs.length-1)
                            fS.insert(Epsilon);
                    }
                    else
                    {
                        fS.insert((*firstSetPart)[]);
                        // break at first symbol that does not
                        // derive the empty string
                        break;
                    }
                }
                if(fS.length > count)
                    changes = true;
            }
        } while(changes);
        return sets;
    }
    
    static Set* fsReduce(Symbol[] syms, SSMap* firstSets, Set* result = null)
    {
        if(result is null)
            result = new Set;
        
        foreach(i, part; syms)
        {
            auto firstSetPart = (*firstSets)[part];
            if(Epsilon in *firstSetPart)
            {
                result.insert((*firstSetPart)[].filter!(NoEpsilon));
                // if it's the last item and it derives the empty string,
                // add the empty string
                if(i == syms.length-1)
                    result.insert(Epsilon);
            }
            else
            {
                result.insert((*firstSetPart)[]);
                // break at first symbol that does not
                // derive the empty string
                break;
            }
        }
        return result;
    }
    
    SSMap* followSets(SSMap* _first = null)
        out(result) { assert(result !is null); }
    body
    {
        SSMap* follow = new SSMap;
        foreach(sym; symbols)
            (*follow)[sym] = new Set;

        auto first = _first is null ? this.firstSets() : _first;
        
        (*follow)[startSymbol].insert(Eof);
        bool changes;
        do {
            changes = false;
            foreach(prod; productions)
            {
                Set* trailer = follow.at(prod.sym);
                foreach(part; retro(prod.rhs))
                {
                    size_t count = (*follow)[part].length;
                    if(part.isTerminal)
                    {
                        trailer = (*first)[part];
                        continue;
                    }

                    (*follow)[part].insert((*trailer)[]);
                    trailer.insert((*first.get(part))[].filter!(NoEpsilon));
//                     trailer.insert((*(*first)[part]))[].filter!(NoEpsilon));

                    if(follow.at(part).length > count)
                        changes = true;
                }
            }
        } while(changes);

        return follow;
    }

    Sets firstFallowSets(SSMap* _first = null, SSMap* _follow = null)
        out(result) { assert(result.first !is null); }
    body
    {
        SSMap* first = _first is null ? firstSets() : _first;
        SSMap* follow = _follow is null ? followSets(_first) : _follow;
        PSMap* firstPlus = new PSMap;
        foreach(prod; productions)
        {
            Set* tmp = new Set;
            foreach(i, sym; prod.rhs)
            {
                tmp.insert((*first.get(sym))[].filter!(NoEpsilon));
//                 tmp.insert((*first[sym])[].filter!NoEpsilon);
                // last item contains epsilon
                if(Epsilon in (*first.get(sym)))
                {
                    if(i == prod.rhs.length - 1)
                        tmp.insert(Epsilon);
                }
                else break;
            }

            if(Epsilon in *tmp)
            {
                tmp.insert((*follow.get(prod.sym))[]);
                tmp.remove(Epsilon);
            }


            (*firstPlus)[prod] = tmp;
        }
        return Sets(first, follow, firstPlus);
    }
   
    enum AddMod { Sort, DontSort };
    void addProduction(ref Production prod, AddMod mod = AddMod.Sort)
    {
        productions ~= prod;
        if(mod == AddMod.Sort)
            sort(productions);
    }

    void addProductions(Production[] prods)
    {
        foreach(p; prods) addProduction(p, AddMod.DontSort);
        sort(productions);
    }

    auto nonterminals()
    {
        return filter!(x => x.isTerminal == IsTerminal.no)(symbols);
    }

    auto terminals()
    {
        return filter!(x => x.isTerminal == IsTerminal.yes)(symbols);
    }

    auto symbols()
    {
        return chain(
                    productions.map!((a) => a.rhs).joiner,
                    productions.map!((a) => a.sym))
                   .array
                   .sort
                   .uniq;
    }
    
    size_t ringLength()
    {
        return productions.map!(x => x.rhs.length)
               .reduce!(max);
    }
    
    /**
     * normalize grammer by removing duplicates etc.
     */
    void normalize()
    {
        removeDuplicates();
    }

private:
    void removeDuplicates()
    {
        Production[] newArr = productions.uniq.array;
        productions = newArr;
    }
    
public:
    static struct Symbol 
    {
        string name;
        IsTerminal isTerminal = IsTerminal.no;
        IsEpsilon isEpsilon = IsEpsilon.no;
        TK kind;
       
        static string toString(TK k) { return to!string(k); }
        //private debug auto _TKNames = Array!(string, Map!(toString, EnumMembers!TK));
        
        // generally used to define non-terminal symbols.
        // name must be different from every element of TK
        this(string name, IsEpsilon eps=IsEpsilon.no)
        in
        {
          //  debug assert(!_TKNames.canFind(name));
        }
        body
        {
            this.name=name;
            this.isTerminal = eps ? IsTerminal.yes : IsTerminal.no;
            this.isEpsilon = eps;
        }
        
        this(TK kind)
        {
            this.name = to!string(kind);
            this.isTerminal = IsTerminal.yes;
            this.isEpsilon = IsEpsilon.no;
            this.kind = kind;
        }
        
        bool opEquals(Symbol rhs)
        {
            return name == rhs.name;
        }

        int opCmp(ref Symbol rhs)
        {
            if(name < rhs.name)
                return -1;
            if(name > rhs.name)
                return 1;
            return 0;
        }

        hash_t toHash()
        {
            return typeid(name).getHash(&name);
        }
    }
    
    enum Epsilon = Symbol("ε",  IsEpsilon.yes);
    enum Eof = Symbol(TK.Eof);

    static bool NoEpsilon(Symbol sym) { return !sym.isEpsilon; }

    struct Production
    {
        Symbol sym;
        Symbol[] rhs;

        this(Symbol sym, Symbol[] rhs)
            in { assert(!sym.isTerminal); }
        body
        { 
            this.sym = sym; this.rhs=rhs; 
        }

        int opCmp(ref Production op)
        {
            int symCmp;
            symCmp = sym < op.sym ? -1 : symCmp;
            symCmp = sym > op.sym ? 1 : symCmp;

            if(symCmp == 0)
                return this.rhs < op.rhs ? -1 : (this.rhs > op.rhs);
            else
                return symCmp;
        }

        bool opEquals(ref Production rhs)
        {
            return sym == rhs.sym && this.rhs == rhs.rhs;
        }
        
        string toString()
        {
            return sym.name ~ " --> " ~ to!string(joiner(map!(x => x.name.dup)(rhs), " "));
        }
    }
}

void printSet(U, T)(U[T] sets)
{
    foreach(t; sets.byKey())
    {
        writef("%s: ", to!string(t));
        auto fs = sets[t];
        foreach(first; fs)
        {
            writef("%s ", first.name);
        }
        writeln;
    }
}

void wDotItem(Sink, Production)(Sink sink, Production prod, size_t pos)
{
    formattedWrite(sink, "%s ⇒", prod.sym.name);
    if(prod.rhs.length == 0)
    {
        formattedWrite(sink, " ε");
        return;
    }

    foreach(i, sym; prod.rhs)
    {
        if(i == pos)
            formattedWrite(sink, "%s%s", "•", sym.name);
        else
            formattedWrite(sink, " %s", sym.name);
    }
    if(pos == prod.rhs.length)
        formattedWrite(sink, "•");
}

