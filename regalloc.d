/// レジスタ割当
module regalloc;

import std.stdio : stderr;

import ir;
import util;

public:
// 関数呼び出し前後で保存されることが保証されているレジスタを使ってレジスタの無駄な退避をなくす
// 前段階で0番レジスタをベースレジスタ扱いしているのでrbpも他のレジスタと同じように扱える
static immutable string[] registers = ["rbp", "rbx", "r10", "r11", "r12", "r13", "r14", "r15"];

void allocRegisters(ref Function[] fns)
{
    foreach (ref fn; fns)
    {
        visit(fn.irs);
    }
}

private:

void visit(ref IR[] ins)
{
    size_t[size_t] reg_map;
    reg_map[0] = 0;
    bool[] used = new bool[](registers.length);
    used[] = false;
    used[0] = true; // ベースレジスタ

    foreach (ref ir; ins)
    {
        switch (ir.getInfo())
        {
        case IRInfo.REG:
        case IRInfo.REG_LABEL:
        case IRInfo.REG_IMM:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            break;
        case IRInfo.REG_REG:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            ir.rhs = alloc(reg_map, used, ir.rhs);
            break;
        case IRInfo.CALL:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            foreach (i, r; ir.args)
                ir.args[i] = alloc(reg_map, used, r);
            break;
        default:
            break;
        }
        if (ir.op == IRType.KILL)
        {
            kill(used, ir.lhs);
            ir.op = IRType.NOP; // レジスタ割当専用命令なので特に対応する命令はない
        }
    }
}

/// 使われていないレジスタを探して中間表現のレジスタと紐付ける
size_t alloc(ref size_t[size_t] reg_map, ref bool[] used, size_t ir_reg)
{
    if (ir_reg in reg_map)
    {
        size_t r = reg_map[ir_reg];
        assert(used[r]);
        return r;
    }
    foreach (i; 0 .. registers.length)
    {
        if (used[i])
            continue;
        used[i] = true;
        reg_map[ir_reg] = i;
        return i;
    }
    stderr.writeln("Register exhausted");
    throw new ExitException(-1);
}

/// レジスタの解放
void kill(ref bool[] used, size_t r)
{
    assert(used[r]);
    used[r] = false;
}
