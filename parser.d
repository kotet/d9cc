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

enum NodeType : int
{
    LESS_THAN = '<',
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    ASSIGN = '=',
    NUM = 256,
    IDENTIFIER,
    STRING,
    VARIABLE_DEFINITION,
    LOCAL_VARIABLE,
    GLOBAL_VARIABLE,
    DEREFERENCE,
    RETURN,
    IF,
    FOR,
    COMPOUND_STATEMENT,
    EXPRESSION_STATEMENT,
    CALL,
    FUNCTION,
    LOGICAL_AND,
    LOGICAL_OR,
    ADDRESS,
    SIZEOF,
}

enum TypeName
{
    INT,
    POINTER,
    ARRAY,
    CHAR,
}

struct Type
{
    TypeName type;
    Type* pointer_of;

    // 配列
    Type* array_of;
    size_t array_length;
}

struct Node
{
    NodeType op;

    // (op == LOGICAL_AND, LOGICAL_OR, LESS_THAN, ADD, SUB, MUL, DIV, ASSIGN)
    Node* lhs = null;
    Node* rhs = null;

    int val; // 値リテラル (op == NUM)
    string str; // 文字列リテラル (op == STRING)
    string name; // 変数名または関数名 (op == IDENTIFIER, FUNCTION)
    Node* expr; // 式 (op == EXPRESSION_STATEMENT, RETURN)
    Node[] statements; // 文 (op == COMPOUND_STATEMENT)

    // typeの値によって役割が変わる
    // function (<args>){<body>} (op == FUNCTION)
    // if (<cond>) <then> else <els> (op == IF)
    // for (<init>;<cond>;<inc>) <body> (op == FOR)
    // function(<args>) (op == CALL)
    Node* initalize;
    Node* cond;
    Node* inc;
    Node* then;
    Node* els;
    Node* bdy;
    Node[] args;

    // FUNCTIONノード用
    size_t stacksize;
    Node[] strings;

    // 変数関連ノード用
    size_t offset;

