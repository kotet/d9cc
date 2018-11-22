module token;

import std.stdio : stderr;
import std.uni : isWhite;
import std.ascii : isDigit, isAlpha;
import std.algorithm : among;
import std.meta : aliasSeqOf;
import std.format : format;

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
    EQUAL,
    NOT_EQUAL,
    DO,
    WHILE,
    EXTERN,
    NEWLINE,
    ALIGNOF,
}

struct Token
{
    TokenType type;
    int val; // 数値リテラルデータ
    string str; // 文字列リテラルデータ
    string name; // 変数名
    string input; // エラー報告用のトークン文字列
    size_t lineno;
}

Token[] tokenize(string s)
{
    Token[] result;
    lineno = 1;
    size_t i;
    TokenType[string] symbols = [
        "int" : TokenType.INT, "return" : TokenType.RETURN, "if" : TokenType.IF,
        "for" : TokenType.FOR, "else" : TokenType.ELSE, "&&" : TokenType.LOGICAL_AND,
        "||" : TokenType.LOGICAL_OR, "sizeof" : TokenType.SIZEOF, "char" : TokenType.CHAR,
        "==" : TokenType.EQUAL, "!=" : TokenType.NOT_EQUAL, "do" : TokenType.DO, "while"
        : TokenType.WHILE, "extern" : TokenType.EXTERN, "_Alignof" : TokenType.ALIGNOF,
    ];

    while_loop: while (i < s.length) // Dの文字列はNull終端ではない
    {
        // 空白文字をスキップ
        if (s[i].isWhite())
        {
            i++;
            continue;
        }

        if (s[i] == '\n')
        {
            i++;
            lineno++;
            continue;
        }

        // 行コメント
        if ((i + 1) < s.length && s[i .. i + 2] == "//")
        {
            while (i < s.length && s[i] != '\n')
                i++;
            i++;
            lineno++;
            continue;
        }

        // ブロックコメント
        if ((i + 1) < s.length && s[i .. i + 2] == "/*")
        {
            while ((i + 1) < s.length && s[i .. i + 2] != "*/")
            {
                if (s[i] == '\n')
                    lineno++;
                i++;
                checkEOF(s, i + 1);
            }
            i += 2;
            continue;

        }

        // 文字列
        if (s[i] == '"')
        {
            Token t;
            t.lineno = lineno;
            t.type = TokenType.STRING;
            i++;
            string str = readString(s, i);
            t.str = str;
            t.input = str;
            result ~= t;
            continue;
        }

        //文字

        if (s[i] == '\'')
        {
            Token t;
            t.lineno = lineno;
            t.type = TokenType.NUM;
            i++;
            t.val = readChar(s, i);
            result ~= t;
            continue;
        }

        // 複数文字トークン
        foreach (symbol, type; symbols)
        {
            if ((i + symbol.length) < s.length && s[i .. (i + symbol.length)] == symbol)
            {
                Token t;
                t.lineno = lineno;
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
            t.lineno = lineno;
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
            t.lineno = lineno;
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
                t.lineno = lineno;
                t.type = TokenType.IDENTIFIER;
                t.name = name;
                t.input = name;
                return t;
            }();
            i += len;
            continue;
        }

        error("Cannot tokenize: %s (%d)", s[i], cast(int) s[i]);
    }

    result ~= () { Token t; t.lineno = lineno; t.type = TokenType.EOF; return t; }();

    return result;
}

private:

size_t lineno;

static immutable char[256] escaped = () {
    char[256] a;
    a[] = 0;
    static foreach (char c; "abfnrtv")
    {
        a[c] = mixin(format("'\\%c'", c));
    }
    a['e'] = a['E'] = '\033';
    return a;
}();

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
        checkEOF(s, i);

        // エスケープ
        char esc = escaped[s[i]];
        result ~= ((esc == 0) ? s[i] : esc);
        i++;
    }
    checkEOF(s, i);
    i++;
    return result;
}

int readChar(string s, ref size_t i)
{
    int result;
    checkEOF(s, i);
    if (s[i] != '\\')
    {
        result = cast(int) s[i];
        i++;
    }
    else
    {
        i++;
        checkEOF(s, i);
        result = escaped[s[i]];
        result = (result == 0) ? s[i] : result;
        i++;
    }
    checkEOF(s, i);
    if (s[i] != '\'')
    {
        error(format("Line %d: Unclosed character literal", lineno));
    }
    i++;
    return result;
}

private:

bool checkEOF(string s, size_t i)
{
    if (s.length <= i)
    {
        error(format("Line %d: Premature end of input", lineno));
        assert(0);
    }
    else
    {
        return true;
    }
}
