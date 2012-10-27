/**
 *
 * This modules includes functionality to deal with grammars.
 *
 * Will include: * algorithm to compute first and follow sets
 * 		 * ...
 */


import std.container, std.algorithm, std.range, std.array, std.stdio;


struct Symbol {
    string name;
    bool isTerminal = false;
    bool isEpsilon = false;

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

enum Epsilon = Symbol("ε", true, true);
enum EOF = Symbol("$", true, false);

bool NoEpsilon(Symbol sym) { return !sym.isEpsilon; }

struct Production
{
    Symbol sym;
    Symbol[] rhs;

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
    immutable Symbol A = { "A" };
    immutable Symbol B = { "B" } ;
    immutable Symbol C = { "C" };
    immutable Symbol a = { "a", true };
    immutable Symbol b = { "b", true };
    immutable Symbol c= { "c", true };

    Production prd5 = { C, [A, B, C] };
    Production prd3 = { B, [b] };
    Production prd1 = { A, [ a ] };
    Production prd2 = { B, [B, A ]};
    Production prd4 = { B, [Epsilon] };
    Production prd6 = { A, [Epsilon] };
    Production prd7 = { C, [ c ] };

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
    immutable Symbol A = { "A" };
    immutable Symbol B = { "B" } ;
    immutable Symbol C = { "C" };
    immutable Symbol a = { "a", true };
    immutable Symbol b = { "b", true };
    immutable Symbol c= { "c", true };

    Production prd5 = { C, [A, B, C] };
    Production prd3 = { B, [b] };
    Production prd1 = { A, [ a ] };
    Production prd2 = { B, [B, A ]};
    Production prd4 = { B, [Epsilon] };
    Production prd6 = { A, [Epsilon] };
    Production prd7 = { C, [ c ] };

    Grammar g = Grammar(C, []);
    writeln(g.startSymbol);
    g.addProductions([prd1, prd2, prd3, prd4, prd5, prd6, prd7]);

    printSet(g.firstSets());
    writeln;
    printSet(g.followSets());
    return 0;
}

