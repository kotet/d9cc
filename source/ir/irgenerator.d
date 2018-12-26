module ir.irgenerator;

import ir.classes;
static import ND = parser.classes;

import std.stdio;

import util;

class IRGenerator
{
    ND.Node node;
    IR[] result;
    size_t regno;

    this(ND.Node _node)
    {
        this.node = _node;
    }

    IR[] generate()
    {
        size_t r = generateImpl(node);
        result ~= new RET(r, node.line, node.column);
        return result;
    }

    private size_t generateImpl(ND.Node node)
    {
        {
            auto c = cast(ND.NUM) node;
            if (c !is null)
            {
                size_t r = regno++;
                result ~= new IMM(r, c.value, c.line, c.column);
                return r;
            }
        }

        static foreach (op; "+-")
        {
            {
                auto c = cast(ND.BINOP!(op)) node;
                if (c !is null)
                {
                    size_t dst = this.generateImpl(c.lhs);
                    size_t src = this.generateImpl(c.rhs);

                    result ~= new BINOP!(op)(dst, src, c.line, c.column);
                    result ~= new KILL(src, c.line, c.column);
                    return dst;
                }
            }
        }

        error("unknown node: %s", node.line, node.column);
        assert(0);
    }
}
