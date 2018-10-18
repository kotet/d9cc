/// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
module ir;

import std.algorithm : among;
import std.stdio : stderr;

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
    ALLOCA,
    LOAD,
    STORE,
    ADD_IMM, // 即値add
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
}

struct IR
{
    IRType op;
    long lhs;
    long rhs;
}

IR[] genIR(Node* node)
{
    long regno = 1;
    long basereg;
    long bpoff; // 使うメモリ領域のサイズ
    long[string] vars;
    IR[] result;
    result ~= IR(IRType.ALLOCA, basereg, 0);
    result ~= genStatement(regno, bpoff, basereg, vars, node);
    result[0].rhs = bpoff;
    return result;
}

private:

IR[] genStatement(ref long regno, ref long bpoff, ref long basereg, ref long[string] vars,
        Node* node)
{
    IR[] result;
    if (node.type == NodeType.RETURN)
    {
        long r = genExpression(result, regno, bpoff, basereg, vars, node.expr);
        result ~= IR(IRType.RETURN, r, -1);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.type == NodeType.EXPRESSION_STATEMENT)
    {
        long r = genExpression(result, regno, bpoff, basereg, vars, node.expr);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.type == NodeType.COMPOUND_STATEMENT)
    {
        foreach (n; node.statements)
        {
            result ~= genStatement(regno, bpoff, basereg, vars, &n);
        }
        return result;
    }
    error("Unknown node: %s", node.type);
    assert(0);
}

long genExpression(ref IR[] ins, ref long regno, ref long bpoff, ref long basereg,
        ref long[string] vars, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        long r = regno;
        regno++;
        ins ~= IR(IRType.IMM, r, node.val);
        return r;
    }

    if (node.type == NodeType.IDENTIFIER)
    {
        long r = genLval(ins, regno, bpoff, basereg, vars, node);
        ins ~= IR(IRType.LOAD, r, r);
        return r;
    }

    if (node.type == NodeType.ASSIGN)
    {
        long rhs = genExpression(ins, regno, bpoff, basereg, vars, node.rhs);
        long lhs = genLval(ins, regno, bpoff, basereg, vars, node.lhs);
        ins ~= IR(IRType.STORE, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs, -1);
        return lhs;
    }

    assert(node.type.among!(NodeType.ADD, NodeType.SUB, NodeType.MUL, NodeType.DIV));

    long lhs = genExpression(ins, regno, bpoff, basereg, vars, node.lhs);
    long rhs = genExpression(ins, regno, bpoff, basereg, vars, node.rhs);

    ins ~= IR(cast(IRType) node.type, lhs, rhs);
    ins ~= IR(IRType.KILL, rhs, -1);
    return lhs;
}

long genLval(ref IR[] ins, ref long regno, ref long bpoff, ref long basereg,
        ref long[string] vars, Node* node)
{
    if (node.type != NodeType.IDENTIFIER)
    {
        error("Not an lvalue: ", node);
    }
    if (!(node.name in vars))
    {
        vars[node.name] = bpoff;
        bpoff += 8;
    }

    long r = regno;
    regno++;
    long off = vars[node.name];
    ins ~= IR(IRType.MOV, r, basereg);
    ins ~= IR(IRType.ADD_IMM, r, off);
    return r;
}
