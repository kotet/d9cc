/// 再帰下降構文解析器
module parser;

import std.stdio : stderr;

import token;
import util;

// BNFじみた表記になっているが特にBNFとしては意味のないメモ書き
// <func>           ::= <compound_stmt>
// <compound_stmt>  ::= {<stmt>}
// <stmt>           ::= <if> | <assign>
// <if>             ::= if (<assign>) <stmt> [else <stmt>]
// <assign>         ::= <logicalOr> | <logicalOr> = <logicalOr>
// <logicalOr>      ::= <logicalAnd> | <logicalAnd> || <logicalAnd>
// <logicalAnd>     ::= <rel> | <rel> && <rel>
// <rel>            ::= <add> | <add> < <add>
// <add>            ::= <mul> | <mul> + <mul>
// <mul>            ::= <term> | <term> * <term>
// <term>           ::= <assign> | <NUM> | <IDENTIFIER>

public:

enum NodeType
{
    NUM,
    IDENTIFIER,
    VARIABLE_DEFINITION,
    VARIABLE_REFERENCE,
    RETURN,
    IF,
    FOR,
    COMPOUND_STATEMENT,
    EXPRESSION_STATEMENT,
    CALL,
    FUNCTION,
    LOGICAL_AND,
    LOGICAL_OR,
    LESS_THAN = '<',
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    ASSIGN = '=',
}

struct Node
{
    NodeType type;

    // (type == LOGICAL_AND, LOGICAL_OR, LESS_THAN, ADD, SUB, MUL, DIV, ASSIGN)
    Node* lhs = null;
    Node* rhs = null;

    int val; // 値リテラル (type == NUM)
    string name; // 変数名または関数名 (type == IDENTIFIER, FUNCTION)
    Node* expr; // 式 (type == EXPRESSION_STATEMENT, RETURN)
    Node[] statements; // 文 (type == COMPOUND_STATEMENT)

    // typeの値によって役割が変わる
    // function (<args>){<body>} (type == FUNCTION)
    // if (<cond>) <then> else <els> (type == IF)
    // for (<init>;<cond>;<inc>) <body> (type == FOR)
    // function(<args>) (type == CALL)
    Node* initalize;
    Node* cond;
    Node* inc;
    Node* then;
    Node* els;
    Node* bdy;
    Node[] args;

    // FUNCTIONノード用
    size_t stacksize;
    // 変数関連ノード用
    size_t offset;
}

Node[] parse(Token[] tokens)
{
    size_t i;
    Node[] functions;
    while (tokens[i].type != TokenType.EOF)
    {
        functions ~= *func(tokens, i);
    }
    return functions;
}

private:

void expect(char c, Token[] tokens, ref size_t i)
{
    if (tokens[i].type != (cast(TokenType) c))
    {
        error("%s (%s) expected, but got %s (%s)", c, cast(TokenType) c,
                tokens[i].input, tokens[i].type);
    }
    i++;
}

bool consume(TokenType type, Token[] tokens, ref size_t i)
{
    if (tokens[i].type == type)
    {
        i++;
        return true;
    }
    return false;
}

bool isTypeName(Token t)
{
    return t.type == TokenType.INT;
}

// 関数
Node* func(Token[] tokens, ref size_t i)
{
    Node* n = new Node();
    n.type = NodeType.FUNCTION;

    // 関数の型。intしかない上に今のところは特に何もしない
    if (tokens[i].type != TokenType.INT)
    {
        error("Function return type expected, but got %s", tokens[i].input);
    }
    i++;
    if (tokens[i].type != TokenType.IDENTIFIER)
    {
        error("Function name expected, but got %s", tokens[i].input);
    }

    auto t = tokens[i];
    n.name = t.name;
    i++;
    expect('(', tokens, i);
    if (!consume(TokenType.RIGHT_PARENTHESE, tokens, i))
    {
        n.args ~= *param(tokens, i);
        while (consume(TokenType.COMMA, tokens, i))
        {
            n.args ~= *param(tokens, i);
        }
        expect(')', tokens, i);
    }
    expect('{', tokens, i);
    n.bdy = compound_stmt(tokens, i);
    return n;
}

// 複数の文
Node* compound_stmt(Token[] tokens, ref size_t i)
{
    Node* n = new Node();
    n.type = NodeType.COMPOUND_STATEMENT;
    while (!consume(TokenType.RIGHT_BRACE, tokens, i))
    {
        n.statements ~= *stmt(tokens, i);
    }
    return n;
}

// 制御構造でない文
Node* expressionStatement(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    node.type = NodeType.EXPRESSION_STATEMENT;
    node.expr = assign(tokens, i);
    expect(';', tokens, i);
    return node;
}

Node* param(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    node.type = NodeType.VARIABLE_DEFINITION;
    i++;
    if (tokens[i].type != TokenType.IDENTIFIER)
    {
        error("Parameter name expected, but got %s", tokens[i].input);
    }
    node.name = tokens[i].name;
    i++;
    return node;
}

// 変数宣言
Node* declaration(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    i++;
    node.type = NodeType.VARIABLE_DEFINITION;
    if (tokens[i].type != TokenType.IDENTIFIER)
    {
        error("Variable name expected, but got %s", tokens[i].input);
    }
    node.name = tokens[i].name;
    i++;
    if (consume(TokenType.ASSIGN, tokens, i))
    {
        node.initalize = assign(tokens, i);
    }
    expect(';', tokens, i);
    return node;
}

