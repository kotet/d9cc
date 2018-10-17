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
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    RETURN,
    COMPOUND_STATEMENT,
    EXPRESSION_STATEMENT
}

struct Node
{
    NodeType type;
    Node* lhs = null;
    Node* rhs = null;
    int val; // 値リテラル
    Node* expr; // 式
    Node[] statements; // 文
}

Node* parse(Token[] tokens)
{
    size_t i;
    return stmt(tokens, i);
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

Node* stmt(Token[] tokens, ref size_t i)
{
    Node* node = new Node();
    node.type = NodeType.COMPOUND_STATEMENT;
    while (true)
    {
        Token t = tokens[i];
        if (t.type == TokenType.EOF)
        {
            return node;
        }
        Node e;

        if (t.type == TokenType.RETURN) // return ... ;
        {
            i++;
            e.type = NodeType.RETURN;
            e.expr = expr(tokens, i);
        }
        else
        {
            e.type = NodeType.EXPRESSION_STATEMENT;
            e.expr = expr(tokens, i);
        }
        node.statements ~= e;
        expect(';', tokens, i);
    }
    return node;
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
    Node* lhs = number(tokens, i);

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
            n.rhs = number(tokens, i);
            return n;
        }();
    }
}

Node* number(Token[] tokens, ref size_t i)
{
    if (tokens[i].type == TokenType.NUM)
    {
        Node* n = new Node();
        n.type = NodeType.NUM;
        n.val = tokens[i].val;
        i++;
        return n;
    }
    error("Number expected, but got %s", tokens[i].input);
    assert(0);
}
