/// 再帰下降構文解析器
module parse;

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
    DIV = '/'
}

struct Node
{
    NodeType type;
    Node* lhs = null;
    Node* rhs = null;
    int val;
}

Node* expr(Token[] tokens)
{
    size_t i;
    Node* lhs = mul(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.ADD && op != TokenType.SUB)
        {
            break;
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
    if (tokens[i].type != TokenType.EOF)
    {
        stderr.writefln("Stray token: %s", tokens[i].input);
    }
    return lhs;
}

private:

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
    stderr.writefln("Number expected, but got %s", tokens[i].input);
    throw new ExitException(-1);
}
