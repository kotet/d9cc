module sema;

import std.stdio : stderr;
import std.algorithm : swap;
import std.format : format;

import parser;
import util;

public:

struct Variable
{
    Type* type;
    bool is_local;

    size_t offset; // ローカル変数
    string name; // グローバル変数
    string data; // 文字列
}

long size_of(Type t)
{
    with (TypeName) switch (t.type)
    {
    case CHAR:
        return 1;
    case INT:
        return 4;
    case ARRAY:
        return size_of(*t.array_of) * t.array_length;
    default:
        assert(t.type == TypeName.POINTER);
        return 8;
    }
}

void semantics(ref Node[] nodes)
{
    size_t str_label; // アセンブリ内での通し番号
    foreach (ref node; nodes)
    {
        Enviroment* env = new Enviroment();
        size_t stacksize;
        Variable[] globals; // 文字列ノードが入る。.dataセクションは関数ごとに生成する

        walk(&node, true, str_label, globals, env, stacksize);
        node.stacksize = stacksize;
        node.globals = globals;
    }
}

private:

struct Enviroment
{
    Variable[string] vars;
    Enviroment* next; // 外側のスコープ
}

Enviroment* newEnv(Enviroment* env)
{
    Enviroment* e = new Enviroment();
    e.next = env;
    return e;
}

Variable* find(Enviroment* env, string name)
{
    if (name in env.vars)
    {
        return name in env.vars;
    }
    else if (env.next)
    {
        return find(env.next, name);
    }
    else
    {
        return null;
    }
}

// decay == trueならIDENTIFIERノードをADDRESSノードに書き換える。
// decay == falseになるのは arr = {1,2,3}みたいなときだと思う
Node* walk(Node* node, bool decay, ref size_t str_label, ref Variable[] globals,
        Enviroment* env, ref size_t stacksize)
{
    with (NodeType) switch (node.op)
    {
    case NUM:
        return node;
    case IDENTIFIER:
        Variable* var = find(env, node.name);
        if (!var)
        {
            error("Undefined variable: %s", node.name);
        }
        node.op = LOCAL_VARIABLE;
        node.offset = var.offset;

        if (decay && var.type.type == TypeName.ARRAY)
        {
            return () {
                Node* n = new Node();
                n.op = NodeType.ADDRESS;
                Type* t = new Type(TypeName.POINTER);
                t.pointer_of = var.type.array_of;
                n.type = t;
                n.expr = node;
                return n;
            }();
        }
        else
        {
            node.type = var.type;
            return node;
        }
    case VARIABLE_DEFINITION:
        stacksize += size_of(*node.type);
        node.offset = stacksize;

        Variable var;
        var.type = node.type;
        var.offset = stacksize;
        var.is_local = true;
        env.vars[node.name] = var;

        if (node.initalize)
        {
            node.initalize = walk(node.initalize, true, str_label, globals, env, stacksize);
        }
        return node;
    case IF:
        node.cond = walk(node.cond, true, str_label, globals, env, stacksize);
        node.then = walk(node.then, true, str_label, globals, env, stacksize);
        if (node.els)
        {
            node.els = walk(node.els, true, str_label, globals, env, stacksize);
        }
        return node;
    case FOR:
        node.initalize = walk(node.initalize, true, str_label, globals, env, stacksize);
        node.cond = walk(node.cond, true, str_label, globals, env, stacksize);
        node.inc = walk(node.inc, true, str_label, globals, env, stacksize);
        node.bdy = walk(node.bdy, true, str_label, globals, env, stacksize);
        return node;
    case ADD:
    case SUB:
        node.lhs = walk(node.lhs, true, str_label, globals, env, stacksize);
        node.rhs = walk(node.rhs, true, str_label, globals, env, stacksize);
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
        node.lhs = walk(node.lhs, true, str_label, globals, env, stacksize);
        node.rhs = walk(node.rhs, true, str_label, globals, env, stacksize);
        node.type = node.lhs.type;
        return node;
    case ASSIGN:
        node.lhs = walk(node.lhs, false, str_label, globals, env, stacksize);
        if (node.lhs.op != NodeType.DEREFERENCE && node.lhs.op != NodeType.LOCAL_VARIABLE)
        {
            error("Not an lvalue: %s (%s)", node.op, node.name);
        }
        node.rhs = walk(node.rhs, true, str_label, globals, env, stacksize);
        node.type = node.lhs.type;
        return node;
    case DEREFERENCE:
        node.expr = walk(node.expr, true, str_label, globals, env, stacksize);
        if (node.expr.type.type != TypeName.POINTER)
        {
            error("Operand must be a pointer");
        }
        node.type = node.expr.type.pointer_of;
        return node;
    case RETURN:
        node.expr = walk(node.expr, true, str_label, globals, env, stacksize);
        node.type = new Type(TypeName.INT);
        return node;
    case CALL:
        foreach (i, ref arg; node.args)
            node.args[i] = *walk(&arg, true, str_label, globals, env, stacksize);
        node.type = new Type(TypeName.INT);
        return node;
    case FUNCTION:
        foreach (i, ref arg; node.args)
            node.args[i] = *walk(&arg, true, str_label, globals, env, stacksize);
        walk(node.bdy, true, str_label, globals, env, stacksize);
        return node;
    case COMPOUND_STATEMENT:
        Enviroment* new_env = newEnv(env);
        foreach (i, ref stmt; node.statements)
            node.statements[i] = *walk(&stmt, true, str_label, globals, new_env, stacksize);
        return node;
    case EXPRESSION_STATEMENT:
        node.expr = walk(node.expr, true, str_label, globals, env, stacksize);
        return node;
    case ADDRESS:
        node.expr = walk(node.expr, true, str_label, globals, env, stacksize);
        node.type = node.expr.type.pointer_of;
        return node;
    case SIZEOF:
        return () {
            Node* expr = walk(node.expr, false, str_label, globals, env, stacksize);
            Node* n = new Node();
            n.op = NodeType.NUM;
            n.type = new Type(TypeName.INT);
            n.val = cast(int) size_of(*expr.type);
            return n;
        }();
    case STRING:
        Variable var;
        string name = format(".L.str%d", str_label);
        str_label++;
        var.type = node.type;
        var.is_local = false;
        var.name = name;
        var.data = node.str;
        globals ~= var;

        Node* ret = new Node();
        ret.op = NodeType.GLOBAL_VARIABLE;
        ret.type = node.type;
        ret.name = name;
        return walk(ret, decay, str_label, globals, env, stacksize);
        break;
    case GLOBAL_VARIABLE:
        if (decay && node.type.type == TypeName.ARRAY)
        {
            return () {
                Node* n = new Node();
                n.op = NodeType.ADDRESS;
                Type* t = new Type(TypeName.POINTER);
                t.pointer_of = node.type.array_of;
                n.type = t;
                n.expr = node;
                return n;
            }();
        }
        else
        {
            return node;
        }
        break;
    default:
        error("Unknown node type: %s", node.op);
        assert(0);
    }
}
