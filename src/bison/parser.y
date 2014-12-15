
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "../symbol_table.h"
#include "../parse_node.h"

/* suppress some compiler warnings */
int yylex();
int yyerror(char *s);

int __parser_debug__ = 0; /* toggle for debug prints*/

#define DEBUG_LOG(...)                  \
    do {                                \
        if (__parser_debug__  != 0) {   \
            printf(__VA_ARGS__);        \
            printf("\n");               \
        }                               \
    } while (0)

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

parse_node* make_node(int type, parse_node* left, parse_node* right)
{
    parse_node* node = alloc_parse_node();
    node->type = type;
    node->left = left;
    node->right = right;
    return node;
}

parse_node* make_op_node(parse_node* left, parse_node* right, int op_type)
{   
    int left_type = left->type;
    int right_type = right->type;
    
    if (left_type == TYPE_VAR)
    {
        symbol_entry* var_sym = get_symbol(left->data.sval);
        if (var_sym != NULL)
            left_type = var_sym->type;
    }
    
    if (right_type == TYPE_VAR)
    {
        symbol_entry* var_sym = get_symbol(right->data.sval);
        if (var_sym != NULL)
            right_type = var_sym->type;
    }
    
    if (left_type != right_type) {
        printf("ERROR: type mismatch - type of $1 is %d, type of $2 is %d\n", left->type, right->type);
        return NULL;
    }
    
    int exp_type = left_type;
    switch (op_type)
    {
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
            if (exp_type != TYPE_INTEGER && exp_type != TYPE_FLOAT) {
                printf("ERROR (1): bad type for op, type is %d, op_type is %d\n", exp_type, op_type);
                return NULL;
            }
            
            break;
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
            if (exp_type != TYPE_INTEGER && exp_type != TYPE_FLOAT) {
                printf("ERROR (2): bad type for op, type is %d, op_type is %d\n", exp_type, op_type);
                return NULL;
            }
            
            exp_type = TYPE_BOOL;
            break;
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
            exp_type = TYPE_BOOL;
            break;
        case TYPE_OP_BITWISE_AND:
        case TYPE_OP_BITWISE_OR:
            if (exp_type != TYPE_INTEGER) {
                printf("ERROR (2): bad type for op, type is %d, op_type is %d\n", exp_type, op_type);
                return NULL;
            }
            
            break;
        case TYPE_OP_LOGICAL_AND:
        case TYPE_OP_LOGICAL_OR:
            if (exp_type != TYPE_BOOL) {
                printf("ERROR (2): bad type for op, type is %d, op_type is %d\n", exp_type, op_type);
                return NULL;
            }
            
            exp_type = TYPE_BOOL;
            break;
        default:
            printf("Bad op type: %d", op_type);
            assert(0);
            break;
    }
    
    parse_node* node = make_node(exp_type, left, right);
    node->op_type = op_type;
    return node;
}

parse_node* make_op_node_single_arg(parse_node* left, int op_type)
{
    int left_type = left->type;
    
    if (left_type == TYPE_VAR)
    {
        symbol_entry* var_sym = get_symbol(left->data.sval);
        if (var_sym != NULL)
            left_type = var_sym->type;
    }
    
    int exp_type = left_type;
    switch (op_type)
    {
        case TYPE_OP_NEG:
            if (exp_type != TYPE_BOOL)
            {
                printf("ERROR (3): bad type for op, type is %d, op_type is %d\n", exp_type, op_type);
                return NULL;
            }
            
            break;
        case TYPE_OP_MINUS:
            if (exp_type == TYPE_BOOL)
            {
                printf("ERROR (3): bad type for op, type is %d, op_type is %d\n", exp_type, op_type);
                return NULL;
            }
            
            break;
        default:
            printf("Bad op type: %d", op_type);
            assert(0);
            break;
    }
    
    parse_node* node = make_node(exp_type, left, NULL);
    node->op_type = op_type;
    return node;
}

%}

%union {
    char* id; /* identifiers */
    char* sval; /* strings */
    int ival; /* integers */
    double fval; /* floats/doubles */
    parse_node* node; /* node for tree structure */
}

%token <ival> TOKEN_TRUE TOKEN_FALSE
%token <ival> TOKEN_INTEGER
%token <fval> TOKEN_FLOAT
%token <sval> TOKEN_VAR
%token <node> TOKEN_PRINTLN TOKEN_SEPARATOR TOKEN_IF TOKEN_WHILE TOKEN_ELSEIF TOKEN_ELSE TOKEN_END
                              
%token TOKEN_ASSIGN
%token '(' ')'

%left TOKEN_GT TOKEN_LT TOKEN_GE TOKEN_LE TOKEN_NE TOKEN_EQ
%left TOKEN_ADD TOKEN_SUB
%left TOKEN_MUL TOKEN_DIV
%left TOKEN_BITWISE_AND TOKEN_BITWISE_OR TOKEN_LOGICAL_AND TOKEN_LOGICAL_OR
%left TOKEN_NEG

%type<node> comm_list command if_comm while_comm var exp elseif_list elseif_block else_block

%start program
%%

program : comm_list             { root = $1; }
;

comm_list : command             { DEBUG_LOG("Reduce [command] to [comm_list]");
                                  $$ = $1; }

        | command comm_list     { DEBUG_LOG("Reduce [command comm_list] to [comm_list]"); 
                                  $$ = make_node(TYPE_CONNECTION_NODE, $1, $2); }
;

