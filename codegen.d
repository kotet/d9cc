/// コード生成器
module codegen;

import std.stdio : writefln, stderr;
import std.format : format;

import ir;
import regalloc;

public:

void generate_x86(Function[] fns)
{
    writefln(".intel_syntax noprefix"); // intel記法を使う
    size_t labelcnt;
    foreach (fn; fns)
        gen(fn, labelcnt);
}

private:

void gen(Function fn, ref size_t labelcnt)
{
    writefln(".global %s", fn.name);
    writefln("%s:", fn.name);

    // 終了処理の開始位置に置くラベル
    string ret = format(".Lend%d", labelcnt);
    labelcnt++;

    // レジスタをスタックに退避
    // rspはrbpから復元
    enum save_regs = ["rbx", "rbp", "r12", "r13", "r14", "r15"];
    static foreach (reg; save_regs)
    {
        writefln("  push %s", reg);
    }
    writefln("  mov rbp, rsp");


    // 最後に出力するものだけど上と対になってるので近くに置いたほうが読みやすいかなと思った
    scope (success)
    {
        // スタックからレジスタを復元
        // rspはrbpから復元
        writefln("%s:", ret);
        writefln("  mov rsp, rbp");
        static foreach_reverse (reg; save_regs)
        {
            writefln("  pop %s", reg);
        }
        writefln("  ret");
    }

    foreach (ir; fn.irs)
    {
        // 計算結果はlhsのレジスタに格納
        switch (ir.op)
        {
        case IRType.IMM:
            writefln("  mov %s, %d", registers[ir.lhs], ir.rhs);
            break;
        case IRType.MOV:
            writefln("  mov %s, %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.RETURN:
            writefln("  mov rax, %s", registers[ir.lhs]);
            writefln("  jmp %s", ret);
            break;
        case IRType.ALLOCA:
            // スタックはアドレスの小さい方に伸びていく
            if (ir.rhs != 0)
            {
                writefln("  sub rsp, %d", ir.rhs);
            }
            writefln("  mov %s, rsp", registers[ir.lhs]);
            break;
        case IRType.LOAD:
            writefln("  mov %s, [%s]", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.STORE:
            writefln("  mov [%s], %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.ADD_IMM:
            writefln("  add %s, %d", registers[ir.lhs], ir.rhs);
            break;
        case IRType.ADD:
            writefln("  add %s, %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.SUB:
            writefln("  sub %s, %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.MUL:
            // ここ写経元だとrhs *= lhsになってた
            writefln("  mov rax, %s", registers[ir.lhs]);
            writefln("  mul %s", registers[ir.rhs]);
            writefln("  mov %s, rax", registers[ir.lhs]);
            break;
        case IRType.DIV:
            writefln("  mov rax, %s", registers[ir.lhs]);
            // 符号拡張
            // 負数を扱うときとかにこれがないとバグる
            writefln("  cqo");
            // raxに商、rdxに剰余が入る
            writefln("  div %s", registers[ir.rhs]);
            writefln("  mov %s, rax", registers[ir.lhs]);
            break;
        case IRType.LABEL:
            writefln(".L%d:", ir.lhs);
            break;
        case IRType.UNLESS:
            // 右辺(この場合0)との差が0ならゼロフラグが1になる
            writefln("  cmp %s, 0", registers[ir.lhs]);
            // ゼロフラグが1ならジャンプ
            writefln("  je .L%d", ir.rhs);
            break;
        case IRType.JMP:
            writefln("  jmp .L%d", ir.lhs);
            break;
        case IRType.CALL:

            static immutable string[] regs_arg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"];
            foreach (i, arg; ir.args)
            {
                writefln("  mov %s, %s", regs_arg[i], registers[arg]);
            }
            // レジスタの退避
            writefln("  push r10");
            writefln("  push r11");

            writefln("  mov rax, 0");
            writefln("  call %s", ir.name);

            // レジスタの復元
            writefln("  pop r11");
            writefln("  pop r10");

            writefln("  mov %s, rax", registers[ir.lhs]);
            break;
        case IRType.NOP:
            break;
        default:
            assert(0, "Unknown operator");
        }
    }
}

string genLabel(size_t labelcnt)
{
    return format(".L%d", labelcnt);
}
