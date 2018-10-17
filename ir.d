/// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
module ir;

import std.algorithm : among;

import parser;
import util;

// 5+20-4 -> 
// [IR(IMM, 0, 5), a = 5
// IR(IMM, 1, 20), b = 20
// IR(ADD, 0, 1), a += b
// IR(KILL, 1, 0), free(b)
// IR(IMM, 2, 4), c = 4
// IR(SUB, 0, 2), a -= c
// IR(KILL, 2, 0), free(c)
// IR(RETURN, 0, 0)] ret

public:

enum IRType
{
    IMM, // IMmediate Move (即値move) の略? 
    MOV,
    RETURN,
    KILL, // lhsに指定されたレジスタを解放する
    NOP,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
}

struct IR
{
    IRType op;
    size_t lhs;
    size_t rhs;
}

IR[] genIR(Node* node)
{
    size_t regno;
    IR[] result = genStatement(regno, node);
    return result;
}

private:

IR[] genStatement(ref size_t regno, Node* node)
{
    IR[] result;
    if (node.type == NodeType.RETURN)
    {
        size_t r = genExpression(result, regno, node.expr);
        result ~= IR(IRType.RETURN, r, 0);
        result ~= IR(IRType.KILL, r, 0);
        return result;
    }
    if (node.type == NodeType.EXPRESSION_STATEMENT)
    {
        size_t r = genExpression(result, regno, node.expr);
        result ~= IR(IRType.KILL, r, 0);
        return result;
    }
    if (node.type == NodeType.COMPOUND_STATEMENT)
    {
        foreach (n; node.statements)
        {
            result ~= genStatement(regno, &n);
        }
        return result;
    }
    error("Unknown node: %s", node.type);
    assert(0);
}

size_t genExpression(ref IR[] ins, ref size_t regno, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        size_t r = regno;
        regno++;
        ins ~= IR(IRType.IMM, r, node.val);
        return r;
    }

    assert(node.type.among!(NodeType.ADD, NodeType.SUB, NodeType.MUL, NodeType.DIV));

    size_t lhs = genExpression(ins, regno, node.lhs);
    size_t rhs = genExpression(ins, regno, node.rhs);

    ins ~= IR(cast(IRType) node.type, lhs, rhs);
    ins ~= IR(IRType.KILL, rhs, 0);
    return lhs;
}
