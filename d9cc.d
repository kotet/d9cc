import std.stdio : writeln, writefln, stderr;
import std.conv : to;
import std.uni : isSpace;
import std.ascii : isDigit;
import std.array : join;

enum TokenType
{
    NUM,
    ADD = '+',
    SUB = '-',
    EOF
}

struct Token
{
    TokenType type;
    int val; // 数値リテラルデータ
    string input; // エラー報告用のトークン文字列
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

Token[] tokenize(string s)
{
    Token[] result;
    size_t i;

    while (i < s.length) // Dの文字列はNull終端ではない
    {
        if (s[i].isSpace())
        {
            i++;
            continue;
        }

        if (s[i] == '+' || s[i] == '-')
        {
            Token t;
            t.type = cast(TokenType) s[i];
            t.input = s[i .. i + 1];

            result ~= t;
            i++;
            continue;
        }

        if (s[i].isDigit())
        {
            Token t;
            t.type = TokenType.NUM;
            size_t _i = i;
            t.val = nextInt(s, i);
            t.input = s[_i .. i];

            result ~= t;
            continue;
        }

        stderr.writefln("Cannot tokenize: %s", s[i]);
        throw new ExitException(-1);
    }

    result ~= () { Token t; t.type = TokenType.EOF; return t; }();

    return result;
}

void fail(Token t)
{
    stderr.writefln("Unexpected token: %s (%s)", t.input, t.type);
    throw new ExitException(-1);
}

/// strtolの代わり
int nextInt(string s, ref size_t i)
{
    int result;
    while (i < s.length && '0' <= s[i] && s[i] <= '9')
    {
        result = (result * 10) + (s[i] - '0');
        i++;
    }
    return result;
}

int main(string[] args)
{
    if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc <code>");
        return 1;
    }

    try
    {
        Token[] tokens = tokenize(args[1]);

        writeln(".intel_syntax noprefix"); // intel記法を使う
        writeln(".global main");
        writeln("main:");

        if (tokens[0].type != TokenType.NUM)
            fail(tokens[0]);

        writefln("  mov rax, %d", tokens[0].val);

        size_t i = 1;

        while (tokens[i].type != TokenType.EOF)
        {
            if (tokens[i].type == TokenType.ADD)
            {
                i++;
                if (tokens[i].type != TokenType.NUM)
                    fail(tokens[i]);
                writefln("  add rax, %d", tokens[i].val);
                i++;
                continue;
            }

            if (tokens[i].type == TokenType.SUB)
            {
                i++;
                if (tokens[i].type != TokenType.NUM)
                    fail(tokens[i]);
                writefln("  sub rax, %d", tokens[i].val);
                i++;
                continue;
            }
            fail(tokens[i]);
        }
        writeln("  ret");
        return 0;

    }
    catch (ExitException e)
    {
        return e.rc;
    }
}
