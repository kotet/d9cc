/// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
module gen_ir;

import std.algorithm : among;
import std.stdio : stderr;
import std.format : format;
import std.range : empty;

import parser;
import util;
import sema;

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

enum IRType : int
{
    LESS_THAN = '<',
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    IMM = 256, // IMmediate Move (即値move) の略? 
    MOV,
    RETURN,
    KILL, // lhsに指定されたレジスタを解放する
    NOP,
    LOAD32,
    LOAD64,
    STORE32,
    STORE64,
    STORE32_ARG, // int引数の保持
    STORE64_ARG, // ポインタ引数の保持
    ADD_IMM, // 即値add
    SUB_IMM, // 即値sub
    LABEL,
    UNLESS,
    JMP,
    CALL,
}

enum IRInfo
{
    NOARG,
    REG,
    LABEL,
    REG_REG,
    REG_IMM,
    REG_LABEL,
    CALL,
    IMM,
    IMM_IMM,
    JMP,
}

struct IR
{
    IRType op;
    long lhs;
    long rhs;

    // 関数呼び出し
    string name;
    long[] args;

    IRInfo getInfo()
    {
        switch (this.op)
        {
        case IRType.MOV:
        case IRType.ADD:
        case IRType.SUB:
        case IRType.MUL:
        case IRType.DIV:
        case IRType.LOAD32:
        case IRType.LOAD64:
        case IRType.STORE32:
        case IRType.STORE64:
        case IRType.LESS_THAN:
            return IRInfo.REG_REG;
        case IRType.IMM:
        case IRType.ADD_IMM:
        case IRType.SUB_IMM:
            return IRInfo.REG_IMM;
        case IRType.RETURN:
        case IRType.KILL:
            return IRInfo.REG;
        case IRType.LABEL:
            return IRInfo.LABEL;
        case IRType.JMP:
            return IRInfo.JMP;
        case IRType.UNLESS:
            return IRInfo.REG_LABEL;
        case IRType.CALL:
            return IRInfo.CALL;
        case IRType.NOP:
            return IRInfo.NOARG;
        case IRType.STORE32_ARG:
        case IRType.STORE64_ARG:
            return IRInfo.IMM_IMM;
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
            return format("  %s\tr%d\tr%d", this.op, this.lhs, this.rhs);
        case IRInfo.REG_IMM:
            return format("  %s\tr%d\t%d", this.op, this.lhs, this.rhs);
        case IRInfo.REG:
            return format("  %s\tr%d", this.op, this.lhs);
        case IRInfo.LABEL:
            return format(".L%s:", this.lhs);
        case IRInfo.REG_LABEL:
            return format("  %s\tr%d\t.L%s", this.op, this.lhs, this.rhs);
        case IRInfo.NOARG:
            return format("  %s", this.op);
        case IRInfo.CALL:
            string s = format("  r%d = %s(", this.lhs, this.name);
            foreach (arg; this.args)
                s ~= format("\tr%d", arg);
            s ~= ")";
            return s;
        case IRInfo.IMM:
            return format("  %s\t%d", this.op, this.lhs);
        case IRInfo.JMP:
            return format("  %s\t.L%s:", this.op, this.lhs);
        case IRInfo.IMM_IMM:
            return format("  %s\t%d\t%d", this.op, this.lhs, this.rhs);
        default:
            assert(0);
        }
    }
}

struct Function
{
    string name;
    IR[] irs;
    size_t stacksize;
}

Function[] genIR(Node[] nodes)
{
    Function[] result;
    foreach (node; nodes)
    {
        assert(node.op == NodeType.FUNCTION);
        size_t regno = 1; // 0番はベースレジスタとして予約
        size_t label;
        IR[] code;

        foreach (i, arg; node.args)
        {
            IRType op = (arg.type.type == TypeName.POINTER) ? IRType.STORE64_ARG
                : IRType.STORE32_ARG;
            code ~= IR(op, arg.offset, i);
        }

        code ~= genStatement(regno, label, node.bdy);

        Function fn;
        fn.name = node.name;
        fn.irs = code;
        fn.stacksize = node.stacksize;
        result ~= fn;
    }
    return result;
}

