
import std.container, std.range, std.algorithm, std.array, std.stdio, std.typecons,
       std.format;

/*
 * This module implements the GSS and SPPF needed in every gll parser,
 * as well as the sets U_i
 */

import grammar;

struct InputPos
{
    uint _pos;
    alias _pos this;
}

struct GssLabel
{
    this(GrammarSlot _slot, InputPos _pos)
    {
        slot = _slot;
        pos = _pos;
    }
    InputPos pos;
    GrammarSlot slot;
}

struct Gss
{
    struct GssNode
    {
        this(GssLabel _label)
        {
            label = _label;
            parents.insertBack(12);
            parents.clear;
        }

        GssLabel label;
        Array!GssId parents;
    }

    // can be used to lookup a gssNode
    // 2^32 should be more than enough
    alias uint GssId;
    alias GssId[const(GssLabel)] GssLookupTable;

    enum L0 = GssLabel(GrammarSlot(0), InputPos(0));

    static Gss opCall()
    {
        Gss gss;
        gss._data.insertBack(GssNode(L0));
        gss._index[L0] = 0;
        return gss;
    }

    // return value for create
    alias Tuple!(GssId, "id", InputPos[], "poppedAt") CreateRT;
    /**
     * Create a new node and return it's identifier and the positions
     * where it has been popped earlier.
     */
    CreateRT create(GrammarSlot slot, InputPos pos, GssId parent)
    {

        // check if there already exists a GssNode labelled (slot, i)
        GssLabel label = GssLabel(slot, pos);
        GssId id;
        if(auto node = label in _index)
        {
            // node exists, does edge to designated parent exist?
            id = *node;
            if(!canFind(_data[id].parents[], parent))
            {
                _data[id].parents.insertBack(parent);
                writefln("adding parent %d to %d", parent, id);
            }
        } else
        {
            id = cast(GssId) _data.length;
            GssNode newNode = GssNode(GssLabel(slot, pos));
            _data.insertBack(newNode);
            if(!canFind(_data[id].parents[], parent))
            {
                _data[id].parents.insertBack(parent);
                writefln("adding parent %d to %d", parent, id);
                assert(_data[id].parents.length > 0);
            }
        }

        // check if it was previously popped
        return CreateRT(id, _popped.get(id, []));
    }

    /**
     * Pop a node from the Gss and return all it's parents
     */
    auto pop(GssId elem, InputPos pos)
        in { assert(elem != 0); } // 0 is GssId of L0
    body
    {
        auto entry = _popped[elem];
        if(entry.length != 0)
            assumeSafeAppend(entry);
        entry ~= pos;
        _popped[elem] = entry;

        return _data[elem].parents[];
    }

    /**
     * Given and identifier, look up the real thing and
     * return a pointer to it.
     */
    GssNode opIndex(GssId id) { return _data[id]; }

    /**
     * Write a dot file representing the gss into output
     */
    void gssToDot(Out)(Grammar* gram, Out output)
    {
        output.put("strict digraph Gss {\n");
        string[string] nodeAttrs = ["shape":"box", "style":"solid", "regular":"1"];
        foreach(key; nodeAttrs.byKey)
            formattedWrite(output, "node %s=\"%s\"\n", key, nodeAttrs[key]);

        output.put("\n");

        size_t i = 0;
        foreach(GssNode node; _data[])
        {
            i++;
            formattedWrite(output, "n%d label=\"L:%d, P:%d\"\n", i,node.label.slot, node.label.pos);
        }

        i = 0;
        foreach(GssNode node; _data)
        {
            i++;
            foreach(parent; node.parents)
                formattedWrite(output, "n%d -> n%d\n", i, parent);
        }

        output.put("\n}\n");
    }


    /**
     * Array containing the actual data
     */
    private Array!GssNode _data;

    /**
     * For fast lookup of GssNodes by Label
     */
    GssLookupTable _index;
    /**
     * Remember all elements that have been popped so far.
     */
    private InputPos[][GssId] _popped;
}

unittest {

    Gss gss = Gss();

    Gss.GssId last = 0;
    foreach(ushort i; 0 .. 12)
    {
        auto ret = gss.create(GrammarSlot(i), InputPos(i+2), last);
        last = ret.id;
    }

    auto app = appender!string();
    gss.gssToDot(null, app);
    writeln(app.data);
}

struct Descriptor
{
    this(GrammarSlot _slot, InputPos _pos, Gss.GssId stackTop)
    {
        pos = _pos;
        top = stackTop;
        slot = _slot;
    }

    InputPos pos;
    Gss.GssId top;
    GrammarSlot slot;
}

struct PendingSet
{
private:
    Array!Descriptor[] _R;
    alias Tuple!(GrammarSlot, "slot", Gss.GssId, "stackTop") UElem;
    bool[UElem][] _U;
    size_t ringLength;
    size_t curPos;

    this(size_t ringLength)
    {
        _R.length = ringLength;
        _U.length = ringLength;
    }

    @property
    bool empty()
    {
        if(_R[curPos].length != 0)
            return false;

        immutable start = curPos;
        bool empty = true;
        do {
            dropFirst;
            empty = _R[curPos].length == 0;
        }
        while(empty && curPos != start);

        return empty;
    }

    void dropFirst()
    {
        _U[curPos].clear;
        _R[curPos].length = 0;
        curPos = (curPos + 1) % ringLength;
    }

    Descriptor pop()
    in
    {
        assert(!empty);
    }
    body
    {
        return _R[curPos].removeAny;
    }



    void add(GrammarSlot slot, InputPos pos, Gss.GssId top)
    {
        add(Descriptor(slot, pos, top));
    }

    void add(Descriptor desc)
    {
        immutable idx = desc.pos % ringLength;
        UElem elem = tuple(desc.slot, desc.top);
        if((elem in _U[idx]))
            return;

        _U[idx][elem] = true;
        _R[idx].insert(desc);
    }
}

class GllContext
{
    alias Gss.GssId GssId;

    Gss gss;
    PendingSet pending;

    GssId create(GrammarSlot slot, InputPos pos, GssId parent)
    {
        auto result = gss.create(slot, pos, parent);
        foreach(_pos; result.poppedAt)
            add(slot, _pos, parent);
        return result.id;
    }

    void add(GrammarSlot slot, InputPos pos, GssId top)
    {
        pending.add(slot, pos, top);
    }

    void add(Descriptor desc) { pending.add(desc); }

    void pop(GssId u, InputPos pos)
    {
        // GssId of L0 is 0
        if(u == 0)
            return;
        auto r = gss.pop(u, pos);
        foreach(id; r)
            add(gss[u].label.slot, pos, id);
    }
}