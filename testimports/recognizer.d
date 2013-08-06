
struct Recognizer(Token, TK, alias compare)
{
    
enum Label
{
    Loop,
    _A,
    _B,
    _C,
    A_0a,
    B_0b,
    B_0B_A,
    B_B0A,
    B_B_A0,
    C_0c,
    C_0A_B_C,
    C_A0B_C,
    C_A_B0C,
    C_A_B_C0
};

    Token[] input;
    GllContext context;
this(Token[] _input)
{
    input = _input;
    context = new GllContext();
}


bool parse()
{
    InputPos curIdx;
    GssId curTop;
    Label curLabel = Label._C;
    //add start symbol to pending set
    with(Label) {

    /* setup for data structures .. ? */
    while(true)
    {
        final switch(curLabel)
        {
            case Loop:
            if(context.pending.empty)
                return (curIdx == input.length);
            else
            {
                auto desc = context.pending.pop;
                curIdx = desc.pos;
                curTop = desc.top;
                curLabel = to!Label(desc.slot);
                break;
            }
            case _A:

if(compare(input[curIdx], TK.a))
{
    context.add(A_0a, curIdx, curTop);
}
curLabel = Loop; break;
case A_0a:
curIdx += 1;
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        case _B:

if(compare(input[curIdx], TK.b))
{
    context.add(B_0b, curIdx, curTop);
}

if(compare(input[curIdx], TK.b))
{
    context.add(B_0B_A, curIdx, curTop);
}
curLabel = Loop; break;
case B_0b:
curIdx += 1;
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        case B_0B_A:

curTop = context.create(B_B0A, curIdx, curTop);
curLabel = _B; break;
case B_B0A:
    
if(compare(input[curIdx], TK.a))
{
    curTop = context.create(B_B_A0, curIdx, curTop);
    curLabel = _A; break;
}
else
{
    curLabel = Loop; break;
}
case B_B_A0:

context.pop(curTop, curIdx);
curLabel = Loop; break;
case _C:

if(compare(input[curIdx], TK.c))
{
    context.add(C_0c, curIdx, curTop);
}

if(compare(input[curIdx], TK.a))
{
    context.add(C_0A_B_C, curIdx, curTop);
}
curLabel = Loop; break;
case C_0c:
curIdx += 1;
        context.pop(curTop, curIdx);
        curLabel = Loop; break;
        case C_0A_B_C:

curTop = context.create(C_A0B_C, curIdx, curTop);
curLabel = _A; break;
case C_A0B_C:
    
if(compare(input[curIdx], TK.b))
{
    curTop = context.create(C_A_B0C, curIdx, curTop);
    curLabel = _B; break;
}
else
{
    curLabel = Loop; break;
}
case C_A_B0C:

    
if(compare(input[curIdx], TK.a,TK.c))
{
    curTop = context.create(C_A_B_C0, curIdx, curTop);
    curLabel = _C; break;
}
else
{
    curLabel = Loop; break;
}
case C_A_B_C0:

context.pop(curTop, curIdx);
curLabel = Loop; break;

        }
    }
    }
}

}
