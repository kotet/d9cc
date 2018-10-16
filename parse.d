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
    SUB = '-'
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
    Node* lhs = number(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.ADD && op != TokenType.SUB)
        {
            break;
        }
        i++;
        Node* new_lhs = new Node();
        new_lhs.type = cast(NodeType) op;
        new_lhs.lhs = lhs;
        new_lhs.rhs = number(tokens, i);
        lhs = new_lhs;
    }
    if (tokens[i].type != TokenType.EOF)
    {
        stderr.writefln("Stray token: %s", tokens[i].input);
    }
    return lhs;
}

private:

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
