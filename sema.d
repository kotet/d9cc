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
Node* walk(Node* node, bool decay, ref Variable[string] vars, ref size_t stacksize)
{
    with (NodeType) switch (node.op)
    {
    case NUM:
        return node;
    case IDENTIFIER:
        if (!(node.name in vars))
        {
            error("Undefined variable: %s", node.name);
        }
        node.op = VARIABLE_REFERENCE;
        node.offset = vars[node.name].offset;

        if (decay && vars[node.name].type.type == TypeName.ARRAY)
        {
            return () {
                Node* n = new Node();
                n.op = NodeType.ADDRESS;
                Type* t = new Type(TypeName.POINTER);
                t.pointer_of = vars[node.name].type.array_of;
                n.type = t;
                n.expr = node;
                return n;
            }();
        }
        else
        {
            node.type = vars[node.name].type;
            return node;
        }
    case VARIABLE_DEFINITION:
        stacksize += size_of(*node.type);
        node.offset = stacksize;

        Variable var;
        var.type = node.type;
        var.offset = stacksize;
        vars[node.name] = var;

        if (node.initalize)
        {
            node.initalize = walk(node.initalize, true, vars, stacksize);
        }
        return node;
    case IF:
        node.cond = walk(node.cond, true, vars, stacksize);
        node.then = walk(node.then, true, vars, stacksize);
        if (node.els)
        {
            node.els = walk(node.els, true, vars, stacksize);
        }
        return node;
    case FOR:
        node.initalize = walk(node.initalize, true, vars, stacksize);
        node.cond = walk(node.cond, true, vars, stacksize);
        node.inc = walk(node.inc, true, vars, stacksize);
        node.bdy = walk(node.bdy, true, vars, stacksize);
        return node;
    case ADD:
    case SUB:
        node.lhs = walk(node.lhs, true, vars, stacksize);
        node.rhs = walk(node.rhs, true, vars, stacksize);
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
        return node;
    case MUL:
    case DIV:
    case LESS_THAN:
    case LOGICAL_OR:
    case LOGICAL_AND:
        node.lhs = walk(node.lhs, true, vars, stacksize);
        node.rhs = walk(node.rhs, true, vars, stacksize);
        node.type = node.lhs.type;
        return node;
    case ASSIGN:
        node.lhs = walk(node.lhs, false, vars, stacksize);
        if (node.lhs.op != NodeType.DEREFERENCE && node.lhs.op != NodeType.VARIABLE_REFERENCE)
        {
            error("Not an lvalue: %s (%s)", node.op, node.name);
        }
        node.rhs = walk(node.rhs, true, vars, stacksize);
        node.type = node.lhs.type;
        return node;
    case DEREFERENCE:
        node.expr = walk(node.expr, true, vars, stacksize);
        if (node.expr.type.type != TypeName.POINTER)
        {
            error("Operand must be a pointer");
        }
        node.type = node.expr.type.pointer_of;
        return node;
    case RETURN:
        node.expr = walk(node.expr, true, vars, stacksize);
        node.type = new Type(TypeName.INT);
        return node;
    case CALL:
        foreach (i, ref arg; node.args)
            node.args[i] = *walk(&arg, true, vars, stacksize);
        node.type = new Type(TypeName.INT);
        return node;
    case FUNCTION:
        foreach (i, ref arg; node.args)
            node.args[i] = *walk(&arg, true, vars, stacksize);
        walk(node.bdy, true, vars, stacksize);
        return node;
    case COMPOUND_STATEMENT:
        foreach (i, ref stmt; node.statements)
            node.statements[i] = *walk(&stmt, true, vars, stacksize);
        return node;
    case EXPRESSION_STATEMENT:
        node.expr = walk(node.expr, true, vars, stacksize);
        return node;
    case ADDRESS:
        node.expr = walk(node.expr, true, vars, stacksize);
        node.type = node.expr.type.pointer_of;
        return node;
    case SIZEOF:
        return () {
            Node* expr = walk(node.expr, false, vars, stacksize);
            Node* n = new Node();
            n.op = NodeType.NUM;
            n.type = new Type(TypeName.INT);
            n.val = cast(int) size_of(*expr.type);
            return n;
        }();
    default:
        error("Unknown node type: %s", node.op);
        assert(0);
    }
}