    Type* type;
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

Type* getType(Token t)
{
    switch (t.type)
    {
    case TokenType.INT:
        return new Type(TypeName.INT);
    case TokenType.CHAR:
        return new Type(TypeName.CHAR);
    default:
        return null;
    }
}

Node* newBinOp(NodeType op, Node* lhs, Node* rhs)
{
    Node* node = new Node();
    node.op = op;
    node.lhs = lhs;
    node.rhs = rhs;
    return node;
}

Node* newExpr(NodeType op, Node* expr)
{
    Node* node = new Node();
    node.op = op;
    node.expr = expr;
    return node;
}

// 関数
Node* func(Token[] tokens, ref size_t i)
{
    Node* n = new Node();
    n.op = NodeType.FUNCTION;
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
    n.op = NodeType.COMPOUND_STATEMENT;
    while (!consume(TokenType.RIGHT_BRACE, tokens, i))
    {
        n.statements ~= *stmt(tokens, i);
    }
    return n;
}

// 制御構造でない文
Node* expressionStatement(Token[] tokens, ref size_t i)
{
    Node* node = newExpr(NodeType.EXPRESSION_STATEMENT, assign(tokens, i));
    expect(';', tokens, i);
    return node;
}

Node* param(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    node.op = NodeType.VARIABLE_DEFINITION;
    node.type = type(tokens, i);
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
    node.op = NodeType.VARIABLE_DEFINITION;
    // 型名
    node.type = type(tokens, i);

    // 変数名
    if (tokens[i].type != TokenType.IDENTIFIER)
    {
        error("Variable name expected, but got %s", tokens[i].input);
    }
    node.name = tokens[i].name;
    i++;

    // 配列

    node.type = readArray(node.type, tokens, i);

    // 初期化
    if (consume(TokenType.ASSIGN, tokens, i))
    {
        node.initalize = assign(tokens, i);
    }
    expect(';', tokens, i);
    return node;
}

Type* type(Token[] tokens, ref size_t i)
{
    Type* ty = getType(tokens[i]);
    if (!ty)
    {
        error("Type name expected, but got %s", tokens[i].input);
    }
    i++;
    while (consume(TokenType.ASTERISK, tokens, i))
    {
        ty = () {
            Type* t = new Type();
            t.type = TypeName.POINTER;
            t.pointer_of = ty;
            return t;
        }();
    }
    return ty;
}

Type* readArray(Type* type, Token[] tokens, ref size_t i)
{
    Node[] array_size;
    while (consume(TokenType.LEFT_BRACKET, tokens, i))
    {
        Node* length = primary(tokens, i);
        if (length.op != NodeType.NUM)
        {
            error("Number expected, but got %s", length.type);
        }
        array_size ~= *length;
        expect(']', tokens, i);
    }
    foreach_reverse (length; array_size)
    {
        type = () {
            Type* t = new Type();
            t.type = TypeName.ARRAY;
            t.array_of = type;
            t.array_length = length.val;
            return t;
        }();
    }
    return type;
}

// 文
Node* stmt(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    switch (tokens[i].type)
    {
    case TokenType.IF:
        i++;
        node.op = NodeType.IF;
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
        node.op = NodeType.FOR;
        expect('(', tokens, i);
        if (getType(tokens[i]))
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
        Node* n = newExpr(NodeType.RETURN, assign(tokens, i));
        expect(';', tokens, i);
        return n;
    case TokenType.LEFT_BRACE:
        i++;
        node.op = NodeType.COMPOUND_STATEMENT;
        while (!consume(TokenType.RIGHT_BRACE, tokens, i))
        {
            node.statements ~= *stmt(tokens, i);
        }
        return node;
    case TokenType.INT:
    case TokenType.CHAR:
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
        return newBinOp(NodeType.ASSIGN, lhs, logicalOr(tokens, i));
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
        lhs = newBinOp(NodeType.LOGICAL_OR, lhs, logicalAnd(tokens, i));
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
        lhs = newBinOp(NodeType.LOGICAL_AND, lhs, rel(tokens, i));
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
            lhs = newBinOp(NodeType.LESS_THAN, lhs, add(tokens, i));
            continue;
        }
        if (op == TokenType.GREATER_THAN)
        {
            i++;
            lhs = newBinOp(NodeType.LESS_THAN, add(tokens, i), lhs);
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
        lhs = newBinOp(cast(NodeType) op, lhs, mul(tokens, i));
    }
}
// 乗算式
Node* mul(Token[] tokens, ref size_t i)
{
    Node* lhs = unary(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.ASTERISK && op != TokenType.DIV)
        {
            return lhs;
        }
        i++;
        lhs = newBinOp(cast(NodeType) op, lhs, unary(tokens, i));
    }
}

Node* unary(Token[] tokens, ref size_t i)
{
    if (consume(TokenType.ASTERISK, tokens, i))
    {
        return newExpr(NodeType.DEREFERENCE, mul(tokens, i));
    }

    if (consume(TokenType.AMPERSAND, tokens, i))
    {
        return newExpr(NodeType.ADDRESS, mul(tokens, i));
    }
    if (consume(TokenType.SIZEOF, tokens, i))
    {
        return newExpr(NodeType.SIZEOF, mul(tokens, i));
    }

    return postfix(tokens, i);

}

// ary[x][y] -> *(ary + x)[y] -> *(*(ary + x) + y)
Node* postfix(Token[] tokens, ref size_t i)
{
    Node* lhs = primary(tokens, i);
    while (consume(TokenType.LEFT_BRACKET, tokens, i))
    {
        lhs = newExpr(NodeType.DEREFERENCE, newBinOp(NodeType.ADD, lhs, assign(tokens, i)));
        expect(']', tokens, i);
    }
    return lhs;
}

// 項
Node* primary(Token[] tokens, ref size_t i)
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
        n.op = NodeType.NUM;
        n.type = new Type(TypeName.INT);
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
            n.op = NodeType.IDENTIFIER;
            return n;
        }
        n.op = NodeType.CALL;
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

    if (tokens[i].type == TokenType.STRING)
    {
        Node* n = new Node();
        n.op = NodeType.STRING;
        n.type = () {
            Type* t = new Type();
            t.type = TypeName.ARRAY;
            t.array_of = new Type(TypeName.CHAR);
            t.array_length = tokens[i].str.length;
            return t;
        }();
        n.str = tokens[i].str;
        i++;
        return n;
    }

    error("Number expected, but got %s", tokens[i].input);
    assert(0);
}
