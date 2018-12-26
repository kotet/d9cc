module ir.classes;

import std.format : format;

abstract class IR
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

class IMM : IR
{
    size_t reg;
    int value;
    this(size_t _reg, int _value, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.reg = _reg;
        this.value = _value;
    }

    override string toString()
    {
        return format!"IMM\tr%d\t%d"(reg, value);
    }

}

class BINOP(char c) : IR
{
    size_t dst;
    size_t src;
    this(size_t _dst, size_t _src, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.dst = _dst;
        this.src = _src;
    }

    override string toString()
    {
        return format!"r%d\t%s=\tr%d"(dst, c, src);
    }
}

class KILL : IR
{
    size_t reg;
    this(size_t _reg, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.reg = _reg;
    }

    override string toString()
    {
        return format!"KILL\tr%d"(reg);
    }
}

class RET : IR
{
    size_t reg;
    this(size_t _reg, size_t _line, size_t _column)
    {
        super(_line, _column);
        this.reg = _reg;
    }

    override string toString()
    {
        return format!"RET\tr%d"(reg);
    }
}

class NOP : IR
{
    this(size_t _line, size_t _column)
    {
        super(_line, _column);
    }

    override string toString()
    {
        return "NOP";
    }
}
