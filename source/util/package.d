module util;

import std.stdio;

static immutable regs = ["rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"];

/// Cみたいにどこでもexit()するための例外
class ExitException : Exception
{
    /// 終了コード
    int rc;

    this(int return_code = 0, string file = __FILE__, size_t line = __LINE__)
    {
        super(null, file, line);
        this.rc = return_code;
    }
}

void error(A...)(string msg, size_t lineno, size_t column, A args)
{
    stderr.writefln("(%d, %d) Error: " ~ msg, lineno, column, args);
    throw new ExitException(-1);
}
