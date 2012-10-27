/**
 *
 * This modules includes functionality to deal with grammars.
 *
 * Will include: * algorithm to compute first and follow sets
 * 		 * ...
 */


import std.container, std.algorithm, std.range, std.array, std.stdio;


enum IsTerminal : bool { yes = true, no = false }
enum IsEpsilon : bool { yes = true, no = false }

struct Symbol {
    string name;
    IsTerminal isTerminal = IsTerminal.no;
    IsEpsilon isEpsilon = IsEpsilon.no;

    this(string name, IsTerminal term=IsTerminal.no, IsEpsilon eps=IsEpsilon.no)
    {
	this.name=name;
	this.isTerminal=term;
	this.isEpsilon=eps;
    }

    const
    bool opEquals(ref const(Symbol) rhs)
    {
	return name == rhs.name;
    }

    const
    int opCmp(ref const(Symbol) rhs)
    {
	if(name < rhs.name)
	    return -1;
	if(name > rhs.name)
	    return 1;
	return 0;
    }
}

enum Epsilon = Symbol("ε", IsTerminal.yes, IsEpsilon.yes);
enum EOF = Symbol("$", IsTerminal.yes, IsEpsilon.no);

bool NoEpsilon(Symbol sym) { return !sym.isEpsilon; }

struct Production
{
    Symbol sym;
    Symbol[] rhs;

    this(Symbol sym, Symbol[] rhs) { this.sym = sym; this.rhs=rhs; }

    const
    bool opEquals(ref const(Production) rhs)
    {
	return sym == rhs.sym && this.rhs == rhs.rhs;
    }
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

    alias RedBlackTree!Symbol Set;
    const
    Set[Symbol] firstSets()
    {
	Set[Symbol] sets;
	// initialize sets
 	foreach(sym; this.symbols)
 	{
	    RedBlackTree!Symbol set = make!Set();
	    if( sym.isTerminal )
		set.insert(sym);
	    else
	    {
		// fuck you, std.container
		set.insert(sym);
		set.clear();
	    }
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

    const @property
    Set[Symbol] followSets()
    {
	Set[Symbol] follow;
	Set[Symbol] first = this.firstSets;
	// initialize sets, i hate you std.container
	foreach(sym; symbols)
	{
	    Set tmp = make!Set();
	    tmp.insert(sym);
	    tmp.clear();
	    follow[sym] = tmp;
	}
	follow[startSymbol].insert(EOF);

	bool changes;
	do {
	    changes = false;
	    foreach(prod; productions)
	    {
		auto trailer = follow[prod.sym].dup;
		foreach(part; retro(prod.rhs))
		{
		    size_t count = follow[part].length;
		    if(part.isTerminal)
		    {
			trailer = first[part].dup;
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

    const
    Symbol[][Symbol] followSet();

    enum AddMod { Sort, DontSort };
    void addProduction(ref Production prod, AddMod mod = AddMod.Sort)
    {
	productions ~= prod;
	if(mod == AddMod.Sort)
	    schwartzSort!((a) => a.sym)(productions);
    }

    void addProductions(Production[] prods)
    {
	foreach(p; prods) addProduction(p, AddMod.DontSort);
    }

    const @property
    auto nonterminals()
    {
	return productions.map!((a) => a.sym).uniq;
    }

    const @property
    auto terminals()
    {
	// need cast because of const issues
	Symbol[] tmp = cast(Symbol[]) productions.map!((a) => a.rhs[0..$]).joiner.array;
	return sort(tmp).uniq;
    }

    const @property
    auto symbols()
    {
	return chain(terminals, nonterminals);
    }


}

unittest {
    immutable Symbol A = Symbol( "A" );
    immutable Symbol B = Symbol( "B" );
    immutable Symbol C = Symbol( "C" );
    immutable Symbol a = Symbol( "a", IsTerminal.yes );
    immutable Symbol b = Symbol( "b", IsTerminal.yes );
    immutable Symbol c= Symbol( "c", IsTerminal.yes );

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
}


private void printSet(Grammar.Set[Symbol] sets)
{
    foreach(sym; sets.byKey())
    {
	writef("%s: ", sym.name);
	auto fs = sets[sym];
	foreach(first; fs)
	{
	    writef("%s ", first.name);
	}
	writeln;
    }
}

int main()
{
    return 0;
}

