module gll.data;

import  std.range, std.algorithm, std.array, std.stdio, std.typecons,
       std.format, std.exception;

import org.panke.container.array;
import org.panke.container.set;

/*
 * This module implements the GSS and SPPF needed in every gll parser,
 * as well as the sets U_i
 */

import gll.grammar;

/**
 * Represents an index into the input array
 */
struct InputPos
{
    uint _pos;
    alias _pos this;
}


// can be used to lookup a gssNode
// 2^32 should be more than enough
struct GssId { uint _id; alias _id this; }

/**
 * Represents a code position. These are basically
 * CodeLabels, the label Loop and one Label for each
 * Nonterminal.
 */
alias uint CodeLabel;

/**
 * A GssNode is labeled with both an InputPos and
 * a CodeLabel
 */
struct GssNodeData
{
    this(CodeLabel _slot, InputPos _pos)
    {
        slot = _slot;
        pos = _pos;
    }
    InputPos pos;
    CodeLabel slot;
}

/**
 * Graph structured stack that replaces the call stack in 
 * the GLL algorithm.
 * 
 */
struct Gss
{
    struct GssNode
    {
        this(GssNodeData _data)
        {
            data = _data;
            children = new Array!GssId();
        }

        GssNodeData data;
        // since distinct stacks in the GSS will be merged,
        // a 'thread' can have more than one point to return to.
        Array!GssId* children;
    }

    // for faster Lookup of GssNodes
    alias GssId[const(GssNodeData)] GssLookupTable;

    enum L0 = GssNodeData(cast(CodeLabel)(0), InputPos(0));

    static Gss opCall()
    {
        Gss gss;
        gss._data.insertBack(GssNode(L0));
        gss._index[L0] = 0;
        return gss;
    }

    // return value for create
    alias Tuple!(GssId, "id", Array!(InputPos)*, "poppedAt") CreateRT;
    /**
     * Create a new node and return it's identifier and the positions
     * where it has been popped earlier.
     */
    CreateRT create(CodeLabel slot, InputPos pos, GssId children)
    {

        // check if there already exists a GssNode labelled (slot, i)
        GssNodeData label = GssNodeData(slot, pos);
        GssId id;
        if(auto idxptr = label in _index)
        {
            // node exists, does edge to designated children (i.e returnpoint) exist?
            id = *idxptr;
            GssNode node = _data[id];
            if(!canFind((*node.children)[], children))
            {
                node.children.insertBack(children);
            }
        } else
        {
            id = GssId(cast(ushort) _data.length);
            GssNode node = GssNode(GssNodeData(slot, pos));
            node.children.insertBack(children);
            _data.insertBack(node);
            _index[node.data] = id;
        }

        // check if it was previously popped
        return CreateRT(id, _popped.get(id, null));
    }

    /**
     * Pop a node from the Gss and return all it's children
     */
    auto pop(GssId elem, InputPos pos)
        in { assert(elem != 0); } // 0 is GssId of L0
    body
    {
        auto entry = _popped.get(elem, null);
        if(entry is null)
            entry = new Array!(InputPos);
        entry.insertBack(pos);
        _popped[elem] = entry;

        return (*_data[elem].children)[];
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
            foreach(children; (*node.children)[])
                formattedWrite(output, "n%d -> n%d\n", i, children);
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
    private Array!(InputPos)*[GssId] _popped;
}

struct Descriptor
{
    this(CodeLabel _slot, InputPos _pos, GssId stackTop)
    {
        pos = _pos;
        top = stackTop;
        slot = _slot;
    }

    InputPos pos;
    GssId top;
    CodeLabel slot;
}

struct PendingSet
{
private:
    Array!Descriptor[] _R;
    alias Tuple!(CodeLabel, "slot", GssId, "stackTop") UElem;
    CritBitTree!(UElem, byteStringRange!(UElem))[] _U;
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

    void add(CodeLabel slot, InputPos pos, GssId top)
    {
        add(Descriptor(slot, pos, top));
    }

    void add(Descriptor desc)
    {
        immutable idx = desc.pos % ringLength;
        UElem elem = tuple(desc.slot, desc.top);
        if((elem in _U[idx]))
            return;

        _U[idx].insert(elem);
        _R[idx].insertBack(desc);
    }
}

class GllContext
{
    Gss gss;
    PendingSet pending;

    this(Grammar)(Grammar* g)
    {
        gss = Gss();
        pending = PendingSet(g.ringLength);
    }
   
    this(int dummy = 0)()
    {
        gss = Gss();
        pending = PendingSet(25);
    }
    
    GssId create(CodeLabel slot, InputPos pos, GssId children)
    {
        auto result = gss.create(slot, pos, children);
        if(result.poppedAt !is null)
        {
            foreach(_pos; (*result.poppedAt)[])
                add(slot, _pos, children);
        }
        return result.id;
    }

    void add(CodeLabel slot, InputPos pos, GssId top)
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
            add(gss[u].data.slot, pos, id);
    }
}

