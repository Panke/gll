import probat.all;

import std.stdio;

import gll.data;
import gll.grammar;

unittest {

    testCase("Creation",
    {
        Gss gss = Gss();
    });

    testCase("Add to first elem and check popped parents",
    {
        alias Gss.GssId GssId;
        Gss gss = Gss();
        foreach(ushort i; 1..11)
        {
            auto res = gss.create(GrammarSlot(i), InputPos(0), GssId(0));
            writeln(res.id);
            assNeq(res.id, 0);
        }

        foreach(ushort i; 1 .. 11)
        {
            auto res = gss.create(GrammarSlot(1), InputPos(1), GssId(i));
            writeln(res.id);
        }

        // pop and check if it has indeed 10 parents
         auto res = gss.pop(GssId(11), InputPos(1));
         assEq(10, res.length);
    });
}
