#!/bin/sh
# @todo: replace with a proper make file?

set +e # stop on error

# color constants
LC='\033[0;33m' # log color - dark grey
NC='\033[0m' # no color

cd src/flex/

echo -e "${LC}-- Flex Start --${NC}"
flex lexer # creatures lex.yy.c
echo -e "${LC}-- Flex End --${NC}"

cd ../../

mkdir -p build # gcc won't build the directory

# creates bison/parser.tab.c and a few other files
# --report=state creates an .output file for debugging
cd src/bison/
echo -e "${LC}-- Bison Start --${NC}"
bison -d parser.y --report=state
echo -e "${LC}-- Bison End --${NC}"

cd ../../
echo -e "${LC}-- GCC Start --${NC}"
gcc src/flex/lex.yy.c src/bison/parser.tab.c libs/libyywrap.c src/symbol_table.c src/parse_node.c -o build/compiler
echo -e "${LC}-- GCC End --${NC}"


