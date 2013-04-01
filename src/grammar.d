module gll.grammar;
/**
 *
 * This modules includes functionality to deal with grammars.
 *
 * Will include: * algorithm to compute first and follow sets
 *               * ...
 */


enum IsTerminal : bool { yes = true, no = false }
enum IsEpsilon : bool { yes = true, no = false }

template Gram(TK)
{
import std.algorithm, std.range, std.array, std.stdio,
       std.typecons, std.conv, std.format;
import org.panke.container.set : HashSet;
import gll.util;
alias TK TokenKind;
struct Symbol {
    string name;
    IsTerminal isTerminal = IsTerminal.no;
    IsEpsilon isEpsilon = IsEpsilon.no;
    TokenKind kind;

    this(string name, IsEpsilon eps=IsEpsilon.no)
    {
        this.name=name;
        this.isTerminal = eps ? IsTerminal.yes : IsTerminal.no;
        this.isEpsilon = eps;
    }

    this(string name, TokenKind tok)
    {
        this.name = name;
        this.kind = tok;
        isTerminal = IsTerminal.yes;
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
enum EOF = Symbol("$", TokenKind.Eof);

bool NoEpsilon(Symbol sym) { return !sym.isEpsilon; }

struct Production
{
    Symbol sym;
    Symbol[] rhs;

    this(Symbol sym, Symbol[] rhs) { this.sym = sym; this.rhs=rhs; }

    
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

unittest {
    Production a, b;
    assert(is(typeof(a < b)));
    assert(is(typeof(a > b)));
    assert(is(typeof(a == b)));
}

struct Grammar
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
    alias Tuple!(Set[Symbol], "first", Set[Symbol], "follow",
                 Set[Production], "firstPlus") Sets;

    
    bool isLL1( Symbol nonterm, Sets sets = Sets())
    {
        if(sets.first !is null)
            sets = firstFallowSets;

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
        return setIntersection(lhsFsp[], rhsFsp[]).walkLength > 0;
    }


    
    Set[Symbol] firstSets()
        out(result) { assert(result !is null); }
    body
    {
        stdout.flush();
        Set[Symbol] sets;
        // initialize sets
        foreach(sym; this.symbols)
        {
            HashSet!Symbol set;
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
                    if(Epsilon in firstSetPart)
                    {
                        fS.insert(firstSetPart[].filter!(NoEpsilon));
                        // if it's the last item and it derives the empty string,
                        // add the empty string
                        if(i == rhs.length-1)
                            fS.insert(Epsilon);
                    }
                    else
                    {
                        fS.insert(firstSetPart[]);
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

     
    Set[Symbol] followSets(Set[Symbol] _first = null)
        out(result) { assert(result !is null); }
    body
    {
        Set[Symbol] follow;
        Set[Symbol] first = _first is null ? this.firstSets : _first;
        
        follow[startSymbol].insert(EOF);
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

                    follow[part].insert(trailer[]);
                    trailer.insert(first[part][].filter!(NoEpsilon));

                    if(follow[part].length > count)
                        changes = true;
                }
            }
        } while(changes);

        return follow;
    }

    Sets firstFallowSets(Set[Symbol] _first = null, Set[Symbol] _follow = null)
        out(result) { assert(result.first !is null); }
    body
    {
        Set[Symbol] first = _first is null ? firstSets : _first;
        Set[Symbol] follow = _follow is null ? followSets(_first) : _follow;
        Set[Production] firstPlus;
        foreach(prod; productions)
        {
            Set tmp;
            foreach(i, sym; prod.rhs)
            {
                tmp.insert(first[sym][].filter!NoEpsilon);
                // last item contains epsilon
                if(Epsilon in first[sym])
                {
                    if(i == prod.rhs.length - 1)
                        tmp.insert(Epsilon);
                }
                else break;
            }

            if(Epsilon in tmp)
            {
                tmp.insert(follow[prod.sym][]);
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
}
}
/++
unittest {

    Symbol symA = Symbol("A");
    Symbol symB = Symbol("B");
    Production p1 = Production(symA, [symB, symB]);
    Grammar g = Grammar(symA, [p1, p1]);
    g.normalize;
    assert(g.productions.length == 1);
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

    auto fs = g.firstSets();
    assert(equal(fs[A][],[Epsilon, a]));
    assert(equal(fs[B][],[Epsilon, a, b]));
    assert(equal(fs[C][],[a, b, c]));
    auto fls = g.followSets();
    assert(equal(fls[C][], [EOF]));
    assert(fls[A].length == fls[B].length);
    assert(fls[A].length == 4);
    assert(g.isLL1 == false);
}


unittest {
    immutable Symbol S = Symbol( "S" );
    immutable Symbol A = Symbol( "A" );
    immutable Symbol B = Symbol( "B" );
    immutable Symbol C = Symbol( "C" );
    immutable Symbol a = Symbol( "a", IsTerminal.yes );
    immutable Symbol b = Symbol( "b", IsTerminal.yes );
    immutable Symbol c = Symbol( "c", IsTerminal.yes );

    Production prd1 = Production( S, [A, B, C] );
    Production prd2 = Production( B, [b] );
    Production prd3 = Production( A, [ a ] );
    Production prd4 = Production( A, [ b, C ] );
    Production prd5 = Production( A, [ C, C, C ] );
    Production prd6 = Production( C, [ c ] );

    Grammar g = Grammar(A, []);
    g.addProductions([prd1, prd2, prd3, prd4, prd5, prd6]);

    auto fs = g.firstSets();
    assert(g.isLL1 == true);
    auto fsp = g.firstFallowSets;

    // test util.subsets
     Production cprod = Production(S, [A, B, C]);
     Production cprod2 = prd5;

    (Production)[] prods = [cprod, cprod2];
    foreach(pair; prods.subsets(2))
        assert(pair.length == 2);
}
++/

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

/++
unittest
{
    immutable Symbol S = Symbol( "S" );
    immutable Symbol A = Symbol( "A" );
    immutable Symbol B = Symbol( "B" );
    Production prod = Production(S, [S, A, B]);
    auto app = appender!string();
    wDotItem(app, prod, 0);
    assert(equal(app.data,"S ⇒•S A B"));
}
++/


