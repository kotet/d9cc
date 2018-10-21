import std.stdio : writeln, stderr;

import token;
import parser;
import ir;
import regalloc;
import codegen;
import util;

int main(string[] args)
{
    string input;
    bool dump_ir1 = false;
    bool dump_ir2 = false;

    if (args.length == 3 && args[1] == "-dump-ir1")
    {
        dump_ir1 = true;
        input = args[2];
    }
    else if (args.length == 3 && args[1] == "-dump-ir2")
    {
        dump_ir2 = true;
        input = args[2];
    }
    else if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc [-dump-ir] <code>");

        return 1;
    }
    else
    {
        input = args[1];
    }

    try
    {
        Token[] tokens = tokenize(input);

        // stderr.writeln(tokens);

        Node[] nodes = parse(tokens);

        Function[] fns = genIR(nodes);

        if (dump_ir1)
        {
            foreach (fn; fns)
            {
                stderr.writefln("%s():", fn.name);
                foreach (i, ir; fn.irs)
                    stderr.writefln("%3d:  %s", i, ir);
            }
        }

        allocRegisters(fns);

        if (dump_ir2)
        {
            foreach (fn; fns)
            {
                stderr.writefln("%s():", fn.name);
                foreach (i, ir; fn.irs)
                    stderr.writefln("%3d:  %s", i, ir);
            }
        }

        generate_x86(fns);
        return 0;
    }
    catch (ExitException e)
    {
        return e.rc;
    }
}
