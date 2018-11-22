/// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
module gen_ir;

import std.algorithm : among;
import std.stdio : stderr;
import std.range : empty;

import parser;
import util;
import sema;
import irdump;

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
    LOAD8,
    LOAD32,
    LOAD64,
    STORE8,
    STORE32,
    STORE64,
    STORE8_ARG, // char引数の保持
    STORE32_ARG, // int引数の保持
    STORE64_ARG, // ポインタ引数の保持
    ADD_IMM, // 即値add
    BPREL, // ベースポインタからの相対位置から実効アドレスを計算
    LABEL,
    LABEL_ADDRESS,
    IF,
    UNLESS,
    JMP,
    CALL,
    EQUAL,
    NOT_EQUAL,
}

struct IR
{
    IRType op;
    long lhs;
    long rhs;

    // 関数呼び出し
    string name;
    long[] args;
}

struct Function
{
    string name;
    IR[] irs;
    size_t stacksize;
    Variable[] globals;
}

Function[] genIR(Node[] nodes)
{
    Function[] result;
    label = 1;
    foreach (node; nodes)
    {
        if (node.op == NodeType.VARIABLE_DEFINITION)
        {
            continue;
        }

        assert(node.op == NodeType.FUNCTION);
        regno = 1; // 0番はベースレジスタとして予約
        IR[] code;

        foreach (i, arg; node.args)
        {
            IRType insn = chooseInsn(&arg, IRType.STORE8_ARG,
                    IRType.STORE32_ARG, IRType.STORE64_ARG);
            code ~= IR(insn, arg.offset, i);
        }

        code ~= genStatement(node.bdy);

        Function fn;
        fn.name = node.name;
        fn.irs = code;
        fn.stacksize = node.stacksize;
        fn.globals = node.globals;
        result ~= fn;
    }
    return result;
}

private:

size_t regno;
size_t label;
size_t return_label;
size_t return_reg;

