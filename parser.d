/// 再帰下降構文解析器
module parser;

import std.stdio : stderr;

import token;
import util;

// 1+2+3+4 -> ((((1 + 2) + 3) + 4) + 5)

public:

enum NodeType
{
    NUM,
    IDENTIFIER,
    RETURN,
    IF,
    COMPOUND_STATEMENT,
    EXPRESSION_STATEMENT,
    CALL,
    FUNCTION,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    ASSIGN = '=',
}

struct Node
{
    NodeType type;
    Node* lhs = null;
    Node* rhs = null;
    int val; // 値リテラル
    string name; // 変数名
    Node* expr; // 式
    Node[] statements; // 文

    // if用
    Node* cond;
    Node* then;
    Node* els;

    // 関数呼び出し用
    Node[] args;

    // 関数定義用
    Node* function_body;
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

Node* func(Token[] tokens, ref size_t i)
{
    Node* n = new Node();
    n.type = NodeType.FUNCTION;
    auto t = tokens[i];
    if (t.type != TokenType.IDENTIFIER)
    {
        error("Function name expected, but got %s", t.input);
    }
    n.name = t.name;
    i++;
    expect('(', tokens, i);
    // term()は関数定義の時(func(a,b,c))の時はIDENTIFIERノードを返す
    if (!consume(TokenType.RIGHT_PARENTHESES, tokens, i))
    {
        n.args ~= *term(tokens, i);
        while (consume(TokenType.COMMA, tokens, i))
        {
            n.args ~= *term(tokens, i);
        }
        expect(')', tokens, i);
    }
    expect('{', tokens, i);
    n.function_body = compound_stmt(tokens, i);
    return n;
}

Node* compound_stmt(Token[] tokens, ref size_t i)
{
    Node* n = new Node();
    n.type = NodeType.COMPOUND_STATEMENT;
    while (!consume(TokenType.RIGHT_BRACES, tokens, i))
    {
        n.statements ~= *stmt(tokens, i);
    }
    return n;
}

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
    case TokenType.RETURN:
        i++;
        node.type = NodeType.RETURN;
        node.expr = assign(tokens, i);
        expect(';', tokens, i);
        return node;
    default:
        node.type = NodeType.EXPRESSION_STATEMENT;
        node.expr = assign(tokens, i);
        expect(';', tokens, i);
        return node;
    }

}

Node* assign(Token[] tokens, ref size_t i)
{
    Node* lhs = expr(tokens, i);

    if (consume(TokenType.ASSIGN, tokens, i))
    {
        return () {
            Node* n = new Node();
            n.type = NodeType.ASSIGN;
            n.lhs = lhs;
            n.rhs = expr(tokens, i);
            return n;
        }();
    }
    return lhs;
}

Node* expr(Token[] tokens, ref size_t i)
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

Node* term(Token[] tokens, ref size_t i)
{

    if (tokens[i].type == TokenType.LEFT_PARENTHESES)
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
        if (!consume(TokenType.LEFT_PARENTHESES, tokens, i))
        {
            n.type = NodeType.IDENTIFIER;
            return n;
        }
        n.type = NodeType.CALL;
        if (consume(TokenType.RIGHT_PARENTHESES, tokens, i))
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