command : if_comm               { DEBUG_LOG("Reduce [if_comm] to [command]");
                                  $$ = $1; }
                                  
    | while_comm                { DEBUG_LOG("Reduce [while_comm] to [command]");
                                  $$ = $1; }

    | var TOKEN_ASSIGN exp      { DEBUG_LOG("Reduce [var '=' exp] to [command]");
                                  if (get_symbol($1->data.sval) == NULL)
                                    put_symbol($1->data.sval, $3->type);
                                    
                                  $$ = make_node(TYPE_ASSIGN, $1, $3); }
                                    
    | TOKEN_PRINTLN '(' exp ')' { DEBUG_LOG("Reduce [TOKEN_PRINTLN '(' exp ')'] to [command]");
                                  $$ = make_node(TYPE_PRINTLN, $3, NULL); }
;

exp: exp TOKEN_ADD exp         { DEBUG_LOG("Reduce [exp TOKEN_ADD exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_ADD);
                                  if (!$$) YYERROR; }

    | exp TOKEN_SUB exp         { DEBUG_LOG("Reduce [exp TOKEN_SUB exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_SUB);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_MUL exp         { DEBUG_LOG("Reduce [exp TOKEN_MUL exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_MUL);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_DIV exp         { DEBUG_LOG("Reduce [exp TOKEN_DIV exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_DIV);
                                  if (!$$) YYERROR; }

    | exp TOKEN_GT exp          { DEBUG_LOG("Reduce [exp TOKEN_GT exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_GT);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_LT exp          { DEBUG_LOG("Reduce [exp TOKEN_LT exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_LT);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_GE exp          { DEBUG_LOG("Reduce [exp TOKEN_GE exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_GE);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_LE exp          { DEBUG_LOG("Reduce [exp TOKEN_LE exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_LE);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_EQ exp          { DEBUG_LOG("Reduce [exp TOKEN_EQ exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_EQ);
                                  if (!$$) YYERROR; }
    
    | exp TOKEN_NE exp          { DEBUG_LOG("Reduce [exp TOKEN_NE exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_NE);
                                  if (!$$) YYERROR; }

    | exp TOKEN_BITWISE_AND exp { DEBUG_LOG("Reduce [exp TYPE_OP_BITWISE_AND exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_BITWISE_AND);
                                  if (!$$) YYERROR; }
        
    | exp TOKEN_BITWISE_OR exp  { DEBUG_LOG("Reduce [exp TYPE_OP_BITWISE_OR exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_BITWISE_OR);
                                  if (!$$) YYERROR; }

    | exp TOKEN_LOGICAL_AND exp { DEBUG_LOG("Reduce [exp TYPE_OP_LOGICAL_AND exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_LOGICAL_AND);
                                  if (!$$) YYERROR; }

    | exp TOKEN_LOGICAL_OR exp  { DEBUG_LOG("Reduce [exp TYPE_OP_LOGICAL_OR exp] to [exp]");
                                  $$ = make_op_node($1, $3, TYPE_OP_LOGICAL_OR);
                                  if (!$$) YYERROR; }
                                
    | TOKEN_NEG exp             { DEBUG_LOG("Reduce [TOKEN_NEG exp] to [exp]");
                                  $$ = make_op_node_single_arg($2, TYPE_OP_NEG);
                                  if (!$$) YYERROR; }
                                  
    | TOKEN_SUB exp %prec TOKEN_NEG { DEBUG_LOG("Reduce [TOKEN_SUB exp] to [exp]");
                                  $$ = make_op_node_single_arg($2, TYPE_OP_MINUS);
                                  if (!$$) YYERROR; }

    | TOKEN_INTEGER             { DEBUG_LOG("Reduce [TOKEN_INTEGER] to [exp]");
                                  $$ = make_node(TYPE_INTEGER, NULL, NULL);
                                  $$->data.ival = yylval.ival; }

    | TOKEN_FLOAT               { DEBUG_LOG("Reduce [TOKEN_FLOAT] to [exp]");
                                  $$ = make_node(TYPE_FLOAT, NULL, NULL);
                                  $$->data.fval = yylval.fval;}
                                  
    | bool                      { DEBUG_LOG("Reduce [bool] to [exp]");
                                  $$ = make_node(TYPE_BOOL, NULL, NULL);
                                  $$->data.ival = yylval.ival; }

    | var
    
    | '(' exp ')'               { DEBUG_LOG("Reduce ['(' exp ')'] to [exp]");
                                  $$ = $2; }
;

var: TOKEN_VAR                  { DEBUG_LOG("Reduce [TOKEN_VAR] to [var]");
                                  $$ = make_node(TYPE_VAR, NULL, NULL);
                                  $$->data.sval = yylval.sval; }

bool: TOKEN_TRUE
    | TOKEN_FALSE

if_comm: TOKEN_IF exp comm_list elseif_list else_block TOKEN_END  { 
                                  DEBUG_LOG("Reduce [TOKEN_IF exp comm_list elseif_list else_block TOKEN_END] to [if_comm]");
                                  if ($2->type != TYPE_BOOL) {
                                    printf("ERROR: type mismatch - type of $2 (%d) is not TYPE_BOOL\n", $2->type);
                                    YYERROR;
                                  }
                                
                                  $$ = make_node(TYPE_IF, $2, $3);
                                  $$->next = ($4 != NULL) ? $4 : $5;
                                  if ($4 != NULL) {
                                    $$->next = $4; // elseif_list
                                    parse_node* temp = $4;
                                    while (temp->next != NULL)
                                        temp = temp->next; // goto end of the TYPE_ELSEIF node list
                                        
                                    temp = $5; // else_block
                                  } else { // elseif_list is empty
                                    $$->next = $5; // else_block
                                  }
                                }
;

while_comm: TOKEN_WHILE exp comm_list TOKEN_END         {
                                  DEBUG_LOG("Reduce [TOKEN_WHILE exp comm_list TOKEN_END] to [while_comm]");
                                  if ($2->type != TYPE_BOOL) {
                                    printf("ERROR: type mismatch - type of $2 (%d) is not TYPE_BOOL\n", $2->type);
                                    YYERROR;
                                  }
                                  
                                  $$ = make_node(TYPE_WHILE, $2, $3); }
;

elseif_list: /* empty */                { DEBUG_LOG("Reduce [EMPTY] to [elseif_list]");
                                          $$ = NULL; }
                                          
           | elseif_list elseif_block   { DEBUG_LOG("Reduce [elseif_list elseif_block] to [elseif_list]");
                                          if ($1 == NULL) {
                                            $$ = $2;
                                          } else {
                                            $$ = $1;
                                            parse_node* temp = $$;
                                            while (temp->next != NULL)
                                                temp = temp->next; // goto end of the TYPE_ELSEIF node list
                                                
                                            temp->next = $2;
                                          }
                                        }
;
            
elseif_block: TOKEN_ELSEIF exp comm_list    { DEBUG_LOG("Reduce [TOKEN_ELSEIF exp comm_list] to [elseif_block]");
                                              $$ = make_node(TYPE_ELSEIF, $2, $3); }
;

else_block: /* empty */                 { $$ = NULL; }
    | TOKEN_ELSE comm_list              { DEBUG_LOG("Reduce [TOKEN_ELSE comm_list] to [else_block]");
                                          $$ = make_node(TYPE_ELSE, $2, NULL); }
;

%%

int yyerror(char *s) {
    printf("yyerror: %s\n", s);
    return 0;
}

int spaces = 1;

const char* strForType(int type)
{
    switch (type)
    {
        case TYPE_VAR: return "TYPE_VAR";
        case TYPE_INTEGER: return "TYPE_INTEGER";
        case TYPE_FLOAT: return "TYPE_FLOAT";
        case TYPE_BOOL: return "TYPE_BOOL";
        case TYPE_OP_ADD: return "TYPE_OP_ADD";
        case TYPE_OP_SUB: return "TYPE_OP_SUB";
        case TYPE_OP_MUL: return "TYPE_OP_MUL";
        case TYPE_OP_DIV: return "TYPE_OP_DIV";
        case TYPE_OP_GT: return "TYPE_OP_GT";
        case TYPE_OP_GE: return "TYPE_OP_GE";
        case TYPE_OP_LT: return "TYPE_OP_LT";
        case TYPE_OP_LE: return "TYPE_OP_LE";
        case TYPE_OP_EQ: return "TYPE_OP_EQ";
        case TYPE_OP_NE: return "TYPE_OP_NE";
        case TYPE_OP_BITWISE_AND: return "TYPE_OP_BITWISE_AND";
        case TYPE_OP_BITWISE_OR: return "TYPE_OP_BITWISE_OR";
        case TYPE_OP_LOGICAL_AND: return "TYPE_OP_LOGICAL_AND";
        case TYPE_OP_LOGICAL_OR: return "TYPE_OP_LOGICAL_OR";
        case TYPE_OP_NEG: return "TYPE_OP_NEG";
        case TYPE_OP_MINUS: return "TYPE_OP_MINUS";
        case TYPE_ASSIGN: return "TYPE_ASSIGN";
        case TYPE_IF: return "TYPE_IF";
        case TYPE_WHILE: return "TYPE_WHILE";
        case TYPE_ELSEIF: return "TYPE_ELSEIF";
        case TYPE_ELSE: return "TYPE_ELSE";
        case TYPE_CONNECTION_NODE: return "TYPE_CONNECTION_NODE";
    }

    return "<undefined>"; // shitty compilers (like this one) might complain
}

void print_tree(parse_node* node)
{
    if (node == NULL)
        return;

    int i = 0;
    for (; i < spaces; ++i)
        printf("-");
    
    parse_node* left = node->left;
    parse_node* right = node->right;
    parse_node* next = node->next;
    
    char valStr[20];
    switch (node->type)
    {
        case TYPE_VAR:
            sprintf(valStr, "%s", node->data.sval);
            break;
        case TYPE_INTEGER:
            sprintf(valStr, "%d", node->data.ival);
            break;
        case TYPE_FLOAT:
            sprintf(valStr, "%f", node->data.fval);
            break;
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
        case TYPE_ASSIGN:
        case TYPE_IF:
        case TYPE_WHILE:
        case TYPE_ELSEIF:
        case TYPE_ELSE:
        case TYPE_CONNECTION_NODE:
        default:
            sprintf(valStr, "None");
            break;
    }

    printf(" [Node] Type: %s, Val: %s, Left: %s, Right: %s, Next: %s\n",
        strForType(node->type),
        valStr,
        left ? "Yes" : "No",
        right ? "Yes" : "No",
        next ? "Yes" : "No");

    ++spaces;
    print_tree(left);
    print_tree(right);
    --spaces;
    
    print_tree(next);
}

void print_symbol_table()
{
    printf("-- Symbol Table - Start --\n");
    symbol_entry* ptr = symtable;
    while (ptr != NULL)
    {
        printf("Symbol - name: %s, type: %s, register: %u\n", ptr->name, strForType(ptr->type), ptr->_register);
        ptr = ptr->next;
    }
    printf("-- Symbol Table - End --\n");
}

int var_num = 0;

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

CompileData mk_compile_data()
{
    CompileData data;
    data.type = CODE_VAL_NONE;
    data.registerType = CODE_REGISTER_NONE;
    data.data.ival = 0;
    return data;
}

struct Code
{
    CodeOpType op;
    CompileData dest;
    CompileData val1;
    CompileData val2;
    
    struct Code* next;
};

typedef struct Code Code;

Code* firstCode = NULL;
Code* lastCode = NULL;

int add_fp(float value);

void add_code(CodeOpType op, CompileData dest, CompileData val1, CompileData val2)
{
    Code* c = (Code*)malloc(sizeof(Code));
    if (firstCode == NULL)
    {
        firstCode = c;
        lastCode = c;
    }
    else
    {
        lastCode->next = c;
        lastCode = c;
    }
    
    c->op = op;
    c->dest = dest;
    c->val1 = val1;
    c->val2 = val2;
    c->next = NULL;
    
    if (op == CODE_OP_LI_F)
    {
        // the hacks we do for love
        int id = add_fp(c->val1.data.fval);
        c->val1.type = CODE_VAL_FLOAT_MEMORY;
        c->val1.registerType = CODE_REGISTER_NONE;
        c->val1.data.ival = id;
    }
}

int label_counter = 0;
int symbol_int_register_counter = 0;
int symbol_float_register_counter = 1;
int temp_int_register_counter = 0;
int* temp_float_register_counter = &symbol_float_register_counter;

CompileData create_label()
{
    CompileData data = mk_compile_data();
    data.type = CODE_VAL_LABEL;
    data.data.ival = label_counter++;
    return data;
}

struct FloatImmediate
{
    int id;
    float value;
    
    struct FloatImmediate* next;
};

typedef struct FloatImmediate FloatImmediate;

FloatImmediate* first_fp = NULL;
FloatImmediate* last_fp = NULL;
int fp_counter = 0;

int add_fp(float value)
{
    FloatImmediate* fp = (FloatImmediate*)malloc(sizeof(FloatImmediate));
    if (first_fp == NULL)
    {
        first_fp = fp;
        last_fp = fp;
    }
    else
    {
        last_fp->next = fp;
        last_fp = fp;
    }
    
    fp->id = fp_counter++;
    fp->value = value;
    fp->next = NULL;
    return fp->id;
}

void print_float_variables()
{
    FloatImmediate* fp = first_fp;
    while (fp != NULL)
    {
        printf("fp%u:\t.float\t%f\n", fp->id, fp->value);
        fp = fp->next;
    }
}

int get_register_for_symbol(parse_node* node)
{
    symbol_entry* sym = get_symbol(node->data.sval);
    if (!sym)
    {
        printf("Var %s not initialized! Exiting!\n", node->data.sval);
        exit(1);
    }
    
    if (sym->_register == -1)
        sym->_register = sym->type == TYPE_FLOAT ? symbol_float_register_counter++ : symbol_int_register_counter++;
        
    return sym->_register;
}

CompileData compile_exp(parse_node* node);

// possibly return a variable type
void compile(parse_node* node)
{
    if (node == NULL)
        return;

    parse_node* left = node->left;
    parse_node* right = node->right;
    
    CompileData leftData;
    CompileData rightData;
    switch (node->type)
    {
        case TYPE_ASSIGN: // left is VAR, right is exp
            leftData = compile_exp(left);
            rightData = compile_exp(right);
            if (rightData.type != CODE_VAL_REGISTER) // needs to be a register
            {
                CompileData destData = mk_compile_data();
                int* destRegister = right->type == TYPE_FLOAT ? temp_float_register_counter : &temp_int_register_counter;
                destData.type = CODE_VAL_REGISTER;
                destData.registerType = right->type == TYPE_FLOAT ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                destData.data.ival = (*destRegister)++;
                add_code(right->type == TYPE_FLOAT ? CODE_OP_LI_F : CODE_OP_LI, destData, rightData, mk_compile_data());
                rightData = destData;
            }
            
            add_code(right->type == TYPE_FLOAT ? CODE_OP_ASSIGN_F : CODE_OP_ASSIGN, leftData, rightData, mk_compile_data()); // add $var1 $var2 $zero
            break;
        case TYPE_IF: // left: exp, right: comm_list, next for elseif/else blocks
        {
            CompileData label2 = create_label();
            while (node != NULL)
            {
                left = node->left;
                right = node->right;

                if (node->type != TYPE_ELSE)
                {
                    leftData = compile_exp(left);
                    CompileData label1 = create_label();
                    if (leftData.registerType == CODE_REGISTER_FLOAT)
                        leftData.registerType = CODE_REGISTER_TEMP;

                    add_code(CODE_OP_BEQ, leftData, mk_compile_data(), label1); // beq $var1, $zero, L1
                    compile(right);
                    add_code(CODE_OP_JUMP, label2, mk_compile_data(), mk_compile_data());
                    add_code(CODE_OP_LABEL, label1, mk_compile_data(), mk_compile_data()); // label L1
                    node = node->next;
                }
                else /* if (node->type == TYPE_ELSE) */
                {
                    compile(left); // left: comm_list
                    assert(node->next == NULL);
                    break; // node with TYPE_ELSE should be the last of the list, no need for jump L2 either
                }
            }
            add_code(CODE_OP_LABEL, label2, mk_compile_data(), mk_compile_data()); // label L2
            break;
        }
        case TYPE_WHILE: // left: exp, right: comm_list
        {
            CompileData label1 = create_label();
            add_code(CODE_OP_LABEL, label1, mk_compile_data(), mk_compile_data()); // make label L1
            leftData = compile_exp(left);
            CompileData label2 = create_label();
            if (leftData.registerType == CODE_REGISTER_FLOAT)
                leftData.registerType = CODE_REGISTER_TEMP;
                        
            add_code(CODE_OP_BEQ, leftData, mk_compile_data(), label2); // beq $var1, $zero, L2
            compile(right);
            add_code(CODE_OP_JUMP, label1, mk_compile_data(), mk_compile_data()); // make j L1
            add_code(CODE_OP_LABEL, label2, mk_compile_data(), mk_compile_data()); // make label L2
            break;
        }
        case TYPE_CONNECTION_NODE:
            compile(left);
            compile(right);
            break;
        case TYPE_PRINTLN:
            assert(right == NULL);
            leftData = compile_exp(left);
            switch (left->type)
            {
                case TYPE_VAR:
                {
                    symbol_entry* var_sym = get_symbol(left->data.sval);
                    if (!var_sym)
                    {
                        printf("Var %s not initialized! Exiting!\n", left->data.sval);
                        exit(1);
                    }
                    
                    switch (var_sym->type)
                    {
                        case TYPE_INTEGER:
                            add_code(CODE_PRINT_INTEGER, leftData, mk_compile_data(), mk_compile_data());
                            break;
                        case TYPE_FLOAT:
                            add_code(CODE_PRINT_FLOAT, leftData, mk_compile_data(), mk_compile_data());
                            break;
                        case TYPE_BOOL:
                            add_code(CODE_PRINT_BOOL, leftData, mk_compile_data(), mk_compile_data());
                            break;
                        default:
                            printf("TYPE_VAR has incorrect op_type %d\n", left->op_type);
                            assert(0);
                            break;
                    }
                    
                    break;
                }
                case TYPE_INTEGER:
                    add_code(CODE_PRINT_INTEGER, leftData, mk_compile_data(), mk_compile_data());
                    break;
                case TYPE_FLOAT:
                    add_code(CODE_PRINT_FLOAT, leftData, mk_compile_data(), mk_compile_data());
                    break;
                case TYPE_BOOL:
                    add_code(CODE_PRINT_BOOL, leftData, mk_compile_data(), mk_compile_data());
                    break;
                default:
                    printf("TYPE_PRINT has left child that with bad type\n");
                    assert(0);
                    break;
            }
            
            add_code(CODE_PRINT_NEWLINE, mk_compile_data(), mk_compile_data(), mk_compile_data());
            break;
        case TYPE_VAR:
        case TYPE_INTEGER:
        case TYPE_FLOAT:
        case TYPE_BOOL:
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
        default:
            assert(0);
            break;
    }
}

// return number of the variable that contains the result
CompileData compile_exp(parse_node* node)
{
    CompileData returnData;
    returnData.type = CODE_VAL_REGISTER;
    returnData.data.ival = -1;
    if (node == NULL)
    {
        printf("compile_exp for NULL node");
        assert(0);
        return returnData;
    }
        
    parse_node* left = node->left;
    parse_node* right = node->right;
    
    switch (node->op_type)
    {
        case TYPE_NONE: // leaf value
            switch (node->type)
            {
                case TYPE_VAR: // need to use sval to get the variable pointer (or create it)
                {
                    int isFloat = 0;
                    symbol_entry* sym = get_symbol(node->data.sval);
                    if (sym && sym->type == TYPE_FLOAT)
                        isFloat = 1;
                        
                    returnData.type = CODE_VAL_REGISTER;
                    returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_SAVED;
                    returnData.data.ival = get_register_for_symbol(node);
                    return returnData;
                }
                case TYPE_INTEGER:
                case TYPE_BOOL:
                    returnData.type = CODE_VAL_INT_VALUE;
                    returnData.data.ival = node->data.ival;
                    return returnData;
                case TYPE_FLOAT:
                    returnData.type = CODE_VAL_FLOAT_VALUE;
                    returnData.data.fval = node->data.fval;
                    return returnData;
                default:
                    printf("Bad node type: %d\n", node->type);
                    assert(0);
                    break;
            }
            break;
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
        case TYPE_OP_BITWISE_AND:
        case TYPE_OP_BITWISE_OR:
        case TYPE_OP_LOGICAL_AND:
        case TYPE_OP_LOGICAL_OR:
        {
            CompileData leftData = compile_exp(left);
            CompileData rightData = compile_exp(right);
            
            int isFloat = 0;
            if (left->type == TYPE_FLOAT || right->type == TYPE_FLOAT)
                isFloat = 1;
            else if (left->type == TYPE_VAR)
            {
                symbol_entry* sym = get_symbol(left->data.sval);
                if (sym && sym->type == TYPE_FLOAT)
                    isFloat = 1;
            }
            
            // both nodes are values
            if (leftData.type != CODE_VAL_REGISTER && rightData.type != CODE_VAL_REGISTER)
            {
                returnData.type = isFloat ? CODE_VAL_FLOAT_VALUE : CODE_VAL_INT_VALUE;
                switch (node->op_type)
                {
                    case TYPE_OP_ADD:
                        if (isFloat)
                            returnData.data.fval = leftData.data.fval + rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival + rightData.data.ival;
                        break;
                    case TYPE_OP_SUB:
                        if (isFloat)
                            returnData.data.fval = leftData.data.fval - rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival - rightData.data.ival;
                        break;
                    case TYPE_OP_MUL:
                        if (isFloat)
                            returnData.data.fval = leftData.data.fval * rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival * rightData.data.ival;
                        break;
                    case TYPE_OP_DIV:
                        if (isFloat)
                        {
                            if (rightData.data.fval == 0)
                            {
                                printf("Error: division by zero");
                                exit(1);
                            }
                            
                            returnData.data.fval = leftData.data.fval / rightData.data.fval;
                        }
                        else
                        {
                            if (rightData.data.ival == 0)
                            {
                                printf("Error: division by zero");
                                exit(1);
                            }
                            
                            returnData.data.ival = leftData.data.ival / rightData.data.ival;
                        }
                        break;
                    case TYPE_OP_GT:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval > rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival > rightData.data.ival;
                        break;
                    case TYPE_OP_GE:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval >= rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival >= rightData.data.ival;
                        break;
                    case TYPE_OP_LT:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval < rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival < rightData.data.ival;
                        break;
                    case TYPE_OP_LE:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval <= rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival <= rightData.data.ival;
                        break;
                    case TYPE_OP_EQ:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval == rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival == rightData.data.ival;
                        break;
                    case TYPE_OP_NE:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval != rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival != rightData.data.ival;
                        break;
                    case TYPE_OP_BITWISE_AND:
                        returnData.data.ival = leftData.data.ival & rightData.data.ival;
                        break;
                    case TYPE_OP_BITWISE_OR:
                        returnData.data.ival = leftData.data.ival | rightData.data.ival;
                        break;
                    case TYPE_OP_LOGICAL_AND:
                        returnData.data.ival = leftData.data.ival && rightData.data.ival;
                        break;
                    case TYPE_OP_LOGICAL_OR:
                        returnData.data.ival = leftData.data.ival || rightData.data.ival;
                        break;
                    default:
                        assert(0);
                        break;
                }
                
                return returnData;
            }
            // one of the nodes is a value, another is a register
            else if (leftData.type != CODE_VAL_REGISTER || rightData.type != CODE_VAL_REGISTER)
            {
                CompileData* registerData = leftData.type == CODE_VAL_REGISTER ? &leftData : &rightData;
                CompileData* valueData = leftData.type != CODE_VAL_REGISTER ? &leftData : &rightData;
                
                int* destRegister = isFloat ? temp_float_register_counter : &temp_int_register_counter;
                CompileData destData = mk_compile_data();
                destData.type = CODE_VAL_REGISTER;
                destData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                destData.data.ival = *destRegister;
                
                switch (node->op_type)
                {
                    case TYPE_OP_ADD:
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_ADD_F : CODE_OP_ADD, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_SUB:
                        // b = 34 - a
                        // b = a + (-34)
                        if (valueData == &leftData)
                        {
                            if (isFloat)
                                valueData->data.fval *= -1;
                            else
                                valueData->data.ival *= -1;
                        }
                        
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_SUB_F : CODE_OP_SUB, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_MUL:
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_MUL_F : CODE_OP_MUL, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_DIV:
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        // order must be kept for division, we create a new register if needed for a direct value
                        else if (valueData == &leftData)
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, leftData, mk_compile_data());
                            leftData.type = CODE_VAL_REGISTER;
                            leftData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            leftData.data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_DIV_F : CODE_OP_DIV, destData, leftData, rightData);
                        break;
                    case TYPE_OP_GT:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, rightData, leftData);
                        break;
                    case TYPE_OP_GE:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, rightData, leftData);
                        break;
                    case TYPE_OP_LT:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LE:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_EQ:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SEQ_F : CODE_OP_SEQ, destData, leftData, rightData);
                        break;
                    case TYPE_OP_NE:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SNE_F : CODE_OP_SNE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_BITWISE_AND:
                        add_code(CODE_OP_BITWISE_AND, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_BITWISE_OR:
                        add_code(CODE_OP_BITWISE_OR, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_LOGICAL_AND:
                        add_code(CODE_OP_LOGICAL_AND, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_LOGICAL_OR:
                        add_code(CODE_OP_LOGICAL_OR, destData, *registerData, *valueData);
                        break;
                    default:
                        assert(0);
                        break;
                }
            
                returnData.type = CODE_VAL_REGISTER;
                returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                returnData.data.ival = *destRegister;
                ++(*destRegister);
                return returnData;
            }
            // both nodes are registers
            else
            {
                int* destRegister = isFloat ? temp_float_register_counter : &temp_int_register_counter;
                CompileData destData = mk_compile_data();
                destData.type = CODE_VAL_REGISTER;
                destData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                destData.data.ival = *destRegister;
                
                switch (node->op_type)
                {
                    case TYPE_OP_ADD:
                        add_code(isFloat ? CODE_OP_ADD_F : CODE_OP_ADD, destData, leftData, rightData);
                        break;
                    case TYPE_OP_SUB:
                        add_code(isFloat ? CODE_OP_SUB_F : CODE_OP_SUB, destData, leftData, rightData);
                        break;
                    case TYPE_OP_MUL:
                        add_code(isFloat ? CODE_OP_MUL_F : CODE_OP_MUL, destData, leftData, rightData);
                        break;
                    case TYPE_OP_DIV:
                        add_code(isFloat ? CODE_OP_DIV_F : CODE_OP_DIV, destData, leftData, rightData);
                        break;
                    case TYPE_OP_GT:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, rightData, leftData);
                        break;
                    case TYPE_OP_GE:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, rightData, leftData);
                        break;
                    case TYPE_OP_LT:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LE:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_EQ:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SEQ_F : CODE_OP_SEQ, destData, leftData, rightData);
                        break;
                    case TYPE_OP_NE:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SNE_F : CODE_OP_SNE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_BITWISE_AND:
                        add_code(CODE_OP_BITWISE_AND, destData, leftData, rightData);
                        break;
                    case TYPE_OP_BITWISE_OR:
                        add_code(CODE_OP_BITWISE_OR, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LOGICAL_AND:
                        add_code(CODE_OP_LOGICAL_AND, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LOGICAL_OR:
                        add_code(CODE_OP_LOGICAL_OR, destData, leftData, rightData);
                        break;
                    default:
                        assert(0);
                        break;
                }
                
                returnData.type = CODE_VAL_REGISTER;
                returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                returnData.data.ival = *destRegister;
                ++(*destRegister);
                return returnData;
            }
            break;
        }
        case TYPE_OP_NEG:
        case TYPE_OP_MINUS:
        {
            CompileData leftData = compile_exp(left);
            
            int isFloat = 0;
            if (left->type == TYPE_FLOAT)
                isFloat = 1;
            else if (left->type == TYPE_VAR)
            {
                symbol_entry* sym = get_symbol(left->data.sval);
                if (sym && sym->type == TYPE_FLOAT)
                    isFloat = 1;
            }
            
            // it's an immediate value
            if (leftData.type != CODE_VAL_REGISTER)
            {
                returnData.type = isFloat ? CODE_VAL_FLOAT_VALUE : CODE_VAL_INT_VALUE;
                if  (node->op_type == TYPE_OP_NEG)
                    returnData.data.ival = !leftData.data.ival;
                else if (node->op_type == TYPE_OP_MINUS)
                {
                    if (isFloat)
                        returnData.data.fval = -leftData.data.fval;
                    else
                        returnData.data.ival = -leftData.data.ival;
                }
            }
            else
            {
                int* destRegister = isFloat ? temp_float_register_counter : &temp_int_register_counter;
                returnData.type = CODE_VAL_REGISTER;
                returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                returnData.data.ival = *destRegister;
                (*destRegister)++; // increment the register counter, we're adding an additional operation here
                
                CompileData rightData = mk_compile_data();

                if (node->op_type == TYPE_OP_NEG)
                {
                    CompileData label1 = create_label();
                    CompileData label2 = create_label();
                    if (leftData.registerType == CODE_REGISTER_FLOAT)
                        leftData.registerType = CODE_REGISTER_TEMP;

                    add_code(CODE_OP_BEQ, leftData, mk_compile_data(), label1); // beq $var1, $zero, L1
                    rightData.type = CODE_VAL_INT_VALUE;
                    rightData.data.ival = 0;
                    add_code(CODE_OP_LI, returnData, rightData, mk_compile_data());
                    add_code(CODE_OP_JUMP, label2, mk_compile_data(), mk_compile_data());
                    add_code(CODE_OP_LABEL, label1, mk_compile_data(), mk_compile_data()); // label L1
                    rightData.type = CODE_VAL_INT_VALUE;
                    rightData.data.ival = 1;
                    add_code(CODE_OP_LI, returnData, rightData, mk_compile_data());
                    add_code(CODE_OP_LABEL, label2, mk_compile_data(), mk_compile_data()); // label L2
                }
                else if (node->op_type == TYPE_OP_MINUS)
                {
                    rightData.type = isFloat ? CODE_VAL_FLOAT_VALUE : CODE_VAL_INT_VALUE;
                    if (isFloat)
                        rightData.data.fval = -1;
                    else
                        rightData.data.ival = -1;
                    
                    add_code(isFloat ? CODE_OP_MUL_F : CODE_OP_MUL, returnData, leftData, rightData);
                }
            }
            return returnData;
        }
        default:
            assert(0);
            break;
    }
    
    return returnData;
}
    
const char* print_CompileData(CompileData data)
{
    if (data.type == CODE_VAL_NONE)
        return "<NULL>";
        
    #define MAX_FMT_STRING 10000
    static char temp_buffer[MAX_FMT_STRING];
    static char string[MAX_FMT_STRING];
    static int index = 0;
    char* buf;
    
    const char* varType = "";
    if (data.type == CODE_VAL_LABEL)
        varType = "L";
    else if (data.type == CODE_VAL_REGISTER)
    {
        if (data.registerType == CODE_REGISTER_SAVED)
            varType = "$s";
        else if (data.registerType == CODE_REGISTER_TEMP)
            varType = "$t";
        else // float?
            varType = "$f";
    }
    else if (data.type == CODE_VAL_FLOAT_MEMORY)
        varType = "fp";
        
    sprintf(temp_buffer, "%s%u", varType, data.data.ival);
    int len = strlen(temp_buffer);
    
    if (len + index >= MAX_FMT_STRING - 1)
        index = 0;
    
    buf = &string[index];
    memcpy(buf, temp_buffer, len + 1);

    index += len + 1;

    return buf;
}

void convert_code_to_mips()
{
    printf(".data\n");
    // default strings
    printf("__newline__:\t.asciiz\t\"\\n\"\n");
    printf("__bool_true__:\t.asciiz\t\"true\"\n");
    printf("__bool_false__:\t.asciiz\t\"false\"\n");
    
    print_float_variables();
    
    printf(".text\n");
    // default $f0 to zero, bloody MIPS doesn't allow $zero to be used
    printf("\tmtc1 $zero $f0\n");
	printf("\tcvt.s.w $f0, $f0\n");
    
    Code* code = firstCode;
    while (code != NULL)
    {
        const char* destStr = print_CompileData(code->dest);
        const char* val1Str = print_CompileData(code->val1);
        const char* val2Str = print_CompileData(code->val2);
    
        switch (code->op)
        {
            case CODE_OP_ASSIGN:
                printf("\tadd %s, %s, $zero\n", destStr, val1Str);
                break;
            case CODE_OP_ASSIGN_F:
                printf("\tadd.s %s, %s, $f0\n", destStr, val1Str);
                break;
            case CODE_OP_ADD:
                printf("\tadd %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_ADD_F:
                printf("\tadd.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SUB:
                printf("\tsub %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SUB_F:
                printf("\tsub.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_MUL:
                printf("\tmul %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_MUL_F:
                printf("\tmul.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_DIV:
                printf("\tdiv %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_DIV_F:
                printf("\tdiv.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_BEQ:
                printf("\tbeq %s, $zero, %s\n", destStr, val2Str);
                break;
            case CODE_OP_JUMP:
                printf("\tj %s\n", destStr);
                break;
            case CODE_OP_LABEL:
                printf("%s:\n", destStr);
                break;
            case CODE_OP_LI:
                printf("\tli %s, %s\n", destStr, val1Str);
                break;
            case CODE_OP_LI_F:
                printf("\tl.s %s, %s\n", destStr, val1Str);
                break;
            case CODE_OP_SLT:
                printf("\tslt %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SLT_F:
            {
                static slt_f_label = 0;
                printf("\tc.lt.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t slt_f_%u\n", slt_f_label);
                printf("\tli %s 0\n", destStr);
                printf("\tj slt_f_%u\n", slt_f_label + 1);
                printf("slt_f_%u:\n", slt_f_label);
                printf("\tli %s 1\n", destStr);
                printf("slt_f_%u:\n", slt_f_label + 1);
                slt_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_SLE:
                printf("\tsle %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SLE_F:
            {
                static sle_f_label = 0;
                printf("\tc.le.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t sle_f_%u\n", sle_f_label);
                printf("\tli %s 0\n", destStr);
                printf("\tj sle_f_%u\n", sle_f_label + 1);
                printf("sle_f_%u:\n", sle_f_label);
                printf("\tli %s 1\n", destStr);
                printf("sle_f_%u:\n", sle_f_label + 1);
                sle_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_SEQ:
                printf("\tseq %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SEQ_F:
            {
                static seq_f_label = 0;
                printf("\tc.eq.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t seq_f_%u\n", seq_f_label);
                printf("\tli %s 0\n", destStr);
                printf("\tj seq_f_%u\n", seq_f_label + 1);
                printf("seq_f_%u:\n", seq_f_label);
                printf("\tli %s 1\n", destStr);
                printf("seq_f_%u:\n", seq_f_label + 1);
                seq_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_SNE:
                printf("\tsne %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SNE_F:
            {
                static sne_f_label = 0;
                printf("\tc.eq.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t sne_f_%u\n", sne_f_label);
                printf("\tli %s 1\n", destStr); // values switched on purpose
                printf("\tj sne_f_%u\n", sne_f_label + 1);
                printf("sne_f_%u:\n", sne_f_label);
                printf("\tli %s 0\n", destStr); // values switched on purpose
                printf("sne_f_%u:\n", sne_f_label + 1);
                sne_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_BITWISE_AND:
                printf("\tand %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_BITWISE_OR:
                printf("\tor %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_LOGICAL_AND:
                printf("\tand %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_LOGICAL_OR:
                printf("\tor %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_PRINT_INTEGER:
                printf("\tli $v0, 1\n"); // print int code = 1
                printf("\tadd $a0, %s, $zero\n", destStr);
                printf("\tsyscall\n");
                break;
            case CODE_PRINT_FLOAT:
                printf("\tli $v0, 2\n"); // print float code = 2
                printf("\tadd.s $f12, %s, $f0\n", destStr);
                printf("\tsyscall\n");
                break;
            case CODE_PRINT_BOOL:
            {
                static int bool_label_counter = 0;
                int label1 = bool_label_counter++;
                int label2 = bool_label_counter++;
                
                printf("\tbeq %s, $zero, LBOOL%u\n", destStr, label1);
                
                // print if true
                printf("\tli $v0, 4\n"); // print string code = 4
                printf("\tla $a0, __bool_true__\n");
                printf("\tsyscall\n");
                // --
                
                printf("\tj LBOOL%u\n", label2);
                printf("LBOOL%u:\n", label1);
                
                // print if false
                printf("\tli $v0, 4\n"); // print string code = 4
                printf("\tla $a0, __bool_false__\n");
                printf("\tsyscall\n");
                // --
                
                printf("LBOOL%u:\n", label2);
                
                ++bool_label_counter;
                break;
            }
            case CODE_PRINT_NEWLINE:
                printf("\tli $v0, 4\n"); // print string code = 4
                printf("\tla $a0, __newline__\n");
                printf("\tsyscall\n");
                break;
            default:
                printf("Code op %d can't be converted to MIPS\n", code->op);
                assert(0);
                break;
        }
        
        code = code->next;
    }
}

int main() {
    int result = yyparse();
    if (result == 0)
        fprintf(stderr, "Parser: Success.\n");
    else
    {
        fprintf(stderr, "Parser: Error (%d).\n", result);
        return result;
    }
     
    // print_tree(root);
    
    compile(root);
    
    // print_symbol_table();
    
    convert_code_to_mips();
    
    // free up stuff
    free_parse_node(root); // delete the whole tree structure    
    while (symtable != NULL)
    {
        symbol_entry* ptr = symtable->next;
        free(symtable);
        symtable = ptr;
    }
    
    lastCode = NULL;
    while (firstCode != NULL)
    {
        Code* ptr = firstCode->next;
        free(firstCode);
        firstCode = ptr;
    }
    
    last_fp = NULL;
    while (first_fp != NULL)
    {
        FloatImmediate* ptr = first_fp->next;
        free(first_fp);
        first_fp = ptr;
    }
    return 0;
}
