import std.stdio : writeln, stderr;

import token;
import parser;
import ir;
import regalloc;
import codegen;
import util;

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

        Node* node = parse(tokens);

        IR[] ins = genIR(node);

        // stderr.writeln(ins);

        size_t[size_t] reg_map = allocRegisters(ins);

        writeln(".intel_syntax noprefix"); // intel記法を使う
        writeln(".global main");
        writeln("main:");

        generate_x86(ins);
        return 0;
    }
    catch (ExitException e)
    {
        return e.rc;
    }
}
