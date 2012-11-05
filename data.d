
import std.container, std.range, std.algorithm, std.array, std.stdio, std.typecons,
       std.format;

/*
 * This module implements the GSS and SPPF needed in every gll parser,
 * as well as the sets U_i
 */

struct InputPos
{
    ushort _pos;
    alias _pos this;
}

struct GrammarSlot
{
    ushort _pos;
    alias _pos this;
}

struct GssLabel
{
    GrammarSlot slot;
    InputPos inputPos;
}

struct GssNode
{
    this(GrammarSlot slot, InputPos pos)
    {
        label.slot = slot;
        label.inputPos = pos;
    }

    GssLabel label;
    Array!GssLabel parents;
}

alias GssNode*[const(GssLabel)] GssIndex;
enum L0 = GssLabel(GrammarSlot(0), 0);

struct Descriptor
{
    GrammarSlot slot;
    InputPos pos;
    GssId top;
}

bool desCmp(Descriptor lhs, Descriptor rhs) { return lhs.pos > rhs.pos; }

struct GllContext
{
    GssIndex gssIndex;
    Array!GssNode gss;
    bool[GssLabel] popped;
    Array!(bool[GssLabel]) U_i;
    BinaryHeap!(Array!Descriptor, desCmp) pending;

    GssId create(GrammarSlot slot, InputPos i, GssId top)
    {
        // check if there already exists a GssNode (slot, i)
        GssLabel label = GssLabel(slot, i);
        if( auto node = label in gssIndex)
        {
            // node exists, does edge to top exist?
            if(!canFind(gss[*node].parents[], top))
                gss[*node].parents.insertBack(top);
            return *node;
        } else
        {
            GssId new_id = cast(GssId) gss.length;
            gss.insertBack(GssNode(label.tupleof));
            return new_id;
        }
    }

    void pop(GssId id, InputPos pos)
    {
        GssLabel label = gss[id].label;
        if(label == L0)
            return;

        popped[label] = true;

        foreach(GssId parent; gss[id].parents[])
        {
            create(gss[parent].label.slot, pos, parent);
        }
    }

    void add(GrammarSlot slot, InputPos pos, GssId top)
    {
        if(pos > U_i.length)
            U_i.length(cast(size_t)(U_i.length * 1.5));
        if(GssLabel(slot, pos) in U_i[pos])
            return;
        else
            pending.insert(Descriptor(slot, pos, top));
    }

    void gssToDot(Out)(Out output)
    {
        output.put("strict digraph Gss {\n");
        string[string] nodeAttrs = ["shape":"box", "style":"solid", "regular":"1"];
        foreach(key; nodeAttrs.byKeys)
            formattedWrite(output, "node %s=%s\n", key, nodeAttrs[key]);

        output.put("\n");

        foreach(i, node; gss)
            formattedWrite(output, "n%d label=\"L:%d, P:%d\"\n", node.label.slot, node.label.pos);

        foreach(i, node; gss)
            foreach(parent; node.parents)
                formattedWrite(output, "n%d -> n%d\n", i, parent);

        output.put("\n}\n");
    }
}
