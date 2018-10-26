module sema;

import std.stdio : stderr;

import parser;
import util;

public:

void semantics(ref Node[] nodes)
{
    foreach (node; nodes)
    {
        long[string] vars;
        size_t stacksize;

        walk(&node, vars, stacksize);
        node.stacksize = stacksize;
    }
}

private:

void walk(Node* node, ref long[string] vars, ref size_t stacksize)
{
    with (NodeType) switch (node.type)
    {
    case NUM:
        return;
    case IDENTIFIER:
        if (!(node.name in vars))
        {
            error("Undefined variable: %s", node.name);
        }
        node.type = VARIABLE_REFERENCE;
        node.offset = vars[node.name];
        return;
    case VARIABLE_DEFINITION:
        stacksize += 8;
        vars[node.name] = stacksize;
        node.offset = stacksize;
        if (node.initalize)
        {
            walk(node.initalize, vars, stacksize);
        }
        return;
    case IF:
        walk(node.cond, vars, stacksize);
        walk(node.then, vars, stacksize);
        if (node.els)
        {
            walk(node.els, vars, stacksize);
        }
        return;
    case FOR:
        walk(node.initalize, vars, stacksize);
        walk(node.cond, vars, stacksize);
        walk(node.inc, vars, stacksize);
        walk(node.bdy, vars, stacksize);
        return;
    case ADD:
    case SUB:
    case MUL:
    case DIV:
    case ASSIGN:
    case LESS_THAN:
    case LOGICAL_OR:
    case LOGICAL_AND:
        walk(node.lhs, vars, stacksize);
        walk(node.rhs, vars, stacksize);
        return;
    case RETURN:
        walk(node.expr, vars, stacksize);
        return;
    case CALL:
        foreach (ref arg; node.args)
            walk(&arg, vars, stacksize);
        return;
    case FUNCTION:
        foreach (ref arg; node.args)
            walk(&arg, vars, stacksize);
        walk(node.bdy, vars, stacksize);
        return;
    case COMPOUND_STATEMENT:
        foreach (ref stmt; node.statements)
            walk(&stmt, vars, stacksize);
        return;
    case EXPRESSION_STATEMENT:
        walk(node.expr, vars, stacksize);
        return;
    default:
        error("Unknown node type: %s", node.type);
        assert(0);
    }
}
