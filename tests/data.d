module tests.data;

import std.stdio;

import probat.testtools;
import probat.all;
import gll.data;
import gll.grammar;

alias Gss.GssId GssId;
unittest
{
    testCase("add and remove descriptor from PendingSet",
    {
        enum rl = 4;
        PendingSet set = PendingSet(rl);
        Descriptor desc = Descriptor(GrammarSlot(1), InputPos(1), GssId(0));
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
            set.add(GrammarSlot(i), InputPos(1), GssId(0));
            set.add(GrammarSlot(i), InputPos(2), GssId(0));
        }
        foreach(ushort i; 0..4)
        {
            set.pop();
        }
        foreach(ushort i; 0..4)
            set.add(GrammarSlot(i), InputPos(4), GssId(0));

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
            set.add(GrammarSlot(12), InputPos(12), GssId(12));

        assert(!set.empty);
        assEq(set.length, 1);
    });
}
