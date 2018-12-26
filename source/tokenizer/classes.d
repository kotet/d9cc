module tokenizer.classes;

import std.format : format;

abstract class Token
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

class NUM : Token
{
    int value;
    this(int _value, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.value = _value;
    }

    override string toString()
    {
        return format!"NUM(%d)"(value);
    }
}

class EOF : Token
{
    this(size_t _line, size_t _column)
    {
        super(_line, _column);
    }

    override string toString()
    {
        return "EOF";
    }
}

class OP(char c) : Token
{
    this(size_t _line, size_t _column)
    {
        super(_line, _column);
    }

    override string toString()
    {
        return "OP(" ~ c ~ ")";
    }
}
