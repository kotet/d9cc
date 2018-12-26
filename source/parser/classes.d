module parser.classes;

import std.format : format;

abstract class Node
{
    size_t line;
    size_t column;
    abstract override string toString();
    this(size_t _line, size_t _column)
    {
        this.line = _line;
        this.column = _column;
    }
}

class NUM : Node
{
    int value;
    this(int _value, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.value = _value;
    }

    override string toString()
    {
        return format!"%d"(value);
    }
}

class BINOP(char c) : Node
{
    Node lhs;
    Node rhs;
    this(Node _lhs, Node _rhs, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.lhs = _lhs;
        this.rhs = _rhs;
    }

    override string toString()
    {
        return format!("(%s) " ~ c ~ " (%s)")(lhs, rhs);
    }
}
