module tests.gll;

import gll.grammar, gll.gll;
import std.algorithm, std.range, std.array, std.traits,
std.functional, std.stdio, std.file, std.format, std.conv, std.typetuple, std.typecons;

unittest {

    enum Toks { Eof, a, b, c }
    alias Grammar!Toks G;
    G.Symbol A = G.Symbol( "A" );
    G.Symbol B = G.Symbol( "B" );
    G.Symbol C = G.Symbol( "C" );
    G.Symbol a = G.Symbol(Toks.a);
    G.Symbol b = G.Symbol(Toks.b);
    G.Symbol c = G.Symbol(Toks.c);

    G.Production prd5 = G.Production( C, [A, B, C] );
    G.Production prd3 = G.Production( B, [b] );
    G.Production prd1 = G.Production( A, [ a ] );
    G.Production prd2 = G.Production( B, [B, A ]);
    G.Production prd4 = G.Production( B, [G.Epsilon] );
    G.Production prd6 = G.Production( A, [G.Epsilon] );
    G.Production prd7 = G.Production( C, [ c ] );

    G g = G(c, []);
    g.addProductions([prd1, prd2, prd3, prd4, prd5, prd6, prd7]);

//     auto app = appender!(string)();
    auto gen = Generator!G(&g);
    gen.precalc;
//     writeln(app.data);
}