private:

IR[] genStatement(ref size_t regno, ref size_t label, Node* node)
{
    IR[] result;
    if (node.op == NodeType.VARIABLE_DEFINITION)
    {
        if (!(node.initalize))
        {
            return result;
        }
        long r_value = genExpression(result, regno, label, node.initalize);
        long r_address = regno;
        regno++;
        result ~= IR(IRType.MOV, r_address, 0); // この0は即値ではなくベースレジスタの番号
        result ~= IR(IRType.SUB_IMM, r_address, node.offset);
        IRType op = (node.type.type == TypeName.POINTER) ? IRType.STORE64 : IRType.STORE32;
        result ~= IR(op, r_address, r_value);
        result ~= IR(IRType.KILL, r_address);
        result ~= IR(IRType.KILL, r_value);
        return result;
    }
    if (node.op == NodeType.IF)
    {
        long r = genExpression(result, regno, label, node.cond);
        long l_then_end = label;
        label++;
        result ~= IR(IRType.UNLESS, r, l_then_end);
        result ~= IR(IRType.KILL, r, -1);
        result ~= genStatement(regno, label, node.then);

        if (node.els)
        {
            long l_else_end = label;
            result ~= IR(IRType.JMP, l_else_end);
            result ~= IR(IRType.LABEL, l_then_end);
            result ~= genStatement(regno, label, node.els);
            result ~= IR(IRType.LABEL, l_else_end);
        }
        else
        {
            result ~= IR(IRType.LABEL, l_then_end, -1);
        }
        return result;
    }
    if (node.op == NodeType.FOR)
    {
        long l_loop_enter = label;
        label++;
        long l_loop_end = label;
        label++;

        result ~= genStatement(regno, label, node.initalize);
        result ~= IR(IRType.LABEL, l_loop_enter);
        long r_cond = genExpression(result, regno, label, node.cond);
        result ~= IR(IRType.UNLESS, r_cond, l_loop_end);
        result ~= IR(IRType.KILL, r_cond);

        result ~= genStatement(regno, label, node.bdy);

        result ~= IR(IRType.KILL, genExpression(result, regno, label, node.inc));
        result ~= IR(IRType.JMP, l_loop_enter);
        result ~= IR(IRType.LABEL, l_loop_end);
        return result;
    }
    if (node.op == NodeType.RETURN)
    {
        long r = genExpression(result, regno, label, node.expr);
        result ~= IR(IRType.RETURN, r, -1);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.op == NodeType.EXPRESSION_STATEMENT)
    {
        long r = genExpression(result, regno, label, node.expr);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.op == NodeType.COMPOUND_STATEMENT)
    {
        foreach (n; node.statements)
        {
            result ~= genStatement(regno, label, &n);
        }
        return result;
    }
    error("Unknown node: %s", node.op);
    assert(0);
}

