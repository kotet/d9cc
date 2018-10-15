import std.stdio : writeln, writefln, stderr;
import std.conv : to;
import std.uni : isSpace;
import std.ascii : isDigit;
import std.array : join;
import std.variant : Algebraic;

enum TokenType
{
    NUM,
    ADD = '+',
    SUB = '-',
    EOF
}

struct Token
{
    TokenType type;
    int val; // 数値リテラルデータ
    string input; // エラー報告用のトークン文字列
}

/// Cみたいにどこでもexit()するための例外
class ExitException : Exception
{
    /// 終了コード
    int rc;

    this(int return_code = 0, string file = __FILE__, size_t line = __LINE__)
    {
        super(null, file, line);
        this.rc = return_code;
    }
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

        if (s[i] == '+' || s[i] == '-')
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

// 再起下降構文解析器
// 1+2+3+4 -> ((((1 + 2) + 3) + 4) + 5)

enum NodeType
{
    NUM,
    ADD = '+',
    SUB = '-'
}

struct Node
{
    NodeType type;
    Node* lhs = null;
    Node* rhs = null;
    int val;
}

Node* number(Token[] tokens, ref size_t i)
{
    if (tokens[i].type == TokenType.NUM)
    {
        Node* n = new Node();
        n.type = NodeType.NUM;
        n.val = tokens[i].val;
        i++;
        return n;
    }
    stderr.writefln("Number expected, but got %s", tokens[i].input);
    throw new ExitException(-1);
}

Node* expr(Token[] tokens)
{
    size_t i;
    Node* lhs = number(tokens, i);

    while (true)
    {
        TokenType op = tokens[i].type;
        if (op != TokenType.ADD && op != TokenType.SUB)
        {
            break;
        }
        i++;
        Node* new_lhs = new Node();
        new_lhs.type = cast(NodeType) op;
        new_lhs.lhs = lhs;
        new_lhs.rhs = number(tokens, i);
        lhs = new_lhs;
    }
    if (tokens[i].type != TokenType.EOF)
    {
        writefln("Stray token: %s", tokens[i].input);
    }
    return lhs;
}

// コード生成器

static immutable string[] registers = ["rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"];

string generate(Node* node, ref size_t i)
{
    if (node.type == NodeType.NUM)
    {
        if (i < registers.length)
        {
            string register = registers[i];
            i++;
            writefln("  mov %s, %d", register, node.val);
            return register;
        }
        stderr.writeln("Register exhausted");
        throw new ExitException(-1);
    }

    string dst = generate(node.lhs, i);
    string src = generate(node.rhs, i);

    switch (node.type)
    {
    default:
        throw new ExitException(-1);
        break;
    case NodeType.ADD:
        writefln("  add %s, %s", dst, src);
        return dst;
    case NodeType.SUB:
        writefln("  sub %s, %s", dst, src);
        return dst;
    }
}

void fail(Token t)
{
    stderr.writefln("Unexpected token: %s (%s)", t.input, t.type);
    throw new ExitException(-1);
}

/// strtolの代わり
int nextInt(string s, ref size_t i)
{
    int result;
    while (i < s.length && '0' <= s[i] && s[i] <= '9')
    {
        result = (result * 10) + (s[i] - '0');
        i++;
    }
    return result;
}

int main(string[] args)
{
    if (args.length != 2)
    {
        stderr.writeln("Usage: d9cc <code>");
        return 1;
    }

    try
    {
        Token[] tokens = tokenize(args[1]);
        size_t i;

        Node* node = expr(tokens);

        writeln(".intel_syntax noprefix"); // intel記法を使う
        writeln(".global main");
        writeln("main:");

        writefln("  mov rax, %s", generate(node, i));

        writeln("  ret");
        return 0;
    }
    catch (ExitException e)
    {
        return e.rc;
    }
}
