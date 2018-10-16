/// 中間表現。レジスタは無限にあるものとして、レジスタの使い回しをしないコードを生成する
module ir;

import parse;

// 5+20-4 -> 
// [IR(IMM, 0, 5), a = 5
// IR(IMM, 1, 20), b = 20
// IR(ADD, 0, 1), a += b
// IR(KILL, 1, 0), free(b)
// IR(IMM, 2, 4), c = 4
// IR(SUB, 0, 2), a -= c
// IR(KILL, 2, 0), free(c)
// IR(RETURN, 0, 0)] ret

public:

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

private:

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
