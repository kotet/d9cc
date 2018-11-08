module token;

import std.stdio : stderr;
import std.uni : isSpace;
import std.ascii : isDigit, isAlpha;
import std.algorithm : among;
import std.meta : aliasSeqOf;

import util;

public:

enum TokenType : int
{
    ADD = '+',
    SUB = '-',
    ASTERISK = '*',
    DIV = '/',
    SEMICOLONE = ';',
    ASSIGN = '=',
    LEFT_PARENTHESE = '(',
    RIGHT_PARENTHESE = ')',
    LEFT_BRACE = '{',
    RIGHT_BRACE = '}',
    LEFT_BRACKET = '[',
    RIGhT_BRACKET = ']',
    COMMA = ',',
    LESS_THAN = '<',
    GREATER_THAN = '>',
    AMPERSAND = '&',
    // 1文字トークン以外はcharの範囲外の数値にする
    // まあ9ccと違って1文字トークンにも名前を付けているので意味ないけど……
    NUM = 256,
    IDENTIFIER,
    INT,
    RETURN,
    IF,
    FOR,
    ELSE,
    EOF,
    LOGICAL_AND,
    LOGICAL_OR,
    SIZEOF,
    CHAR,
    STRING,
}

struct Token
{
    TokenType type;
    int val; // 数値リテラルデータ
    string str; // 文字列リテラルデータ
    string name; // 変数名
    string input; // エラー報告用のトークン文字列
}

Token[] tokenize(string s)
{
    Token[] result;
    size_t i;
    TokenType[string] symbols = [
        "int" : TokenType.INT, "return" : TokenType.RETURN, "if" : TokenType.IF,
        "for" : TokenType.FOR, "else" : TokenType.ELSE, "&&" : TokenType.LOGICAL_AND,
        "||" : TokenType.LOGICAL_OR, "sizeof" : TokenType.SIZEOF, "char" : TokenType.CHAR,
    ];

    while_loop: while (i < s.length) // Dの文字列はNull終端ではない
    {
        // 空白文字をスキップ
        if (s[i].isSpace())
        {
            i++;
            continue;
        }

        // 文字列
        if (s[i] == '"')
        {
            Token t;
            t.type = TokenType.STRING;
            i++;
            string str = readString(s, i);
            t.str = str;
            t.input = str;
            result ~= t;
            continue;
        }

        // 複数文字トークン
        foreach (symbol, type; symbols)
        {
            if ((i + symbol.length) < s.length && s[i .. (i + symbol.length)] == symbol)
            {
                Token t;
                t.type = type;
                t.input = s[i .. (i + symbol.length)];
                i += symbol.length;
                result ~= t;
                continue while_loop;
            }
        }

        // 1文字トークン
        if (s[i].among!(aliasSeqOf!"+-*/;=(),{}<>[]&"))
        {
            Token t;
            t.type = cast(TokenType) s[i];
            t.input = s[i .. i + 1];

            result ~= t;
            i++;
            continue;
        }

        // 数値
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

        // 識別子
        if (s[i].isAlpha || s[i] == '_')
        {
            size_t len = 1;
            while (s[i + len].isAlpha || s[i + len].isDigit || s[i + len] == '_')
            {
                len++;
            }
            string name = s[i .. i + len];

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

private:

string readString(string s, ref size_t i)
{
    string result;
    while (i < s.length && s[i] != '"')
    {
        if (s[i] != '\\')
        {
            result ~= s[i];
            i++;
            continue;
        }

        i++;
        if (s.length <= i)
        {
            error("Premature end of input");
        }

        // エスケープ
        switch (s[i])
        {
        case 'a': // ベル文字
            result ~= '\a';
            break;
        case 'b': // バックスペース
            result ~= '\b';
            break;
        case 'f': // 改ページ
            result ~= '\f';
            break;
        case 'n':
            result ~= '\n';
            break;
        case 'r':
            result ~= '\r';
            break;
        case 't':
            result ~= '\t';
            break;
        case 'v': // 垂直タブ
            result ~= '\v';
            break;
        default:
            result ~= s[i];
            break;
        }
        i++;
    }
    if (s.length <= i)
    {
        error("Premature end of input");
    }
    i++;
    return result;
}
