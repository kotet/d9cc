module codegen.codegenerator;

static import IR = ir.classes;
import util;

import std.stdio;

class CodeGenerator
{
    IR.IR[] irs;
    this(IR.IR[] _irs)
    {
        this.irs = _irs.dup;
    }

    void generate()
    {
        writefln(".intel_syntax noprefix");
        writefln(".global main");
        writefln("main:");

        loop: foreach (ir; irs)
        {
            {
                auto c = cast(IR.IMM) ir;
                if (c !is null)
                {
                    writefln("  mov %s, %d", regs[c.reg], c.value);
                    continue loop;
                }
            }
            {
                auto c = cast(IR.BINOP!'+') ir;
                if (c !is null)
                {
                    writefln("  add %s, %s", regs[c.dst], regs[c.src]);
                    continue loop;
                }
            }
            {
                auto c = cast(IR.BINOP!'-') ir;
                if (c !is null)
                {
                    writefln("  sub %s, %s", regs[c.dst], regs[c.src]);
                    continue loop;
                }
            }
            {
                auto c = cast(IR.RET) ir;
                if (c !is null)
                {
                    writefln("  mov rax, %s", regs[c.reg]);
                    writefln("  ret");
                    continue loop;
                }
            }
            {
                auto c = cast(IR.NOP) ir;
                if (c !is null)
                {
                    continue loop;
                }
            }
            error("unknown operator: %s", ir.line, ir.column, ir);
        }
    }
}
