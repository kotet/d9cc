module parser.parser;

import std.stdio;

import parser.classes;
import util;

import tokenizer;
static import TK = tokenizer.classes;

class Parser
{
    Token[] tokens;
    size_t i;

    this(Token[] _tokens)
    {
        this.tokens = _tokens;
    }

    Node parse()
    {
        return expression();
    }

    Node expression()
    {
        Node lhs = number();
        while_loop: while (true)
        {
            static foreach (c; "+-")
            {
                {
                    auto casted = cast(TK.OP!c) tokens[i];
                    if (casted !is null)
                    {
                        i++;
                        Node rhs = number();
                        Node n = new BINOP!c(lhs, rhs, casted.line, casted.column);
                        lhs = n;
                        continue while_loop;
                    }
                }
            }
            break while_loop;
        }

        return lhs;
    }

    Node number()
    {
        auto c = cast(TK.NUM) tokens[i];
        if (c !is null)
        {
            Node n = new NUM(c.value, c.line, c.column);
            i++;
            return n;
        }
        else
        {
            error("stray token: %s", tokens[i].line, tokens[i].column, tokens[i]);
            assert(0);
        }
    }

}
