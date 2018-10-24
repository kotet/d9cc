#!/bin/bash

try() {
    expected="$1"
    input="$2"

    ./d9cc "$input" > tmp.s
    gcc -static -o tmp tmp.s tmp-plus.o
    ./tmp
    actual="$?"

    if [ "$actual" == "$expected" ]; then
        echo "$input => $actual"
    else
        echo "$input: $expected expected, but got $actual"
        exit 1
    fi
}

try 0 'int main() { return 0; }'
try 42 'int main() { return 42; }'
try 21 'int main() { 1+2; return 5+20-4; }'
try 41 'int main() { return 12 + 34 - 5 ; }'
try 36 'int main() { return 1+2+3+4+5+6+7+8; }'
try 153 'int main() { return 1+2+3+4+5+6+7+8+9+10+11+12+13+14+15+16+17; }'
echo
try 10 'int main() { return 2*3+4; }'
try 14 'int main() { return 2+3*4; }'
try 26 'int main() { return 2*3+4*5; }'
try 5 'int main() { return 50/10; }'
try 9 'int main() { return 6*3/2; }'
echo
try 2 'int main() { int a = 2; return a; }'
try 10 'int main() { int a=2;int b=3+2;return a*b; }'
echo
try 45 'int main() { return ( 2 + 3 ) *(4+5); }'
echo
try 2 'int main() { if (1) return 2;return 3; }'
try 3 'int main() { if (0) return 2;return 3; }'
echo
try 2 'int main() { int a; if (1) a=2;else a=3;return a; }'
try 3 'int main() { int a; if (0) a=2;else a=3;return a; }'
echo
try 5 'int main() { return plus(2,3); }'
echo
try 1 'int one() { return 1; } int main() { return one(); }'
try 3 'int one() { return 1; } int two() { return 2; } int main() { return one() + two(); }'
try 6 'int mul(a, b) { return a * b; } int main() { return mul(2, 3); }'
try 21 'int add(a,b,c,d,e,f) { return a+b+c+d+e+f; } int main() { return add(1,2,3,4,5,6); }'
echo
try 0 'int main() { return 0||0; }'
try 1 'int main() { return 1||0; }'
try 1 'int main() { return 0||1; }'
try 1 'int main() { return 1||1; }'
echo
try 0 'int main() { return 0&&0; }'
try 0 'int main() { return 1&&0; }'
try 0 'int main() { return 0&&1; }'
try 1 'int main() { return 1&&1; }'
echo
try 0 'int main() { return 0<0; }'
try 0 'int main() { return 1<0; }'
try 1 'int main() { return 0<1; }'
try 0 'int main() { return 0>0; }'
try 0 'int main() { return 0>1; }'
try 1 'int main() { return 1>0; }'
echo
try 60 'int main() { int sum=0; int i; for (i=10; i<15; i=i+1) sum = sum + i; return sum;}'
try 89 'int main() { int i=1; int j=1; int k; int m; for (k=0; k<10; k=k+1) { m=i+j; i=j; j=m; } return i;}'
echo "＿人人人＿"
echo "＞　OK　＜"
echo "￣Y^Y^Y^￣"