// 文
Node* stmt(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    switch (tokens[i].type)
    {
    case TokenType.IF:
        i++;
        node.type = NodeType.IF;
        expect('(', tokens, i);
        node.cond = assign(tokens, i);
        expect(')', tokens, i);
        node.then = stmt(tokens, i);
        if (consume(TokenType.ELSE, tokens, i))
        {
            node.els = stmt(tokens, i);
        }
        return node;
    case TokenType.FOR:
        i++;
        node.type = NodeType.FOR;
        expect('(', tokens, i);
        if (isTypeName(tokens[i]))
        {
            node.initalize = declaration(tokens, i);
        }
        else
        {
            node.initalize = expressionStatement(tokens, i);
        }
        node.cond = assign(tokens, i);
        expect(';', tokens, i);
        node.inc = assign(tokens, i);
        expect(')', tokens, i);
        node.bdy = stmt(tokens, i);
        return node;
    case TokenType.RETURN:
        i++;
        node.type = NodeType.RETURN;
        node.expr = assign(tokens, i);
        expect(';', tokens, i);
        return node;
    case TokenType.LEFT_BRACE:
        i++;
        node.type = NodeType.COMPOUND_STATEMENT;
        while (!consume(TokenType.RIGHT_BRACE, tokens, i))
        {
            node.statements ~= *stmt(tokens, i);
        }
        return node;
    case TokenType.INT:
        return declaration(tokens, i);
    default:
        return expressionStatement(tokens, i);
    }

}

// 変数への代入と式
Node* assign(Token[] tokens, ref size_t i)
{
    Node* lhs = logicalOr(tokens, i);

    if (consume(TokenType.ASSIGN, tokens, i))
    {
        return () {
            Node* n = new Node();
            n.type = NodeType.ASSIGN;
            n.lhs = lhs;
            n.rhs = logicalOr(tokens, i);
            return n;
        }();
    }
    return lhs;
}

// Cでは論理演算子の間に優先順位がある
// or式
Node* logicalOr(Token[] tokens, ref size_t i)
{
    Node* lhs = logicalAnd(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.LOGICAL_OR)
        {
            return lhs;
        }
        i++;
        lhs = () {
            Node* n = new Node();
            n.type = NodeType.LOGICAL_OR;
            n.lhs = lhs;
            n.rhs = logicalAnd(tokens, i);
            return n;
        }();
    }
}
// and式
Node* logicalAnd(Token[] tokens, ref size_t i)
{
    Node* lhs = rel(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.LOGICAL_AND)
        {
            return lhs;
        }
        i++;
        lhs = () {
            Node* n = new Node();
            n.type = NodeType.LOGICAL_AND;
            n.lhs = lhs;
            n.rhs = rel(tokens, i);
            return n;
        }();
    }
}
// 大小比較
Node* rel(Token[] tokens, ref size_t i)
{
    // 向きを < (less than)に統一する
    Node* lhs = add(tokens, i);
    while (true)
    {
        TokenType op = tokens[i].type;
        if (op == TokenType.LESS_THAN)
        {
            i++;
            lhs = () {
                Node* n = new Node();
                n.type = NodeType.LESS_THAN;
                n.lhs = lhs;
                n.rhs = add(tokens, i);
                return n;
            }();
            continue;
        }
        if (op == TokenType.GREATER_THAN)
        {
            i++;
            lhs = () {
                Node* n = new Node();
                n.type = NodeType.LESS_THAN;
                n.lhs = add(tokens, i);
                n.rhs = lhs;
                return n;
            }();
            continue;
        }
        return lhs;
    }
}
// 加算式
Node* add(Token[] tokens, ref size_t i)
{
    Node* lhs = mul(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.ADD && op != TokenType.SUB)
        {
            return lhs;
        }
        i++;
        lhs = () {
            Node* n = new Node();
            n.type = cast(NodeType) op;
            n.lhs = lhs;
            n.rhs = mul(tokens, i);
            return n;
        }();
    }
}
// 乗算式
Node* mul(Token[] tokens, ref size_t i)
{
    Node* lhs = term(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.MUL && op != TokenType.DIV)
        {
            return lhs;
        }
        i++;
        lhs = () {
            Node* n = new Node();
            n.type = cast(NodeType) op;
            n.lhs = lhs;
            n.rhs = term(tokens, i);
            return n;
        }();
    }
}
// 項
Node* term(Token[] tokens, ref size_t i)
{

    if (tokens[i].type == TokenType.LEFT_PARENTHESE)
    {
        i++;
        Node* n = assign(tokens, i);
        expect(')', tokens, i);
        return n;
    }

    if (tokens[i].type == TokenType.NUM)
    {
        Node* n = new Node();
        n.type = NodeType.NUM;
        n.val = tokens[i].val;
        i++;
        return n;
    }

    if (tokens[i].type == TokenType.IDENTIFIER)
    {
        Node* n = new Node();
        n.name = tokens[i].name;
        i++;
        if (!consume(TokenType.LEFT_PARENTHESE, tokens, i))
        {
            n.type = NodeType.IDENTIFIER;
            return n;
        }
        n.type = NodeType.CALL;
        if (consume(TokenType.RIGHT_PARENTHESE, tokens, i))
        {
            return n;
        }
        n.args ~= *assign(tokens, i);
        while (consume(TokenType.COMMA, tokens, i))
        {
            n.args ~= *assign(tokens, i);
        }
        expect(')', tokens, i);
        return n;
    }

    error("Number expected, but got %s", tokens[i].input);
    assert(0);
}