long genExpression(ref IR[] ins, ref size_t regno, ref size_t label, Node* node)
{
    with (NodeType) switch (node.op)
    {
    case NUM:
        long r = regno;
        regno++;
        ins ~= IR(IRType.IMM, r, node.val);
        return r;
    case LOGICAL_AND:
        // 短絡評価
        // falseは0、それ以外はtrue
        size_t l = label;
        label++;

        long r1 = genExpression(ins, regno, label, node.lhs);
        ins ~= IR(IRType.UNLESS, r1, l);

        long r2 = genExpression(ins, regno, label, node.rhs);
        ins ~= IR(IRType.MOV, r1, r2);
        ins ~= IR(IRType.UNLESS, r1, l);

        // true && true の時r1に入っている値は0以外
        // そのままだとあとで困るので1を返す
        ins ~= IR(IRType.IMM, r1, 1);

        ins ~= IR(IRType.LABEL, l);
        return r1;
    case LOGICAL_OR:
        size_t l_rhs = label;
        label++;
        size_t l_ret = label;
        label++;

        long r1 = genExpression(ins, regno, label, node.lhs);
        ins ~= IR(IRType.UNLESS, r1, l_rhs);
        ins ~= IR(IRType.IMM, r1, 1);
        ins ~= IR(IRType.JMP, l_ret);

        ins ~= IR(IRType.LABEL, l_rhs);
        long r2 = genExpression(ins, regno, label, node.rhs);
        ins ~= IR(IRType.MOV, r1, r2);
        ins ~= IR(IRType.KILL, r2);
        ins ~= IR(IRType.UNLESS, r1, l_ret);
        ins ~= IR(IRType.IMM, r1, 1);

        ins ~= IR(IRType.LABEL, l_ret);
        return r1;
    case VARIABLE_REFERENCE:
        long r = genLval(ins, regno, label, node);
        IRType op = (node.type.type == TypeName.POINTER) ? IRType.LOAD64 : IRType.LOAD32;
        ins ~= IR(op, r, r);
        return r;
    case ADDRESS:
        return genLval(ins, regno, label, node.expr);
    case DEREFERENCE:
        long r = genExpression(ins, regno, label, node.expr);
        ins ~= IR(IRType.LOAD64, r, r);
        return r;
    case ASSIGN:
        long rhs = genExpression(ins, regno, label, node.rhs);
        long lhs = genLval(ins, regno, label, node.lhs);
        IRType op = (node.type.type == TypeName.POINTER) ? IRType.STORE64 : IRType.STORE32;
        ins ~= IR(op, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs, -1);
        return lhs;
    case CALL:
        IR ir;
        ir.op = IRType.CALL;
        foreach (arg; node.args)
            ir.args ~= genExpression(ins, regno, label, &arg);

        long r = regno;
        regno++;
        ir.lhs = r;
        ir.name = node.name;
        ins ~= ir;
        foreach (reg; ir.args)
            ins ~= IR(IRType.KILL, reg, -1);
        return r;
    case ADD:
    case SUB:
        IRType insn = (node.op == NodeType.ADD) ? IRType.ADD : IRType.SUB;
        if (node.lhs.type.type != TypeName.POINTER)
        {
            return genBinaryOp(ins, regno, label, insn, node.lhs, node.rhs);
        }
        // pointer_of_T + rhs -> pointer_of_T + (rhs * sizeof(T))
        long r_rhs = genExpression(ins, regno, label, node.rhs);
        long r_sizeof = regno;
        regno++;
        ins ~= IR(IRType.IMM, r_sizeof, size_of(*(node.lhs.type.pointer_of)));
        ins ~= IR(IRType.MUL, r_rhs, r_sizeof);
        ins ~= IR(IRType.KILL, r_sizeof);
        long r_lhs = genExpression(ins, regno, label, node.lhs);
        ins ~= IR(insn, r_lhs, r_rhs);
        ins ~= IR(IRType.KILL, r_rhs);
        return r_lhs;
    case MUL:
        return genBinaryOp(ins, regno, label, IRType.MUL, node.lhs, node.rhs);
    case DIV:
        return genBinaryOp(ins, regno, label, IRType.DIV, node.lhs, node.rhs);
    case LESS_THAN:
        return genBinaryOp(ins, regno, label, IRType.LESS_THAN, node.lhs, node.rhs);
    default:
        // IDENTIFIERは前プロセスで別のノードに変換されている
        error("Unknown AST Type: %s", node.op);
        assert(0);
    }
}

long genLval(ref IR[] ins, ref size_t regno, ref size_t label, Node* node)
{
    if (node.op == NodeType.VARIABLE_REFERENCE)
    {
        long r = regno;
        regno++;
        ins ~= IR(IRType.MOV, r, 0);
        ins ~= IR(IRType.SUB_IMM, r, node.offset);
        return r;
    }
    if (node.op == NodeType.DEREFERENCE)
    {
        return genExpression(ins, regno, label, node.expr);
    }

    error("Not an lvalue: %s (%s)", node.op, node.name);
    assert(0);
}

long genBinaryOp(ref IR[] ins, ref size_t regno, ref size_t label, IRType type,
        Node* lhs, Node* rhs)
{
    long r_lhs = genExpression(ins, regno, label, lhs);
    long r_rhs = genExpression(ins, regno, label, rhs);
    ins ~= IR(type, r_lhs, r_rhs);
    ins ~= IR(IRType.KILL, r_rhs);
    return r_lhs;
}
