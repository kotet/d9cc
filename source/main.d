import std.stdio;
import std.getopt;

import tokenizer;
import parser;
import ir;
import regalloc;
import codegen;

int main(string[] args)
{
	string code;
	auto helpinfo = getopt(args, "c|compile", "Compile the code given from command line.", &code);
	if (helpinfo.helpWanted)
	{
		defaultGetoptPrinter("d9cc: A Small C Compiler Written in D", helpinfo.options);
	}

	Token[] tokens = new Tokenizer(code).tokenize();

	Node node = new Parser(tokens).parse();

	IR[] irs = new IRGenerator(node).generate();

	IR[] allocated = new RegisterAllocator(irs).allocate();

	new CodeGenerator(allocated).generate();

	return 0;
}