IR[] genStatement(Node* node)
{
    IR[] result;
    if (node.op == NodeType.NULL)
    {
        return result;
    }
    if (node.op == NodeType.VARIABLE_DEFINITION)
    {
        if (!(node.initalize))
        {
            return result;
        }
        long r_value = genExpression(result, node.initalize);
        long r_address = regno;
        regno++;
        result ~= IR(IRType.BPREL, r_address, node.offset);

        IRType insn = chooseInsn(node, IRType.STORE8, IRType.STORE32, IRType.STORE64);
        result ~= IR(insn, r_address, r_value);

        result ~= IR(IRType.KILL, r_address);
        result ~= IR(IRType.KILL, r_value);
        return result;
    }
    if (node.op == NodeType.IF)
    {
        long r = genExpression(result, node.cond);
        long l_then_end = label;
        label++;
        result ~= IR(IRType.UNLESS, r, l_then_end);
        result ~= IR(IRType.KILL, r, -1);
        result ~= genStatement(node.then);

        if (node.els)
        {
            long l_else_end = label;
            label++;
            result ~= IR(IRType.JMP, l_else_end);
            result ~= IR(IRType.LABEL, l_then_end);
            result ~= genStatement(node.els);
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

        result ~= genStatement(node.initalize);
        result ~= IR(IRType.LABEL, l_loop_enter);
        long r_cond = genExpression(result, node.cond);
        result ~= IR(IRType.UNLESS, r_cond, l_loop_end);
        result ~= IR(IRType.KILL, r_cond);

        result ~= genStatement(node.bdy);

        result ~= genStatement(node.inc);
        result ~= IR(IRType.JMP, l_loop_enter);
        result ~= IR(IRType.LABEL, l_loop_end);
        return result;
    }
    if (node.op == NodeType.DO_WHILE)
    {
        long l_loop_enter = label;
        label++;

        result ~= IR(IRType.LABEL, l_loop_enter);
        result ~= genStatement(node.bdy);
        long r_cond = genExpression(result, node.cond);
        result ~= IR(IRType.IF, r_cond, l_loop_enter);
        result ~= IR(IRType.KILL, r_cond);
        return result;
    }
    if (node.op == NodeType.RETURN)
    {
        long r = genExpression(result, node.expr);
        if (return_label != 0)
        {
            result ~= IR(IRType.MOV, return_reg, r);
            result ~= IR(IRType.KILL, r);
            result ~= IR(IRType.JMP, return_label);
            return result;
        }
        result ~= IR(IRType.RETURN, r, -1);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.op == NodeType.EXPRESSION_STATEMENT)
    {
        long r = genExpression(result, node.expr);
        result ~= IR(IRType.KILL, r, -1);
        return result;
    }
    if (node.op == NodeType.COMPOUND_STATEMENT)
    {
        foreach (n; node.statements)
        {
            result ~= genStatement(&n);
        }
        return result;
    }
    error("Unknown node: %s", node.op);
    assert(0);
}

long genExpression(ref IR[] ins, Node* node)
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

        long r1 = genExpression(ins, node.lhs);
        ins ~= IR(IRType.UNLESS, r1, l);

        long r2 = genExpression(ins, node.rhs);
        ins ~= IR(IRType.MOV, r1, r2);
        ins ~= IR(IRType.UNLESS, r1, l);
        ins ~= IR(IRType.KILL, r2);

        // true && true の時r1に入っている値は0以外
        // そのままだとあとで��るので1を返す
        ins ~= IR(IRType.IMM, r1, 1);

        ins ~= IR(IRType.LABEL, l);
        return r1;
    case LOGICAL_OR:
        size_t l_rhs = label;
        label++;
        size_t l_ret = label;
        label++;

        long r1 = genExpression(ins, node.lhs);
        ins ~= IR(IRType.UNLESS, r1, l_rhs);
        ins ~= IR(IRType.IMM, r1, 1);
        ins ~= IR(IRType.JMP, l_ret);

        ins ~= IR(IRType.LABEL, l_rhs);
        long r2 = genExpression(ins, node.rhs);
        ins ~= IR(IRType.MOV, r1, r2);
        ins ~= IR(IRType.KILL, r2);
        ins ~= IR(IRType.UNLESS, r1, l_ret);
        ins ~= IR(IRType.IMM, r1, 1);

        ins ~= IR(IRType.LABEL, l_ret);
        return r1;
    case LOCAL_VARIABLE:
    case GLOBAL_VARIABLE:
        long r = genLval(ins, node);

        IRType insn = chooseInsn(node, IRType.LOAD8, IRType.LOAD32, IRType.LOAD64);
        ins ~= IR(insn, r, r);

        return r;
    case ADDRESS:
        return genLval(ins, node.expr);
    case DEREFERENCE:
        long r = genExpression(ins, node.expr);

        IRType insn = chooseInsn(node, IRType.LOAD8, IRType.LOAD32, IRType.LOAD64);
        ins ~= IR(insn, r, r);

        return r;
    case ASSIGN:
        long rhs = genExpression(ins, node.rhs);
        long lhs = genLval(ins, node.lhs);
        IRType op = (node.type.type == TypeName.POINTER) ? IRType.STORE64 : IRType.STORE32;
        ins ~= IR(op, lhs, rhs);
        ins ~= IR(IRType.KILL, rhs, -1);
        return lhs;
    case CALL:
        IR ir;
        ir.op = IRType.CALL;
        foreach (arg; node.args)
            ir.args ~= genExpression(ins, &arg);

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
            return genBinaryOp(ins, insn, node);
        }
        // pointer_to_T + rhs -> pointer_to_T + (rhs * sizeof(T))
        long r_rhs = genExpression(ins, node.rhs);
        long r_sizeof = regno;
        regno++;
        ins ~= IR(IRType.IMM, r_sizeof, size_of(*(node.lhs.type.pointer_to)));
        ins ~= IR(IRType.MUL, r_rhs, r_sizeof);
        ins ~= IR(IRType.KILL, r_sizeof);
        long r_lhs = genExpression(ins, node.lhs);
        ins ~= IR(insn, r_lhs, r_rhs);
        ins ~= IR(IRType.KILL, r_rhs);
        return r_lhs;
    case MUL:
        return genBinaryOp(ins, IRType.MUL, node);
    case DIV:
        return genBinaryOp(ins, IRType.DIV, node);
    case LESS_THAN:
        return genBinaryOp(ins, IRType.LESS_THAN, node);
    case EQUAL:
        return genBinaryOp(ins, IRType.EQUAL, node);
    case NOT_EQUAL:
        return genBinaryOp(ins, IRType.NOT_EQUAL, node);
    case STATEMENT_EXPRESSION:
        size_t orig_label = return_label;
        size_t orig_reg = return_reg;
        return_label = label;
        label++;
        size_t r_ret = regno;
        regno++;
        return_reg = r_ret;
        ins ~= genStatement(node.bdy);
        ins ~= IR(IRType.LABEL, return_label);
        return_label = orig_label;
        return_reg = orig_reg;
        return r_ret;
    default: // IDENTIFIERは前プロセスで別のノードに変換されている
        error("Unknown AST Type: %s", node.op);
        assert(0);
    }
}

long genLval(ref IR[] ins, Node* node)
{
    if (node.op == NodeType.LOCAL_VARIABLE)
    {
        long r = regno;
        regno++;
        ins ~= IR(IRType.BPREL, r, node.offset);
        return r;
    }
    if (node.op == NodeType.DEREFERENCE)
    {
        return genExpression(ins, node.expr);
    }
    if (node.op == NodeType.GLOBAL_VARIABLE)
    {
        IR ir;
        ir.op = IRType.LABEL_ADDRESS;
        long r = regno;
        regno++;
        ir.lhs = r;
        ir.name = node.name;
        ins ~= ir;
        return r;
    }
    assert(0);
}

long genBinaryOp(ref IR[] ins, IRType type, Node* node)
{
    long r_lhs = genExpression(ins, node.lhs);
    long r_rhs = genExpression(ins, node.rhs);
    ins ~= IR(type, r_lhs, r_rhs);
    ins ~= IR(IRType.KILL, r_rhs);
    return r_lhs;
}

IRType chooseInsn(Node* node, IRType i8, IRType i32, IRType i64)
{
    long size = size_of(*node.type);
    if (size == 1)
    {
        return i8;
    }
    if (size == 4)
    {
        return i32;
    }
    assert(size == 8);
    return i64;
}
