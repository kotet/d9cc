module irdump;

import std.format;

import gen_ir;

enum IRInfo
{
    NOARG,
    REG,
    LABEL,
    LABEL_ADDRESS,
    REG_REG,
    REG_IMM,
    REG_LABEL,
    CALL,
    IMM,
    IMM_IMM,
    JMP,
}

IRInfo getInfo(IR ir)
{
    switch (ir.op)
    {
    case IRType.MOV:
    case IRType.ADD:
    case IRType.SUB:
    case IRType.MUL:
    case IRType.DIV:
    case IRType.LOAD8:
    case IRType.LOAD32:
    case IRType.LOAD64:
    case IRType.STORE8:
    case IRType.STORE32:
    case IRType.STORE64:
    case IRType.LESS_THAN:
    case IRType.EQUAL:
    case IRType.NOT_EQUAL:
        return IRInfo.REG_REG;
    case IRType.IMM:
    case IRType.ADD_IMM:
    case IRType.BPREL:
        return IRInfo.REG_IMM;
    case IRType.RETURN:
    case IRType.KILL:
        return IRInfo.REG;
    case IRType.LABEL:
        return IRInfo.LABEL;
    case IRType.JMP:
        return IRInfo.JMP;
    case IRType.IF:
    case IRType.UNLESS:
        return IRInfo.REG_LABEL;
    case IRType.CALL:
        return IRInfo.CALL;
    case IRType.NOP:
        return IRInfo.NOARG;
    case IRType.STORE8_ARG:
    case IRType.STORE32_ARG:
    case IRType.STORE64_ARG:
        return IRInfo.IMM_IMM;
    case IRType.LABEL_ADDRESS:
        return IRInfo.LABEL_ADDRESS;
    default:
        assert(0);
    }
}

// -dump-irオプション用
string toString(IR ir)
{
    switch (ir.getInfo())
    {
    case IRInfo.REG_REG:
        return format("  %s\tr%d\tr%d", ir.op, ir.lhs, ir.rhs);
    case IRInfo.REG_IMM:
        return format("  %s\tr%d\t%d", ir.op, ir.lhs, ir.rhs);
    case IRInfo.REG:
        return format("  %s\tr%d", ir.op, ir.lhs);
    case IRInfo.LABEL:
        return format(".L%s:", ir.lhs);
    case IRInfo.REG_LABEL:
        return format("  %s\tr%d\t.L%s", ir.op, ir.lhs, ir.rhs);
    case IRInfo.NOARG:
        return format("  %s", ir.op);
    case IRInfo.CALL:
        string s = format("  r%d = %s(", ir.lhs, ir.name);
        foreach (arg; ir.args)
            s ~= format("\tr%d", arg);
        s ~= ")";
        return s;
    case IRInfo.IMM:
        return format("  %s\t%d", ir.op, ir.lhs);
    case IRInfo.JMP:
        return format("  %s\t.L%s:", ir.op, ir.lhs);
    case IRInfo.IMM_IMM:
        return format("  %s\t%d\t%d", ir.op, ir.lhs, ir.rhs);
    case IRInfo.LABEL_ADDRESS:
        return format("  %s\tr%d\t%s", ir.op, ir.lhs, ir.name);
    default:
        assert(0);
    }
}
