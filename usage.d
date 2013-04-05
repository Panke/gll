/**
 * This file shows example usage of future parser and generator API.
 */

/*
 * The following items are not part of the API, but expected to exist
 * somewhere in some form in user code 
 */

// TokenKind enumerates every kind of possible token. Must include
// an special Eof-Token generated at end of input.
enum TokenKind {...}
// The GLL parser operates on a random access range of `Token`. 
// Token are the terminals in the parsed language.
struct Token {}
// returns whether a value of type token is of a specific kind
bool compare(Token tok, TokenKind kind)


/*
 * The basis for generating a recognizer is a grammar. 
 * The type of the grammar depends on the TokenType. These 
 * two could theoretically be decoupled via implicit contracts
 * but this seems not worth the effort.
 */
struct Grammar(TK) {
    struct Symbol {...}
    struct Production {...}
}

// Building a grammar could look like this
alias Grammar!TokenKind.Symbol Symbol;
auto A = Symbol( "A" );
auto B = Symbol( "B" );
auto C = Symbol( "C" );
auto a = Symbol(TokenKind.a);

auto b = Symbol(TokenKind.b);
auto c = Symbol(TokenKind.c);

alias Grammar!TokenKind.Production Production;
Production prd5 = Production( C, [A, B, C] );
Production prd3 = Production( B, [b] );
Production prd1 = Production( A, [ a ] );
Production prd2 = Production( B, [B, A ]);
Production prd4 = Production( B, [Epsilon] );
Production prd6 = Production( A, [Epsilon] );
Production prd7 = Production( C, [ c ] );

auto g = Grammar!TokenType(C, []);
g.addProductions([prd1, prd2, prd3, prd4, prd5, prd6, prd7]);


/* 
 * Given a grammar, a generator will generate the code needed to
 * parse a token range. This recognizer is actually dependend
 * on the types Token and TokenKind and the compare function. 
 * This decouples the Grammar from the lexer (user code) and 
 * recognizer (generated code).
 * 
 */

// all the generation magic happens inside the "Template!()" template.
alias Generator!(Token, TokenKind, compare) Gen;

bool valid = recog(someKindOfTokenRange);

/*
 * To make this possible, there still will be the need 
 * for some interface between Recognizer/Grammar/TokenKind
 * that makes it possible to 
