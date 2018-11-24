module astdump;

import std.stdio;
import std.range : iota;
import std.algorithm : map;
import std.array : join;
import std.conv : text;
import std.string : fromStringz;

import parser;
import util;

void dumpAST(Node[] nodes)
{
    stderr.writeln("digraph G {\ngraph [layout=dot,rankdir=LR]\nnode [shape=record];");
    id = 0;
    foreach (fn; nodes)
        dump(&fn);
    stderr.writeln("}");
}

private:

size_t id;

size_t dump(Node* node)
{
    if (node == null)
    {
        size_t id_null = id++;
        stderr.writefln("n%d [label=\"NULL\",shape=circle,color=red]", id_null);
        return id_null;
    }

    string type = genType(node.type);
    string typestr = (type != "") ? " : " ~ type : "";

    if (node.op == NodeType.FUNCTION)
    {
        size_t id_func = id++;
        stderr.writefln("n%d [label=\"<op>FUNCTION|name = %s|<type>type = %s|<args>args|<body>body\"]",
                id_func, node.name, genType(node.type));
        size_t id_args = dumpArgs(node.args);
        stderr.writefln("n%d:args -> n%d", id_func, id_args);
        size_t id_body = dump(node.bdy);
        stderr.writefln("n%d:body -> n%d", id_func, id_body);
        return id_func;
    }

    if (node.op == NodeType.VARIABLE_DEFINITION)
    {
        size_t id_var = id++;
        if (node.initalize == null)
        {
            stderr.writefln("n%d [label=\"<op>VARIABLE_DEFINITION|name = %s%s|<type>type = %s\"]",
                    id_var, node.name, (node.is_extern) ? "|extern" : "", genType(node.type));
        }
        else
        {
            size_t id_init = dump(node.initalize);
            stderr.writefln("n%d [label=\"<op>VARIABLE_DEFINITION|name = %s%s|<type>type = %s|<init>init\"]",
                    id_var, node.name, (node.is_extern) ? "|extern" : "", genType(node.type));
            stderr.writefln("n%d:init -> n%d", id_var, id_init);
        }
        return id_var;
    }

    if (node.op == NodeType.COMPOUND_STATEMENT)
    {
        size_t id_cpstmt = id++;

        if (node.statements.length == 0)
        {
            stderr.writefln("n%d [label=\"COMPOUND_STATEMENT|∅\"]", id_cpstmt);
            return id_cpstmt;
        }

        stderr.writefln("n%d [label=\"%s\"]", id_cpstmt,
                "COMPOUND_STATEMENT|" ~ iota(node.statements.length)
                .map!(n => "<" ~ n.text ~ ">" ~ n.text).join("|"));
        foreach (i, stmt; node.statements)
        {
            size_t id_stmt = dump(&stmt);
            stderr.writefln("n%d:%d -> n%d", id_cpstmt, i, id_stmt);
        }
        return id_cpstmt;
    }

    if (node.op == NodeType.NULL)
    {
        size_t id_null = id++;
        stderr.writefln("n%d [label=\"∅\"]");
        return id_null;
    }

    if (node.op == NodeType.IF)
    {
        size_t id_if = id++;
        size_t id_cond = dump(node.cond);
        size_t id_then = dump(node.then);
        if (node.els == null)
        {
            stderr.writefln("n%d [label=\"IF|<cond>cond|<then>then\"]", id_if);
            stderr.writefln("n%d:cond -> n%d", id_if, id_cond);
            stderr.writefln("n%d:then -> n%d", id_if, id_then);
        }
        else
        {
            size_t id_else = dump(node.els);
            stderr.writefln("n%d [label=\"IF|<cond>cond|<then>then|<else>else\"]", id_if);
            stderr.writefln("n%d:cond -> n%d", id_if, id_cond);
            stderr.writefln("n%d:then -> n%d", id_if, id_then);
            stderr.writefln("n%d:else -> n%d", id_if, id_else);
        }
        return id_if;
    }

    if (node.op == NodeType.FOR)
    {
        size_t id_for = id++;
        size_t id_init = dump(node.initalize);
        size_t id_cond = dump(node.cond);
        size_t id_inc = dump(node.inc);
        size_t id_body = dump(node.bdy);
        stderr.writefln("n%d [label=\"FOR|<init>init|<cond>cond|<inc>inc|<body>body\"]", id_for);
        stderr.writefln("n%d:init -> n%d", id_for, id_init);
        stderr.writefln("n%d:cond -> n%d", id_for, id_cond);
        stderr.writefln("n%d:inc -> n%d", id_for, id_inc);
        stderr.writefln("n%d:body -> n%d", id_for, id_body);
        return id_for;
    }

    if (node.op == NodeType.DO_WHILE)
    {
        size_t id_dowhile = id++;
        size_t id_body = dump(node.bdy);
        size_t id_cond = dump(node.cond);
        stderr.writefln("n%d [label=\"DO_WHILE|<body>body|<cond>cond\"]", id_dowhile);
        stderr.writefln("n%d:body -> n%d", id_dowhile, id_body);
        stderr.writefln("n%d:cond -> n%d", id_dowhile, id_cond);
        return id_dowhile;
    }

    if (node.op == NodeType.RETURN)
    {
        size_t id_return = id++;
        size_t id_expr = dump(node.expr);
        stderr.writefln("n%d [label=\"RETURN|<expr>expr\"]", id_return);
        stderr.writefln("n%d:expr -> n%d", id_return, id_expr);
        return id_return;
    }

    if (node.op == NodeType.EXPRESSION_STATEMENT)
    {
        size_t id_expr_stmt = id++;
        size_t id_expr = dump(node.expr);
        stderr.writefln("n%d [label=\"EXPRESSION_STATEMENT|<expr>expr\"]", id_expr_stmt);
        stderr.writefln("n%d:expr -> n%d", id_expr_stmt, id_expr);
        return id_expr_stmt;
    }

    if (node.op == NodeType.STATEMENT_EXPRESSION)
    {
        size_t id_expr = id++;
        size_t id_body = dump(node.expr);

        stderr.writefln("n%d [label=\"STATEMENT_EXPRESSION%s|<body>body\"]", typestr, id_expr);
        stderr.writefln("n%d:expr -> n%d", id_expr, id_body);
        return id_expr;
    }

    if (node.op == NodeType.ASSIGN)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);

        stderr.writefln("n%d [label=\"ASSIGN%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.LOGICAL_OR)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"\\|\\|%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.LOGICAL_AND)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"&&%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.EQUAL)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"==%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.NOT_EQUAL)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"!=%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.LESS_THAN)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"\\<%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.ADD)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"\\+%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.SUB)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"\\-%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.MUL)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"\\*%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.DIV)
    {
        size_t id_binop = id++;
        size_t id_lhs = dump(node.lhs);
        size_t id_rhs = dump(node.rhs);
        stderr.writefln("n%d [label=\"\\/%s|<lhs>lhs|<rhs>rhs\"]", id_binop, typestr);
        stderr.writefln("n%d:lhs -> n%d", id_binop, id_lhs);
        stderr.writefln("n%d:rhs -> n%d", id_binop, id_rhs);
        return id_binop;
    }

    if (node.op == NodeType.DEREFERENCE)
    {
        size_t id_unary = id++;
        size_t id_expr = dump(node.expr);
        stderr.writefln("n%d [label=\"\\*%s|<expr>expr\"]", id_unary, typestr);
        stderr.writefln("n%d:expr -> n%d", id_unary, id_expr);
        return id_unary;
    }

    if (node.op == NodeType.ADDRESS)
    {
        size_t id_unary = id++;
        size_t id_expr = dump(node.expr);
        stderr.writefln("n%d [label=\"&%s|<expr>expr\"]", id_unary, typestr);
        stderr.writefln("n%d:expr -> n%d", id_unary, id_expr);
        return id_unary;
    }

    if (node.op == NodeType.SIZEOF)
    {
        size_t id_unary = id++;
        size_t id_expr = dump(node.expr);
        stderr.writefln("n%d [label=\"sizeof|<expr>expr\"]", id_unary);
        stderr.writefln("n%d:expr -> n%d", id_unary, id_expr);
        return id_unary;
    }

    if (node.op == NodeType.ALIGNOF)
    {
        size_t id_unary = id++;
        size_t id_expr = dump(node.expr);
        stderr.writefln("n%d [label=\"_Alignof|<expr>expr\"]", id_unary);
        stderr.writefln("n%d:expr -> n%d", id_unary, id_expr);
        return id_unary;
    }

    if (node.op == NodeType.IDENTIFIER)
    {
        size_t id_ident = id++;
        stderr.writefln("n%d [label=\"IDENTIFIER|name = %s\"]", id_ident, node.name);
        return id_ident;
    }

    if (node.op == NodeType.CALL)
    {
        size_t id_ident = id++;
        if (node.args == null)
        {
            stderr.writefln("n%d [label=\"CALL%s|name = %s\"]", id_ident, typestr, node.name);
        }
        else
        {
            stderr.writefln("n%d [label=\"CALL%s|name = %s|<args>args\"]",
                    id_ident, typestr, node.name);
            size_t id_args = dumpArgs(node.args);
            stderr.writefln("n%d:args -> n%d", id_ident, id_args);
        }
        return id_ident;
    }

    if (node.op == NodeType.LOCAL_VARIABLE)
    {
        size_t id_var = id++;
        stderr.writefln("n%d [label=\"LOCAL_VARIABLE%s|offset = %d\"]", id_var,
                typestr, node.offset);
        return id_var;
    }

    if (node.op == NodeType.GLOBAL_VARIABLE)
    {
        size_t id_var = id++;
        stderr.writefln("n%d [label=\"GLOBAL_VARIABLE%s|%s\"]", id_var, typestr, node.name);
        return id_var;
    }

    if (node.op == NodeType.STRING)
    {
        size_t id_str = id++;
        stderr.writefln("n%d [label=\"STRING%s\"]", id_str, typestr);
        return id_str;
    }

    if (node.op == NodeType.NUM)
    {
        size_t id_num = id++;
        stderr.writefln("n%d [label=\"NUM|val = %d\"]", id_num, node.val);
        return id_num;
    }

    size_t id_other = id++;
    stderr.writefln("n%d [label=\"%s%s\"]", id_other, node.op, typestr);

    return id_other;
}

size_t dumpArgs(Node[] args)
{
    size_t id_args = id++;

    if (args.length == 0)
    {
        stderr.writefln("n%d [label=\"∅\"]", id_args);
        return id_args;
    }

    stderr.writefln("n%d [label=\"%s\"]", id_args, iota(args.length)
            .map!(n => "<" ~ n.text ~ ">" ~ n.text).join("|"));

    foreach (i, arg; args)
    {
        size_t id_arg = dump(&arg);
        stderr.writefln("n%d:%d -> n%d", id_args, i, id_arg);
    }
    return id_args;
}

string genType(Type* t)
{
    if (t == null)
    {
        return "";
    }
    with (TypeName) switch (t.type)
    {
    case CHAR:
        return "char";
    case INT:
        return "int";
    case POINTER:
        return "*" ~ genType(t.pointer_to);
    default:
        assert(t.type == TypeName.ARRAY);
        return genType(t.array_of) ~ "[" ~ t.array_length.text ~ "]";
    }
}
