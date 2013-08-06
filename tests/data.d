module tests.data;

import std.stdio;

import probat.testtools;
import probat.all;
import gll.data;
import gll.grammar;

enum TestLabel
{
    A, B, C, D
}

alias TestLabel GrammarSlot;
unittest
{
    testCase("add and remove descriptor from PendingSet",
    {
        enum rl = 4;
        PendingSet set = PendingSet(rl);
        Descriptor desc = Descriptor( 1, InputPos(1), GssId(0));
        set.add(desc);
        auto res = set.pop();
        assEq(res, desc);
    });

    testCase("check correct return order of PendingSet",
    {
        enum rl = 4;
        PendingSet set = PendingSet(rl);
        assert(set.empty);
        foreach(ushort i; 0..4)
        {
            set.add(cast(GrammarSlot) i, InputPos(1), GssId(0));
            set.add(cast(GrammarSlot) i, InputPos(2), GssId(0));
        }
        foreach(ushort i; 0..4)
        {
            set.pop();
        }
        foreach(ushort i; 0..4)
            set.add(cast(GrammarSlot) i, InputPos(4), GssId(0));

        foreach(i; 0 .. 4) assEq(set.pop().pos, 2);
        assEq(set.pop().pos, 4);
        assert(!set.empty);
    });

    testCase("check multiple insertion of same element",
    {
        enum rl = 6;
        PendingSet set = PendingSet(rl);
        assert(set.empty);
        foreach(ushort i; 0..10)
            set.add(cast(GrammarSlot) 3, InputPos(12), GssId(12));

        assert(!set.empty);
        assEq(set.length, 1);
    });
}
