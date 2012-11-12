module gll.data;

import  std.range, std.algorithm, std.array, std.stdio, std.typecons,
       std.format, std.exception;

/*
 * This module implements the GSS and SPPF needed in every gll parser,
 * as well as the sets U_i
 */

import gll.grammar;

struct InputPos
{
    uint _pos;
    alias _pos this;
}


// can be used to lookup a gssNode
// 2^32 should be more than enough
struct GssId { uint _id; alias _id this; }

template Gll(alias Label)
{

alias Label GrammarSlot;
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
            parents = new Array!GssId();
        }

        GssLabel label;
        Array!GssId* parents;
    }

    alias GssId[const(GssLabel)] GssLookupTable;

    enum L0 = GssLabel(cast(GrammarSlot)(0), InputPos(0));

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
        if(auto idxptr = label in _index)
        {
            // node exists, does edge to designated parent exist?
            id = *idxptr;
            GssNode node = _data[id];
            if(!canFind((*node.parents)[], parent))
            {
                node.parents.insertBack(parent);
            }
        } else
        {
            id = GssId(cast(ushort) _data.length);
            GssNode node = GssNode(GssLabel(slot, pos));
            node.parents.insertBack(parent);
            _data.insertBack(node);
            _index[node.label] = id;
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
        auto entry = _popped.get(elem, []);
        if(entry.length != 0)
            assumeSafeAppend(entry);
        entry ~= pos;
        _popped[elem] = entry;

        return (*_data[elem].parents)[];
    }

    /**
     * Given and identifier, look up the real thing and
     * return a pointer to it.
     */
    ref GssNode opIndex(GssId id) { return _data[id]; }

    /**
     * Write a dot file representing the gss into output
     */
    void gssToDot(Out)(Grammar* gram, Out output)
    {
        output.put("strict digraph Gss {\n");
        string[string] nodeAttrs = ["shape":"box", "style":"solid", "regular":"1"];
        foreach(key; nodeAttrs.byKey)
            formattedWrite(output, "node [%s=%s];\n", key, nodeAttrs[key]);

        output.put("\n");

        size_t i = 0;
        foreach(GssNode node; _data[])
        {
            i++;
            formattedWrite(output, "n%d [label=\"L:%d, P:%d\"]\n", i,node.label.slot, node.label.pos);
        }

        i = 0;
        foreach(GssNode node; _data)
        {
            i++;
            foreach(parent; (*node.parents)[])
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

struct Descriptor
{
    this(GrammarSlot _slot, InputPos _pos, GssId stackTop)
    {
        pos = _pos;
        top = stackTop;
        slot = _slot;
    }

    InputPos pos;
    GssId top;
    GrammarSlot slot;
}

struct PendingSet
{
private:
    Array!Descriptor[] _R;
    alias Tuple!(GrammarSlot, "slot", GssId, "stackTop") UElem;
    bool[UElem][] _U;
    size_t ringLength;
    size_t curPos;

public:
    this(size_t _ringLength)
    {
        _R.length = _ringLength;
        _U.length = _ringLength;
        this.ringLength = _ringLength;
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

    @property
    size_t length()
    {
        return reduce!"a+b"(map!((ref r) => r.length)(_R));
    }

    void dropFirst()
    {
        _U[curPos].clear;
        _R[curPos].length = 0;
        curPos = (curPos + 1) % ringLength;
    }

    Descriptor pop()
    {
        enforce(!empty);
        return _R[curPos].removeAny;
    }

    void add(GrammarSlot slot, InputPos pos, GssId top)
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
        _R[idx].insertBack(desc);
    }
}

class GllContext
{
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
}
/**
 * Simple and dump, dynamically growing vector class
 * that has value semantics and allocates from the gc heap.
 *
 * Used because std.container gives me headaches.
 */


struct Array(T)
{
    this(this)
    {
        debug writeln("array dupped");
        _data = _data.dup;
    }

    void insertBack(U)(U elem)
        if(is(U : T))
    {
        if(_data.length == _length)
            resize();
        assert(_data.length > _length);
        _data[_length] = elem;
        ++_length;
    }

    ref T opIndex(size_t idx)
    {
        debug assert(idx < _length);
        return _data[idx];
    }

    @property
    size_t length() { return _length; }

    @property
    void length(size_t newLength)
    {
        debug assert(newLength >= 0);
        if(newLength > _length)
            resize(newLength);
        _length = newLength;
    }

    Range opSlice()
    {
        return Range(_data[0 .. _length]);
    }

    Range opSlice(size_t start, size_t end)
    in
    {
        assert(start > 0);
        assert(start > 0);
        assert(end <= _length);
    } body {
        return Range(_data[start .. end]);
    }

    T removeAny()
    {
        debug assert(_length > 0);
        _length--;
        return _data[_length];
    }

private:
    void resize(size_t cap = 0 )
    {
        if(cap > _data.length)
            _data.length = cap;
        else
            _data.length = cast(size_t) ((_data.length+128) * 1.5);
    }

    T[] _data;
    size_t _length;

    struct Range
    {
        T[] slice;
        alias slice this;
    }
}

