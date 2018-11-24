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
import astdump;

int main(string[] args)
{
    string filename;
    bool dump_ir1 = false;
    bool dump_ir2 = false;
    bool dump_ast1 = false;
    bool dump_ast2 = false;
    static immutable usage = "Usage: d9cc [-dump-ir1] [-dump-ir2] [-dump-ast1] [-dump-ast2] <file>";

    if (args.length == 3)
    {
        filename = args[2];
        switch (args[1])
        {
        case "-dump-ir1":
            dump_ir1 = true;
            break;
        case "-dump-ir2":
            dump_ir2 = true;
            break;
        case "-dump-ast1":
            dump_ast1 = true;
            break;
        case "-dump-ast2":
            dump_ast2 = true;
            break;
        default:
            stderr.writeln(usage);
            return 1;
        }
    }
    else if (args.length != 2)
    {
        stderr.writeln(usage);
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

        if (dump_ast1)
        {
            dumpAST(nodes);
        }

        Variable[] globals = semantics(nodes);

        if (dump_ast2)
        {
            dumpAST(nodes);
        }

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
