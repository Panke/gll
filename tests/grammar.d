import std.algorithm, std.range, std.array, std.traits,
std.functional, std.stdio, std.file, std.format;

import probat.all;

import gll.grammar;

enum TokenKind { Eof, Plus, Minus, Times, Semi, N }

unittest {
    alias Grammar!TokenKind.Symbol Symbol;
    alias Grammar!TokenKind.Production Production;
    auto S = Symbol("S");
    auto E = Symbol("E");
    auto T = Symbol("T");
    auto F = Symbol("F");
    auto Plus = Symbol(TokenKind.Plus);
    auto Minus = Symbol(TokenKind.Minus);
    auto Times = Symbol(TokenKind.Times);
    auto Semi = Symbol(TokenKind.Semi);
    auto N = Symbol( TokenKind.N);

    auto SE = Production(S, [E]);
    auto SES = Production(S, [E, Semi, S]);
    auto SEpsi = Production(S, [Grammar!(TokenKind).Epsilon]);

    auto ET1 = Production(E, [T]);
    auto ET2 = Production(E, [T, Plus, T]);
    auto ET3 = Production(E, [T, Minus, T]);
    auto EN = Production(E, [N]);
    auto T1 = Production(T, [F, Times, F]);
    auto T2 = Production(T, [F]);

    auto F1 = Production(F, [N]);

    testCase("test LL1 property on non LL1 grammar",
    {
        auto g = Grammar!TokenKind(S, [SE, SES, EN]);
        auto sets = g.firstFallowSets();
        assFalse(g.isLL1(S, sets));
    }, "LL1-1");
    testCase("test LL1 property on LL1 grammar",
    {
        auto g = Grammar!TokenKind(S, [SE, ET1, T2, F1]);
        auto sets = g.firstFallowSets();
        assTrue(g.isLL1(S, sets));
    }, "LL1-2");

    testCase("test LL1 property on grammar without terminals",
    {
        auto g = Grammar!TokenKind(S, [SE, ET1, T2]);
        auto sets = g.firstFallowSets();
        assTrue(g.isLL1(S, sets));
    }, "LL1-3");

    testCase("test LL1 property on grammar without terminals",
    {
        auto g = Grammar!TokenKind(S, [SE, ET1, ET2, ET3, T2, F1]);
        auto sets = g.firstFallowSets();
        assFalse(g.isLL1(E, sets));
        assFalse(g.isLL1(sets));
    }, "LL1-4");

    // test some simpler grammar functions like firstSets
    testCase("test first sets",
    {
        auto g = Grammar!TokenKind(S, [SE, ET1, ET2, ET3, T2, F1]);
        auto sets = g.firstFallowSets();
        assEq(sets.first.at(E).length, 1);
    });
}
