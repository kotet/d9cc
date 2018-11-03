/// コード生成器
module gen_x86;

import std.stdio : writeln, writefln, stderr;
import std.format : format;

import gen_ir;
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

static immutable string[] regs_arg8 = ["dil", "sil", "dl", "cl", "r8b", "r9b"];
static immutable string[] regs_arg32 = ["edi", "esi", "edx", "ecx", "r8d", "r9d"];
static immutable string[] regs_arg64 = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"];

void gen(Function fn, ref size_t labelcnt)
{
    writefln(".global %s", fn.name);
    writefln("%s:", fn.name);

    writefln("  push rbp");
    writefln("  mov rbp, rsp");
    writefln("  sub rsp, %d", fn.stacksize);

    // 終了処理の開始位置に置くラベル
    string ret = format(".Lend%d", labelcnt);
    labelcnt++;

    // レジスタをスタックに退避
    // rspはrbpから復元
    enum save_regs = ["rbx", "r12", "r13", "r14", "r15"];
    static foreach (reg; save_regs)
    {
        writefln("  push %s", reg);
    }

    // 最後に出力するものだけど上と対になってるので近くに置いたほうが読みやすいかなと思った
    scope (success)
    {
        // スタックからレジスタを復元
        // rspはrbpから復元
        writefln("%s:", ret);
        static foreach_reverse (reg; save_regs)
        {
            writefln("  pop %s", reg);
        }
        writefln("  mov rsp, rbp");
        writefln("  pop rbp");
        writefln("  ret");
        writeln();
    }

    writeln();

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
        case IRType.LOAD64:
            writefln("  mov %s, [%s]", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.STORE64:
            writefln("  mov [%s], %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.LOAD32:
            writefln("  mov %s, [%s]",
                    registers_lower_32bits[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.STORE32:
            writefln("  mov [%s], %s", registers[ir.lhs],
                    registers_lower_32bits[ir.rhs]);
            break;
        case IRType.LOAD8:
            writefln("  mov %s, [%s]",
                    registers_lower_8bits[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.STORE8:
            writefln("  mov [%s], %s", registers[ir.lhs],
                    registers_lower_8bits[ir.rhs]);
            break;
        case IRType.ADD_IMM:
            writefln("  add %s, %d", registers[ir.lhs], ir.rhs);
            break;
        case IRType.SUB_IMM:
            writefln("  sub %s, %d", registers[ir.lhs], ir.rhs);
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
            foreach (i, arg; ir.args)
            {
                writefln("  mov %s, %s", regs_arg64[i], registers[arg]);
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
        case IRType.STORE8_ARG:
            // rbpからの相対アドレス
            writefln("  mov [rbp-%d], %s", ir.lhs, regs_arg8[ir.rhs]);
            break;
        case IRType.STORE32_ARG:
            writefln("  mov [rbp-%d], %s", ir.lhs, regs_arg32[ir.rhs]);
            break;
        case IRType.STORE64_ARG:
            writefln("  mov [rbp-%d], %s", ir.lhs, regs_arg64[ir.rhs]);
            break;
        case IRType.LESS_THAN:
            // lhs - rhsが負数、つまりlhs < rhsのとき符号フラグが1になる
            writefln("  cmp %s, %s", registers[ir.lhs], registers[ir.rhs]);
            // setlは符号フラグが1のとき1をセットする。
            // 結果は1バイトの値なのでレジスタも8ビットのものを使う
            writefln("  setl %s", registers_lower_8bits[ir.lhs]);
            // 上位ビットは変化しないので適切にゼロ拡張してやる必要がある。
            // movzbは8ビットの値を64ビットにゼロ拡張して格納する。
            // 結果的に、下のコードはlhsレジスタの上位ビットをただゼロ埋めする
            writefln("  movzb %s, %s", registers[ir.lhs], registers_lower_8bits[ir.lhs]);
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
