import std.stdio : writeln, writefln, stderr;
import std.conv : to;

int main(string[] args)
{
    if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc <code>");
        return 1;
    }

    size_t i;
    string s = args[1];

    writeln(".intel_syntax noprefix"); // intel記法を使う
    writeln(".global main");
    writeln("main:");
    writefln("  mov rax, %d", s.nextInt(i));

    while (i < s.length) // Dの文字列はNull終端ではない
    {
        if (s[i] == '+')
        {
            i++;
            writefln("  add rax, %d", s.nextInt(i));
            continue;
        }
        if (s[i] == '-')
        {
            i++;
            writefln("  sub rax, %d", s.nextInt(i));
            continue;
        }

        stderr.writefln("Unexpected character: %s", s[i]);
    }

    writeln("  ret");
    return 0;
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
