/// コード生成器
module codegen;

import std.stdio : writefln;
import std.format : format;

import ir;
import regalloc;

public:

void generate_x86(IR[] ins)
{
    size_t labelcnt;
    string ret = ".Lend";

    writefln("  push rbp");
    writefln("  mov rbp, rsp");

    foreach (ir; ins)
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
            if (ir.rhs != -1)
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
            // レジスタをスタックに退避
            // これcallee-savedレジスタだと思うんだけどこうしないと動かない。
            // 調べても意図がわからなかった……
            enum save_regs = ["rbx", "rbp", "rsp", "r12", "r13", "r14", "r15"];
            static foreach (reg; save_regs)
            {
                writefln("  push %s", reg);
            }

            static immutable string[] regs_arg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"];
            foreach (i, arg; ir.args)
            {
                writefln("  mov %s, %s", regs_arg[i], registers[arg]);
            }

            writefln("  mov rax, 0");
            writefln("  call %s", ir.name);
            writefln("  mov %s, rax", registers[ir.lhs]);

            static foreach_reverse (reg; save_regs)
            {
                writefln("  pop %s", reg);
            }
            break;
        case IRType.NOP:
            break;
        default:
            assert(0, "Unknown operator");
        }
    }

    writefln("%s:", ret);
    writefln("  mov rsp, rbp");
    writefln("  pop rbp");
    writefln("  ret");
}

private:

string genLabel(size_t labelcnt)
{
    return format(".L%d", labelcnt);
}
