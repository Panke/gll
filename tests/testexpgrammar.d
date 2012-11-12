module tests.testgrammar;
import gll.grammar, gll.data, gll.gll;
/++
/**
 * A Gll example parser.
 *
 * Used as a template for generation and as a test case for the
 * data structures.
 *
 * Shall recognize strings according to the following grammar.
 *
 * S ::= E
 * S ::= E;S
 * S ::= ε
 * E ::= N
 * E ::= E + E
 * E ::= E - E
 * E ::= E!
 * N ::=
 */


struct Parser
{
    dstring input;
    GllContext context;
    this(dstring _input)
    {
        input = _input;
        context = new GllContext();
    }

    enum Tags
    {
        Loop,
        S_0E,
        S_E0,
        S_0E_Semi_S,
        S_E0_Semi_S,
        S_E_Semi_0S,
        S_E_Semi_S0,
        E_0N,
        E_N0,
        E_0E_PL_E,
        E_E0_PL_E,
        E_E_PL_0E,
        E_E_PL_E0,
        E_0E_MIN_E,
        E_E0_MIN_E,
        E_E_MIN_0E,
        E_E_MIN_E0,
        E_0E_B,
        E_E_0B,
        N_0n,
        // labels for Nonterminals
        _S,
        _E,
        _N,
    }


    bool parse()
    {
        InputPos curIdx;
        GssId curTop;
        Tags curLabel = Loop;
        with(Tags) {
        if(input[0] == "n" || input.length == 0)
            curLabel = _S;
        else
            throw new Exception("Näääh");

        while(true)
        {
            final switch(curLabel)
            {
                case _S:
                    if(input[0] == "n")
                    {
                        context.add(S_0E);
                        context.add(S_0E_Semi_S);
                    }
                    curLabel = Loop; break;
                case S_0E:
                    curTop = context.create(S_E0, curIdx, curTop);
                    curLabel = _E; break;
                case S_E0:
                    context.pop(curTop, curIdx);
                    curLabel = Loop; break;

                case _E:
                    if(input[curIdx] == "n")
                    {
                        context.add(E_0E_B, curIdx, curTop);
                        context.add(E_0E_MIN_E, curIdx, curTop);
                        context.add(E_0E_PL_E, curIdx, curTop);
                        context.add(E_0N, curIdx, curTop);
                    }
                case E_0E_B:
                    curTop = context.create(E_E_0B, curIdx, curTop);
                    curLabel = _E; break;
                case E_E_0B:
                    if(input[curIdx] == "!")
                    {
                        curIdx++;
                        context.pop(curTop, curIdx);
                    }
                    curLabel = Loop; break;

                case E_0E_MIN_E:
                    curTop = context.create(E_E0_MIN_E, curIdx, curTop);
                    curLabel = _E; break;
                case E_E0_MIN_E:
                    if(input[curIdx] == "-")
                    {
                        curIdx++;
                        curTop = context.create(E_E_MIN_E0, curIdx, curTop);
                        curLabel = _E; break;
                    }
                    curLabel = Loop; break;
                case E_E_MIN_E0:
                    context.pop(curTop, curIdx);

                case E_0N:
                    curTop = context.create(E_N0, curIdx, curTop);
                    curLabel = _N; break;
                case E_N0:
                    context.pop(curTop; curIdx);
                case _N:
                    if(input[curIdx] == "n")
                    {
                        curIdx++;
                        context.pop(curTop, curIdx );
                    }
                    curLabel = Loop; break;
            }
        }
    }
}

enum Label
{
    A_0Epsi,
    A_0a,
    B_0Epsi,
    B_0B_A,
    B_B0A,
    B_B_A0,
    B_0b,
    C_0A_B_C,
    C_A0B_C,
    C_A_B0C,
    C_A_B_C0,
    C_0c,
    _A,
    _B,
    _C,
}
++/

enum Label
{
    Loop,
    A_0Epsi,
    A_0a,
    B_0Epsi,
    B_0B_A,
    B_B0A,
    B_B_A0,
    B_0b,
    C_0A_B_C,
    C_A0B_C,
    C_A_B0C,
    C_A_B_C0,
    C_0c,
    _A,
    _B,
    _C,
}
struct Parser
{
    dstring input;
    GllContext context;
    this(dstring _input)
    {
        input = _input;
        context = new GllContext();
    }

    bool parse()
    {
        InputPos curIdx;
        Gss.GssId curTop;
        with(Label) {
        Label curLabel = Loop;
        if(input[0] == 'n' || input.length == 0)
            curLabel = _A;
        else
            throw new Exception("Näääh");

        while(true)
        {
            final switch(curLabel)
            {
                case _A:
                    if(test!(_A, A_0Epsi)(curIdx))
                        context.add(A_0Epsi, curIdx, curTop);
                    if(test!(_A, A_0a)(curIdx))
                        context.add(A_0a, curIdx, curTop);
                    curLabel = Loop; break;
                case A_0Epsi:
                    context.pop(curTop, curIdx);
                    curLabel = Loop; break;
                case A_0a:
                    curIdx++;
                    context.pop(curTop, curIdx);
                    curLabel = Loop; break;
                case _B:
                    if(test!(_B, B_0Epsi)(curIdx))
                        context.add(B_0Epsi, curIdx, curTop);
                    if(test!(_B, B_0B_A)(curIdx))
                        context.add(B_0B_A, curIdx, curTop);
                    if(test!(_B, B_0b)(curIdx))
                        context.add(B_0b, curIdx, curTop);
                    curLabel = Loop; break;
                case B_0Epsi:
                    context.pop(curTop, curIdx);
                    curLabel = Loop; break;
                case B_0B_A:
                    curTop = context.create(B_B0A, curIdx, curTop);
                    curLabel = B; break;
                case B_B0A:
                    if(test!(_B, B_B0A)(curIdx))
                    {
                        curTop = context.create(B_B_A0, curIdx, curTop);
                        curLabel = _A; break;
                    }
                    else
                    {
                        curLabel = Loop; break;
                    }
                case B_B_A0:
                    pop(curTop, curIdx);
                    curLabel = Loop; break;
                case B_0b:
                    curIdx++;
                    context.pop(curTop, curIdx);
                    curLabel = Loop; break;
                case _C:
                    if(test!(_C, C_0A_B_C)(curIdx))
                        context.add(C_0A_B_C, curIdx, curTop);
                    if(test!(_C, C_0c)(curIdx))
                        context.add(C_0c, curIdx, curTop);
                    curLabel = Loop; break;
                case C_0A_B_C:
                    curTop = context.create(C_A0B_C, curIdx, curTop);
                    curLabel = C; break;
                case C_A0B_C:
                    if(test!(_C, C_A0B_C)(curIdx))
                    {
                        curTop = context.create(C_A_B0C, curIdx, curTop);
                        curLabel = _B; break;
                    }
                    else
                    {
                        curLabel = Loop; break;
                    }
                case C_A_B0C:
                    if(test!(_C, C_A_B0C)(curIdx))
                    {
                        curTop = context.create(C_A_B_C0, curIdx, curTop);
                        curLabel = _C; break;
                    }
                    else
                    {
                        curLabel = Loop; break;
                    }
                case C_A_B_C0:
                    pop(curTop, curIdx);
                    curLabel = Loop; break;
                case C_0c:
                    curIdx++;
                    context.pop(curTop, curIdx);
                    curLabel = Loop; break;
            }
        }
    }
}
}

bool test(A, B, C)(C dummy) { return true; }
