import std.stdio : writeln, writefln, stderr;
import std.conv : to;

int main(string[] args)
{
    if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc <code>");
        return 1;
    }

    writeln(".intel_syntax noprefix"); // intel記法を使う
    writeln(".global main");
    writeln("main:");
    writefln("  mov rax, %d", args[1].to!int);
    writeln("  ret");
    return 0;
}
