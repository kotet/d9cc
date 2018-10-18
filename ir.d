/// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
module ir;

import std.algorithm : among;
import std.stdio : stderr;
import std.format : format;

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
    LABEL,
    UNLESS,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
}

enum IRInfo
{
    NOARG,
    REG,
    LABEL,
    REG_REG,
    REG_IMM,
    REG_LABEL,
}

struct IR
{
    IRType op;
    long lhs;
    long rhs;

    IRInfo getInfo()
    {
        switch (this.op)
        {
        case IRType.MOV:
        case IRType.ADD:
        case IRType.SUB:
        case IRType.MUL:
        case IRType.DIV:
        case IRType.LOAD:
        case IRType.STORE:
            return IRInfo.REG_REG;
        case IRType.IMM:
        case IRType.ALLOCA:
        case IRType.ADD_IMM:
            return IRInfo.REG_IMM;
        case IRType.RETURN:
        case IRType.KILL:
            return IRInfo.REG;
        case IRType.LABEL:
            return IRInfo.LABEL;
        case IRType.UNLESS:
            return IRInfo.REG_LABEL;
        case IRType.NOP:
            return IRInfo.NOARG;
        default:
            assert(0);
        }
    }

    // -dump-irオプション用
    string toString()
    {
        switch (this.getInfo())
        {
        case IRInfo.REG_REG:
            return format("%s\tr%d\tr%d", this.op, this.lhs, this.rhs);
        case IRInfo.REG_IMM:
            return format("%s\tr%d\t%d", this.op, this.lhs, this.rhs);
        case IRInfo.REG:
            return format("%s\tr%d", this.op, this.lhs);
        case IRInfo.LABEL:
            return format(".L%s:", this.lhs);
        case IRInfo.REG_LABEL:
            return format("%s\tr%d\t.L%s", this.op, this.lhs, this.rhs);
        case IRInfo.NOARG:
            return format("%s", this.op);
        default:
            assert(0);
        }
    }
}

IR[] genIR(Node* node)
{
    long regno = 1;
    long basereg;
    long bpoff; // 使うメモリ領域のサイズ
    long label;
    long[string] vars;
    IR[] result;
    result ~= IR(IRType.ALLOCA, basereg, 0);
    result ~= genStatement(regno, bpoff, basereg, label, vars, node);
    result[0].rhs = bpoff;
    result ~= IR(IRType.KILL, basereg, -1);
    return result;
}

private:

IR[] genStatement(ref long regno, ref long bpoff, ref long basereg, ref long label,
        ref long[string] vars, Node* node)
{
    IR[] result;
    if (node.type == NodeType.IF)
    {
        long r = genExpression(result, regno, bpoff, basereg, label, vars, node.cond);
        long l = label;
        label++;
        result ~= IR(IRType.UNLESS, r, l);
        result ~= IR(IRType.KILL, r, -1);
        result ~= genStatement(regno, bpoff, basereg, label, vars, node.then);
        result ~= IR(IRType.LABEL, l, -1);
        return result;
    }
    if (node.type == NodeType.RETURN)
    {
        long r = genExpression(result, regno, bpoff, basereg, label, vars, node.expr);
        result ~= IR(IRType.RETURN, r, -1);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.type == NodeType.EXPRESSION_STATEMENT)
    {
        long r = genExpression(result, regno, bpoff, basereg, label, vars, node.expr);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.type == NodeType.COMPOUND_STATEMENT)
    {
        foreach (n; node.statements)
        {
            result ~= genStatement(regno, bpoff, basereg, label, vars, &n);
        }
        return result;
    }
    error("Unknown node: %s", node.type);
    assert(0);
}

long genExpression(ref IR[] ins, ref long regno, ref long bpoff, ref long basereg,
        ref long label, ref long[string] vars, Node* node)
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
        long r = genLval(ins, regno, bpoff, basereg, label, vars, node);
        ins ~= IR(IRType.LOAD, r, r);
        return r;
    }

    if (node.type == NodeType.ASSIGN)
    {
        long rhs = genExpression(ins, regno, bpoff, basereg, label, vars, node.rhs);
        long lhs = genLval(ins, regno, bpoff, basereg, label, vars, node.lhs);
        ins ~= IR(IRType.STORE, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs, -1);
        return lhs;
    }

    assert(node.type.among!(NodeType.ADD, NodeType.SUB, NodeType.MUL, NodeType.DIV));

    long lhs = genExpression(ins, regno, bpoff, basereg, label, vars, node.lhs);
    long rhs = genExpression(ins, regno, bpoff, basereg, label, vars, node.rhs);

    ins ~= IR(cast(IRType) node.type, lhs, rhs);
    ins ~= IR(IRType.KILL, rhs, -1);
    return lhs;
}

long genLval(ref IR[] ins, ref long regno, ref long bpoff, ref long basereg,
        ref long label, ref long[string] vars, Node* node)
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
