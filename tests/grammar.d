import std.algorithm, std.range, std.array, std.container, std.traits,
std.functional, std.stdio, std.file, std.format;

import probat.all;

import gll.grammar;

immutable S = Symbol("S");
immutable E = Symbol("E");
immutable T = Symbol("T");
immutable F = Symbol("F");
immutable Plus = Symbol("+", IsTerminal.yes);
immutable Minus = Symbol("-", IsTerminal.yes);
immutable Times = Symbol("*", IsTerminal.yes);
immutable Semi = Symbol(";", IsTerminal.yes);
immutable N = Symbol("n", IsTerminal.yes);

auto SE = Production(S, [E]);
auto SES = Production(S, [E, Semi, S]);
auto SEpsi = Production(S, [Epsilon]);

auto ET1 = Production(E, [T]);
auto ET2 = Production(E, [T, Plus, T]);
auto ET3 = Production(E, [T, Minus, T]);

auto T1 = Production(T, [F, Times, F]);
auto T2 = Production(T, [F]);

auto F1 = Production(F, [N]);

unittest {
    testCase("test LL1 property",
    {
        Grammar g = Grammar(S, [SE, SES, ET1, T2, F1]);
        auto sets = g.firstSets();
//         assert(!g.isLL1(S));
    }, "LL1");
}
