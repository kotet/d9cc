import std.stdio : writeln, stderr;
import std.file : readText;

import token;
import parser;
import sema;
import gen_ir;
import regalloc;
import gen_x86;
import util;
import irdump;

int main(string[] args)
{
    string filename;
    bool dump_ir1 = false;
    bool dump_ir2 = false;

    if (args.length == 3 && args[1] == "-dump-ir1")
    {
        dump_ir1 = true;
        filename = args[2];
    }
    else if (args.length == 3 && args[1] == "-dump-ir2")
    {
        dump_ir2 = true;
        filename = args[2];
    }
    else if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc [-dump-ir] <file>");

        return 1;
    }
    else
    {
        filename = args[1];
    }

    string input = readText(filename);

    try
    {
        Token[] tokens = tokenize(input);

        // stderr.writeln(tokens);

        Node[] nodes = parse(tokens);

        Variable[] globals = semantics(nodes);

        Function[] fns = genIR(nodes);

        if (dump_ir1)
        {
            foreach (fn; fns)
            {
                stderr.writefln("%s():", fn.name);
                foreach (i, ir; fn.irs)
                    stderr.writefln("%3d:  %s", i, ir.toString());
            }
        }

        allocRegisters(fns);

        if (dump_ir2)
        {
            foreach (fn; fns)
            {
                stderr.writefln("%s():", fn.name);
                foreach (i, ir; fn.irs)
                    stderr.writefln("%3d:  %s", i, ir.toString());
            }
        }

        generate_x86(globals, fns);
        return 0;
    }
    catch (ExitException e)
    {
        debug
        {
            throw e;
        }
        else
        {
            return e.rc;
        }
    }
}
