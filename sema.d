module sema;

import std.stdio : stderr;
import std.algorithm : swap;

import parser;
import util;

public:

long size_of(Type t)
{
    if (t.type == TypeName.INT)
    {
        return 4;
    }
    if (t.type == TypeName.ARRAY)
    {
        return size_of(*t.array_of) * t.array_length;
    }
    assert(t.type == TypeName.POINTER);
    return 8;
}

void semantics(ref Node[] nodes)
{
    foreach (node; nodes)
    {
        Variable[string] vars;
        size_t stacksize;

        walk(&node, true, vars, stacksize);
        node.stacksize = stacksize;
    }
}

private:

struct Variable
{
    Type* type;
    size_t offset;
}

// decay == trueならIDENTIFIERノードをADDRESSノードに書き換える。
// decay == falseになるのは arr = {1,2,3}みたいなときだと思う
void walk(Node* node, bool decay, ref Variable[string] vars, ref size_t stacksize)
{
    with (NodeType) switch (node.op)
    {
    case NUM:
        return;
    case IDENTIFIER:
        if (!(node.name in vars))
        {
            error("Undefined variable: %s", node.name);
        }
        node.op = VARIABLE_REFERENCE;
        node.offset = vars[node.name].offset;

        if (decay && vars[node.name].type.type == TypeName.ARRAY)
        {
            *node = () {
                Node* n = new Node();
                Node* _node = new Node();
                *_node = *node;

                n.op = NodeType.ADDRESS;
                Type* t = new Type(TypeName.POINTER);
                t.pointer_of = vars[node.name].type.array_of;
                n.type = t;
                n.expr = _node;
                return *n;
            }();
        }
        else
        {
            node.type = vars[node.name].type;
        }

        return;
    case VARIABLE_DEFINITION:
        stacksize += size_of(*node.type);
        node.offset = stacksize;

        Variable var;
        var.type = node.type;
        var.offset = stacksize;
        vars[node.name] = var;

        if (node.initalize)
        {
            walk(node.initalize, true, vars, stacksize);
        }
        return;
    case IF:
        walk(node.cond, true, vars, stacksize);
        walk(node.then, true, vars, stacksize);
        if (node.els)
        {
            walk(node.els, true, vars, stacksize);
        }
        return;
    case FOR:
        walk(node.initalize, true, vars, stacksize);
        walk(node.cond, true, vars, stacksize);
        walk(node.inc, true, vars, stacksize);
        walk(node.bdy, true, vars, stacksize);
        return;
    case ADD:
    case SUB:
        walk(node.lhs, true, vars, stacksize);
        walk(node.rhs, true, vars, stacksize);
        if (node.rhs.type.type == TypeName.POINTER)
        {
            // a - bがb - aになっちゃうけどいいんだろうか……
            swap(node.lhs, node.rhs);
        }
        if (node.rhs.type.type == TypeName.POINTER)
        {
            error("Pointer %s pointer is not defined", cast(char) node.op);
        }
        node.type = node.lhs.type;
        return;
    case MUL:
    case DIV:
    case LESS_THAN:
    case LOGICAL_OR:
    case LOGICAL_AND:
        walk(node.lhs, true, vars, stacksize);
        walk(node.rhs, true, vars, stacksize);
        node.type = node.lhs.type;
        return;
    case ASSIGN:
        walk(node.lhs, false, vars, stacksize);
        walk(node.rhs, true, vars, stacksize);
        node.type = node.lhs.type;
        return;
    case DEREFERENCE:
        walk(node.expr, true, vars, stacksize);
        if (node.expr.type.type != TypeName.POINTER)
        {
            error("Operand must be a pointer");
        }
        node.type = node.expr.type.pointer_of;
        return;
    case RETURN:
        walk(node.expr, true, vars, stacksize);
        node.type = new Type(TypeName.INT);
        return;
    case CALL:
        foreach (ref arg; node.args)
            walk(&arg, true, vars, stacksize);
        node.type = new Type(TypeName.INT);
        return;
    case FUNCTION:
        foreach (ref arg; node.args)
            walk(&arg, true, vars, stacksize);
        walk(node.bdy, true, vars, stacksize);
        return;
    case COMPOUND_STATEMENT:
        foreach (ref stmt; node.statements)
            walk(&stmt, true, vars, stacksize);
        return;
    case EXPRESSION_STATEMENT:
        walk(node.expr, true, vars, stacksize);
        return;
    default:
        error("Unknown node type: %s", node.op);
        assert(0);
    }
}
