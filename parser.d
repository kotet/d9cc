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
}

Node* parse(Token[] tokens)
{
    size_t i;
    return compound_stmt(tokens, i);
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

Node* compound_stmt(Token[] tokens, ref size_t i)
{
    Node* n = new Node();
    n.type = NodeType.COMPOUND_STATEMENT;
    while (true)
    {
        if (tokens[i].type == TokenType.EOF)
        {
            return n;
        }
        n.statements ~= *stmt(tokens, i);
    }
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
        n.type = NodeType.IDENTIFIER;
        n.name = tokens[i].name;
        i++;
        return n;
    }

    error("Number expected, but got %s", tokens[i].input);
    assert(0);
}
