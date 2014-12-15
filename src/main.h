
#ifndef __MAIN_H__
#define __MAIN_H__

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"
#include "parse_node.h"

enum {
    TYPE_NONE,
    TYPE_VAR,
    TYPE_INTEGER,
    TYPE_FLOAT,
    TYPE_BOOL,
    TYPE_OP_ADD,
    TYPE_OP_SUB,
    TYPE_OP_MUL,
    TYPE_OP_DIV,
    TYPE_OP_GT, // greater than
    TYPE_OP_GE, // greater equal than
    TYPE_OP_LT, // smaller than
    TYPE_OP_LE, // smaller equal than
    TYPE_OP_EQ, // equal
    TYPE_OP_NE, // not equal
    TYPE_OP_BITWISE_AND,
    TYPE_OP_BITWISE_OR,
    TYPE_OP_LOGICAL_AND,
    TYPE_OP_LOGICAL_OR,
    TYPE_OP_NEG, // !value
    TYPE_OP_MINUS, // -value
    TYPE_ASSIGN,
    TYPE_IF,
    TYPE_WHILE,
    TYPE_ELSEIF,
    TYPE_ELSE,
    TYPE_PRINTLN,
    TYPE_CONNECTION_NODE, // compiles both 'left' and 'right' by default
};

typedef enum
{
    CODE_OP_ASSIGN, // add $dest $reg1 $zero
    CODE_OP_ASSIGN_F,
    CODE_OP_ADD, // add $dest $reg1 $reg2
    CODE_OP_ADD_F,
    CODE_OP_SUB, // sub $dest $reg1 $reg2
    CODE_OP_SUB_F,
    CODE_OP_MUL, // mult $dest $reg1 $reg2
    CODE_OP_MUL_F,
    CODE_OP_DIV, // div $dest $reg1 $reg2
    CODE_OP_DIV_F,
    CODE_OP_BEQ, // branch equal @todo: fixme, used in cases that need BGE
    CODE_OP_JUMP, // jump $label
    CODE_OP_LABEL, // label $name
    CODE_OP_LI, // load immediate integer $dest $value
    CODE_OP_LI_F,
    CODE_OP_SLT, // set less than $dest $reg1 $reg2
    CODE_OP_SLT_F,
    CODE_OP_SLE, // set less or equal than $dest $reg1 $reg2
    CODE_OP_SLE_F,
    CODE_OP_SEQ, // set equal $dest $reg1 $reg2
    CODE_OP_SEQ_F,
    CODE_OP_SNE, // set not equal $dest $reg1 $reg2
    CODE_OP_SNE_F,
    CODE_OP_BITWISE_AND,
    CODE_OP_BITWISE_OR, 
    CODE_OP_LOGICAL_AND, 
    CODE_OP_LOGICAL_OR,
    CODE_PRINT_INTEGER,
    CODE_PRINT_FLOAT,
    CODE_PRINT_BOOL,
    CODE_PRINT_NEWLINE,
} CodeOpType;

typedef enum
{
    CODE_VAL_NONE,
    CODE_VAL_REGISTER,
    CODE_VAL_INT_VALUE,
    CODE_VAL_FLOAT_VALUE,
    CODE_VAL_FLOAT_MEMORY,
    CODE_VAL_LABEL,
} CodeValType;

typedef enum
{
    CODE_REGISTER_NONE,
    CODE_REGISTER_SAVED,
    CODE_REGISTER_TEMP,
    CODE_REGISTER_FLOAT,
} CodeRegisterType;

struct CompileData
{
    CodeValType type;
    CodeRegisterType registerType; // if CODE_VAL_REGISTER
    union
    {
        int ival;
        float fval;
    } data;
};

typedef struct CompileData CompileData;

CompileData mk_compile_data();

struct Code
{
    CodeOpType op;
    CompileData dest;
    CompileData val1;
    CompileData val2;
    
    struct Code* next;
};

typedef struct Code Code;

void add_code(CodeOpType op, CompileData dest, CompileData val1, CompileData val2);


struct FloatImmediate
{
    int id;
    float value;
    
    struct FloatImmediate* next;
};

typedef struct FloatImmediate FloatImmediate;

// debug helpers
const char* strForType(int type);
void print_tree(parse_node* node);
void print_symbol_table();
// --

CompileData mk_compile_data();
CompileData create_label();

void add_code(CodeOpType op, CompileData dest, CompileData val1, CompileData val2);
int add_fp(float value);

void compile(parse_node* node);
CompileData compile_exp(parse_node* node);

const char* print_CompileData(CompileData data);

void convert_code_to_mips(FILE* file);
void print_float_variables(FILE* file);

#endif


