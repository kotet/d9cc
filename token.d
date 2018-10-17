module token;

import std.stdio : stderr;
import std.uni : isSpace;
import std.ascii : isDigit, isAlpha;
import std.algorithm : among;

import util;

public:

enum TokenType
{
    NUM,
    IDENTIFIER,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    RETURN,
    SEMICOLONE = ';',
    ASSIGN = '=',
    EOF
}

struct Token
{
    TokenType type;
    int val; // 数値リテラルデータ
    string name; // 変数名
    string input; // エラー報告用のトークン文字列
}

Token[] tokenize(string s)
{
    Token[] result;
    size_t i;
    TokenType[string] keywords;
    keywords["return"] = TokenType.RETURN;

    while (i < s.length) // Dの文字列はNull終端ではない
    {
        if (s[i].isSpace())
        {
            i++;
            continue;
        }

        if (s[i].among!('+', '-', '*', '/', ';', '='))
        {
            Token t;
            t.type = cast(TokenType) s[i];
            t.input = s[i .. i + 1];

            result ~= t;
            i++;
            continue;
        }

        if (s[i].isDigit())
        {
            Token t;
            t.type = TokenType.NUM;
            size_t _i = i;
            t.val = nextInt(s, i);
            t.input = s[_i .. i];

            result ~= t;
            continue;
        }

        if (s[i].isAlpha || s[i] == '_')
        {
            size_t len = 1;
            while (s[i + len].isAlpha || s[i + len].isDigit || s[i + len] == '_')
            {
                len++;
            }
            string name = s[i .. i + len];

            if (name in keywords)
            {
                result ~= () {
                    Token t;
                    t.type = keywords[name];
                    t.input = name;
                    return t;
                }();
                i += len;
                continue;
            }
            result ~= () {
                Token t;
                t.type = TokenType.IDENTIFIER;
                t.name = name;
                t.input = name;
                return t;
            }();
            i += len;
            continue;
        }

        error("Cannot tokenize: %s", s[i]);
    }

    result ~= () { Token t; t.type = TokenType.EOF; return t; }();

    return result;
}
