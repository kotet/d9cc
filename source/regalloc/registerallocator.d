module regalloc.registerallocator;

import util;
static import IR = ir.classes;

import std.stdio;

class RegisterAllocator
{
    IR.IR[] irs;
    bool[regs.length] used;
    size_t[size_t] regmap;

    this(IR.IR[] _irs)
    {
        this.irs = _irs.dup;
    }

    private size_t alloc(size_t reg, size_t line, size_t column)
    {
        if (reg in regmap)
        {
            size_t r = regmap[reg];
            assert(used[r]);
            return r;
        }
        else
        {
            foreach (i; 0 .. regs.length)
            {
                if (!used[i])
                {
                    used[i] = true;
                    regmap[reg] = i;
                    return i;
                }
            }
            error("register exhausted", line, column);
            assert(0);
        }
    }

    private void kill(size_t reg)
    {
        size_t r = regmap[reg];
        assert(used[r]);
        used[r] = false;
    }

    IR.IR[] allocate()
    {
        loop: foreach (i, ref ir; irs)
        {
            {
                auto c = cast(IR.IMM) ir;
                if (c !is null)
                {
                    c.reg = alloc(c.reg, c.line, c.column);
                    continue loop;
                }
            }
            static foreach (op; "+-")
            {
                {
                    auto c = cast(IR.BINOP!(op)) ir;
                    if (c !is null)
                    {
                        c.dst = alloc(c.dst, c.line, c.column);
                        c.src = alloc(c.src, c.line, c.column);
                        continue loop;
                    }
                }
            }
            {
                auto c = cast(IR.RET) ir;
                if (c !is null)
                {
                    kill(c.reg);
                    continue loop;
                }
            }
            {
                auto c = cast(IR.KILL) ir;
                if (c !is null)
                {
                    kill(c.reg);
                    ir = new IR.NOP(c.line, c.column);
                    continue loop;
                }
            }
            error("unknown operator: %s", ir.line, ir.column, ir);
        }
        return irs;
    }
}
