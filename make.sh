#!/bin/sh
# ./make [1], if 1 is present only the lexer will be built/linked
# @todo: replace with a proper make file?

set +e # stop on error

cd src/flex/
flex lexer # creatures lex.yy.c

cd ../../

mkdir -p build # gcc won't build the directory

if [ -n "$1" ]; then
	echo "Building lexer only..."
	gcc -Wall src/flex/lex.yy.c -o build/compiler
	exit 0
fi


# creates bison/parser.tab.c and a few other files
# --report=state creates an .output file for debugging
cd src/bison/
bison -d parser.y --report=state

cd ../../
gcc -Wall src/flex/lex.yy.c src/bison/parser.tab.c libs/libyywrap.c -o build/compiler

