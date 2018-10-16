module token;

import std.stdio : stderr;
import std.uni : isSpace;
import std.ascii : isDigit;
import std.algorithm : among;

import util;

public:

enum TokenType
{
    NUM,
    ADD = '+',
    SUB = '-',
    MUL = '*',
    DIV = '/',
    EOF
}

struct Token
{
    TokenType type;
    int val; // 数値リテラルデータ
    string input; // エラー報告用のトークン文字列
}

Token[] tokenize(string s)
{
    Token[] result;
    size_t i;

    while (i < s.length) // Dの文字列はNull終端ではない
    {
        if (s[i].isSpace())
        {
            i++;
            continue;
        }

        if (s[i].among!('+', '-', '*'))
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

        stderr.writefln("Cannot tokenize: %s", s[i]);
        throw new ExitException(-1);
    }

    result ~= () { Token t; t.type = TokenType.EOF; return t; }();

    return result;
}
