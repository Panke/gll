import probat.all;

import std.stdio;

import gll.data;
import gll.grammar;


enum TestLabel { A, B, C, D}
alias TestLabel GrammarSlot;
unittest {

    testCase("Creation",
    {
        Gss gss = Gss();
    });

    testCase("Add to first elem and check popped children",
    {
        Gss gss = Gss();
        foreach(ushort i; 1 .. 11)
        {
            auto res = gss.create(i, InputPos(0), GssId(0));
            assNeq(res.id, 0);
        }

        foreach(ushort i; 1 .. 11)
        {
            auto res = gss.create(1, InputPos(1), GssId(i));
        }

        // pop and check if it has indeed 10 children
         auto res = gss.pop(GssId(11), InputPos(1));
         assEq(10, res.length);
    });

    testCase("check that create returns poppedAt positions correctly",
    {
        Gss gss = Gss();
        auto res = gss.create(1, InputPos(1), GssId(0));

        foreach(i; 0 .. 10)
            auto ret = gss.pop(res.id, InputPos(i));

        res = gss.create(1, InputPos(1), GssId(0));
        assEq(10, res.poppedAt.length);
    });

    testCase("check return value of opIndex is mutable",
    {
        Gss gss = Gss();
        auto old_length = gss[GssId(0)].children.length;
        gss[GssId(0)].children.insertBack(GssId(12));
        assEq(gss[GssId(0)].children.length, old_length+1);
    });
}
