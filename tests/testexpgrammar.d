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


    struct Parser(Token)
    {
        Token[] input;
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
++/
