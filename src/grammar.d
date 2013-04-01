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
       
import org.panke.container.set : HashSet;
import org.panke.meta.meta;
import gll.util;

enum IsTerminal : bool { yes = true, no = false }
enum IsEpsilon : bool { yes = true, no = false }


struct Grammar(TK)
{
    Symbol startSymbol;
    Production[] productions;

    this(Symbol start, Production[] prods=[])
    {
        startSymbol = start;
        if(prods.length)
            productions = prods;
    }

    alias HashSet!Symbol Set;
    alias Tuple!(Set*[Symbol], "first", Set*[Symbol], "follow",
                 Set*[Production], "firstPlus") Sets;
    
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
        auto lhsFsp = sets.firstPlus[lhs];
        auto rhsFsp = sets.firstPlus[rhs];
        return setIntersection((*lhsFsp)[], (*rhsFsp)[]).walkLength > 0;
    }


    
    Set*[Symbol] firstSets()
        out(result) { assert(result !is null); }
    body
    {
        Set*[Symbol] sets;
        // initialize sets
        foreach(sym; this.symbols)
        {
            auto set = new Set;
            if( sym.isTerminal )
                set.insert(sym);
            
            sets[sym] = set;
        }

        // fix point iterate
        bool changes;
        do {
            changes = false;
            foreach(prod; productions)
            {
                auto sym = prod.sym;
                auto rhs = prod.rhs;
                auto fS = sets[sym];
                size_t count = fS.length;
                foreach(i, part; rhs)
                {
                    auto firstSetPart = sets[part];
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

     
    Set*[Symbol] followSets(Set*[Symbol] _first = null)
        out(result) { assert(result !is null); }
    body
    {
        Set*[Symbol] follow;
        foreach(sym; symbols)
            follow[sym] = new Set;

        Set*[Symbol] first = _first is null ? this.firstSets() : _first;
        
        follow[startSymbol].insert(Eof);
        bool changes;
        do {
            changes = false;
            foreach(prod; productions)
            {
                auto trailer = follow[prod.sym];
                foreach(part; retro(prod.rhs))
                {
                    size_t count = follow[part].length;
                    if(part.isTerminal)
                    {
                        trailer = first[part];
                        continue;
                    }

                    follow[part].insert((*trailer)[]);
                    trailer.insert((*first[part])[].filter!(NoEpsilon));

                    if(follow[part].length > count)
                        changes = true;
                }
            }
        } while(changes);

        return follow;
    }

    Sets firstFallowSets(Set*[Symbol] _first = null, Set*[Symbol] _follow = null)
        out(result) { assert(result.first !is null); }
    body
    {
        Set*[Symbol] first = _first is null ? firstSets() : _first;
        Set*[Symbol] follow = _follow is null ? followSets(_first) : _follow;
        Set*[Production] firstPlus;
        foreach(prod; productions)
        {
            Set* tmp = new Set;
            foreach(i, sym; prod.rhs)
            {
                tmp.insert((*first[sym])[].filter!NoEpsilon);
                // last item contains epsilon
                if(Epsilon in (*first[sym]))
                {
                    if(i == prod.rhs.length - 1)
                        tmp.insert(Epsilon);
                }
                else break;
            }

            if(Epsilon in *tmp)
            {
                tmp.insert((*follow[prod.sym])[]);
                tmp.remove(Epsilon);
            }


            firstPlus[prod] = tmp;
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
        return productions.map!((a) => a.sym).uniq;
    }

     
    auto terminals()
    {
        // need cast because of  issues
        Symbol[] tmp = cast(Symbol[])productions.map!(( a) => a.rhs[0..$]).joiner.array;
        return sort(tmp).uniq;
    }

     
    auto symbols()
    {
        return chain(terminals, nonterminals);
    }

    /**
     * normalize grammer by removing duplicates etc.
     *
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
    
    struct Symbol 
    {
        static string toString(TK k) { return to!string(k); }
        string name;
        IsTerminal isTerminal = IsTerminal.no;
        IsEpsilon isEpsilon = IsEpsilon.no;
        TK kind;
        private debug auto _TKNames = Array!(string, Map!(toString, EnumMembers!TK));
        // generally used to define non-terminal symbols.
        // name must be different from every element of TK
        this(string name, IsEpsilon eps=IsEpsilon.no)
        in
        {
            debug assert(!_TKNames.canFind(name));
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
        
        bool opEquals(ref Symbol rhs)
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
            formattedWrite(sink, "% s%s", "•", sym.name);
        else
            formattedWrite(sink, " %s", sym.name);
    }
    if(pos == prod.rhs.length)
        formattedWrite(sink, "•");
}



