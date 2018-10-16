import std.stdio : writeln, writefln, stderr;
import std.conv : to;
import std.uni : isSpace;
import std.ascii : isDigit;

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

// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
// 5+20-4 -> 
// [IR(IMM, 0, 5), a = 5
// IR(IMM, 1, 20), b = 20
// IR(ADD, 0, 1), a += b
// IR(KILL, 1, 0), free(b)
// IR(IMM, 2, 4), c = 4
// IR(SUB, 0, 2), a -= c
// IR(KILL, 2, 0), free(c)
// IR(RETURN, 0, 0)] ret

enum IRType
{
    IMM, // IMmediate Move (即値move) の略? 
    MOV,
    RETURN,
    KILL, // lhsに指定されたレジスタを解放する
    NOP,
    ADD = '+',
    SUB = '-'
}

struct IR
{
    IRType op;
    size_t lhs;
    size_t rhs;
}

size_t genIRSub(ref IR[] ins, ref size_t regno, Node* node)
{
    if (node.type == NodeType.NUM)
    {
        size_t r = regno;
        regno++;

        IR imm;
        imm.op = IRType.IMM;
        imm.lhs = r;
        imm.rhs = node.val;

        ins ~= imm;
        return r;
    }

    assert(node.type == NodeType.ADD || node.type == NodeType.SUB);

    size_t lhs = genIRSub(ins, regno, node.lhs);
    size_t rhs = genIRSub(ins, regno, node.rhs);

    ins ~= () {
        IR ir;
        ir.op = cast(IRType) node.type;
        ir.lhs = lhs;
        ir.rhs = rhs;
        return ir;
    }();
    ins ~= () { IR ir; ir.op = IRType.KILL; ir.lhs = rhs; ir.rhs = 0; return ir; }();
    return lhs;
}

IR[] genIR(Node* node)
{
    IR[] result;
    size_t regno;

    size_t r = genIRSub(result, regno, node);

    IR ret;
    ret.op = IRType.RETURN;
    ret.lhs = r;
    ret.rhs = 0;

    result ~= ret;
    return result;
}

static immutable string[] registers = ["rdi", "rsi", "r10", "r11", "r12", "r13", "r14", "r15"];

// レジスタ割当

/// 使われていないレジスタを探して中間表現のレジスタと紐付ける
size_t alloc(ref size_t[size_t] reg_map, ref bool[] used, size_t ir_reg)
{
    if (ir_reg in reg_map)
    {
        size_t r = reg_map[ir_reg];
        assert(used[r]);
        return r;
    }
    foreach (i; 0 .. registers.length)
    {
        if (used[i])
            continue;
        used[i] = true;
        reg_map[ir_reg] = i;
        return i;
    }
    stderr.writeln("Register exhausted");
    throw new ExitException(-1);
}

/// レジスタの解放
void kill(ref bool[] used, size_t r)
{
    assert(used[r]);
    used[r] = false;
}

size_t[size_t] allocRegisters(ref IR[] ins)
{
    size_t[size_t] reg_map;
    bool[] used = new bool[](registers.length);
    used[] = false;
    foreach (ref ir; ins)
    {
        switch (ir.op)
        {
        case IRType.IMM:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            break;
        case IRType.MOV:
        case IRType.ADD:
        case IRType.SUB:
            ir.lhs = alloc(reg_map, used, ir.lhs);
            ir.rhs = alloc(reg_map, used, ir.rhs);
            break;
        case IRType.RETURN:
            kill(used, reg_map[ir.lhs]);
            break;
        case IRType.KILL:
            kill(used, reg_map[ir.lhs]);
            ir.op = IRType.NOP; // レジスタ割当専用命令なので特に対応する命令はない
            break;
        default:
            assert(0, "Unknown operator");
        }
    }
    return reg_map;
}

// コード生成器

void generate_x86(IR[] ins)
{
    foreach (ir; ins)
    {
        switch (ir.op)
        {
        case IRType.IMM:
            writefln("  mov %s, %d", registers[ir.lhs], ir.rhs);
            break;
        case IRType.MOV:
            writefln("  mov %s, %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.RETURN:
            writefln("  mov rax, %s", registers[ir.lhs]);
            writefln("  ret");
            break;
        case IRType.ADD:
            writefln("  add %s, %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.SUB:
            writefln("  sub %s, %s", registers[ir.lhs], registers[ir.rhs]);
            break;
        case IRType.NOP:
            break;
        default:
            assert(0, "Unknown operator");
        }
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

        IR[] ins = genIR(node);

        size_t[size_t] reg_map = allocRegisters(ins);

        writeln(".intel_syntax noprefix"); // intel記法を使う
        writeln(".global main");
        writeln("main:");

        generate_x86(ins);
        return 0;
    }
    catch (ExitException e)
    {
        return e.rc;
    }
}
