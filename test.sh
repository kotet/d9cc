#!/bin/bash

try() {
    expected="$1"
    input="$2"

    ./d9cc "$input" > tmp.s
    gcc -static -o tmp tmp.s
    ./tmp
    actual="$?"

    if [ "$actual" == "$expected" ]; then
        echo "$input => $actual"
    else
        echo "$input expected, but got $actual"
        exit 1
    fi
}

try 0 0
try 42 42
try 21 '5+20-4'
try 41 '12 + 34 - 5'

echo "＿人人人＿"
echo "＞　OK　＜"
echo "￣Y^Y^Y^￣"
