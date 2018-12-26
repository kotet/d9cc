module tokenizer.tokenizer;

import tokenizer.classes;
import util : error;

import std.uni : isWhite;
import std.conv : to;

import std.stdio : writeln;

class Tokenizer
{
    private Token[] tks;
    private size_t i;
    private size_t lineno;
    private size_t linehead;
    private string s;

    this(string code)
    {
        this.s = code;
    }

    Token[] tokenize()
    {
        mainloop: while (i < s.length)
        {
            // 空白文字のスキップ
            if (s[i].isWhite)
            {
                i++;
                continue;
            }

            // 改行を数える
            if (s[i] == '\n')
            {
                i++;
                lineno++;
                linehead = i;
                continue;
            }

            // 1文字演算子
            static foreach (c; "+-")
            {
                if (s[i] == c)
                {
                    tks ~= new OP!c(lineno, i - linehead);
                    i++;
                    continue mainloop;
                }
            }

            // 数値
            if ('0' <= s[i] && s[i] <= '9')
            {
                tks ~= new NUM(nextInt(), lineno, i - linehead);
                continue;
            }

            error("cannot tokenize %s", lineno, i - linehead, s[i]);

        }

        tks ~= new EOF(lineno, i);
        return tks;
    }

    private int nextInt()
    {
        size_t _i = i;
        while (i < s.length && '0' <= s[i] && s[i] <= '9')
            i++;
        return s[_i .. i].to!int();
    }
}
