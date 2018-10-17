module util;

import std.ascii : isDigit;
import std.stdio : stderr;

public:

/// strtolの代わり
int nextInt(string s, ref size_t i)
{
    int result;
    while (i < s.length && s[i].isDigit())
    {
        result = (result * 10) + (s[i] - '0');
        i++;
    }
    return result;
}

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

void error(A...)(string msg, A args)
{
    stderr.writefln(msg, args);
    throw new ExitException(-1);
}
