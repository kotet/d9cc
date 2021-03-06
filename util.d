module util;

import std.ascii : isDigit;
import std.stdio : stderr;

public:

enum TypeName
{
    INT,
    POINTER,
    ARRAY,
    CHAR,
}

struct Type
{
    TypeName type;
    Type* pointer_to;

    // 配列
    Type* array_of;
    size_t array_length;
}

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

// Enumの番号を表示
mixin template debugEnum(E)
{
    import std.traits : EnumMembers;

    pragma(msg, E, ":");
    static foreach (e; EnumMembers!E)
        static if (e <= char.max)
            {
            pragma(msg, "\t", cast(char) e, "\t= ", cast(int) e);
        }
        else
            {
            pragma(msg, "\t", cast(int) e, "\t= ", cast(int) e);
        }
}

long size_of(Type t)
{
    with (TypeName) switch (t.type)
    {
    case CHAR:
        return 1;
    case INT:
        return 4;
    case ARRAY:
        return size_of(*t.array_of) * t.array_length;
    default:
        assert(t.type == TypeName.POINTER);
        return 8;
    }
}

long align_of(Type t)
{
    with (TypeName) switch (t.type)
    {
    case CHAR:
        return 1;
    case INT:
        return 4;
    case POINTER:
        return 8;
    default:
        assert(t.type == TypeName.ARRAY);
        return align_of(*t.array_of);
    }
}

size_t roundup(size_t x, size_t alignment)
{
    // alignmentは2の倍数。
    // (x + alignment - 1) - ((x + alignment -1) % alignment) と等価。
    size_t tmp = (alignment - 1);
    return (x + tmp) & ~tmp;
}
