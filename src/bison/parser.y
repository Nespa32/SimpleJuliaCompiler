
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

parse_node* make_node(int type, parse_node* left, parse_node* right)
{
    parse_node* node = alloc_parse_node();
    node->type = type;
    node->left = left;
    node->right = right;
    return node;
}

int __parser_debug__ = 1; /* toggle for debug prints*/

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
    TYPE_ASSIGN,
    TYPE_IF,
    TYPE_WHILE,
    TYPE_ELSEIF,
    TYPE_ELSE,
    TYPE_PRINTLN,
    TYPE_CONNECTION_NODE, // compiles both 'left' and 'right' by default
};

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
%token TOKEN_PLUS TOKEN_SUB TOKEN_MUL TOKEN_DIV
%token TOKEN_GT TOKEN_LT TOKEN_GE TOKEN_LE TOKEN_NE TOKEN_EQ
%token '(' ')'

%left TOKEN_GT TOKEN_LT TOKEN_GE TOKEN_LE TOKEN_NE TOKEN_EQ
%left TOKEN_PLUS TOKEN_MINUS
%left TOKEN_MULT TOKEN_DIV
%left TOKEN_NEG
%left TOKEN_ASSIGN

%type<node> comm_list command if_comm while_comm var exp elseif_list elseif_block else_block
%type<ival> op

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

exp: TOKEN_INTEGER              { DEBUG_LOG("Reduce [TOKEN_INTEGER] to [exp]");
                                  $$ = make_node(TYPE_INTEGER, NULL, NULL);
                                  $$->data.ival = yylval.ival; }

    | TOKEN_FLOAT               { DEBUG_LOG("Reduce [TOKEN_FLOAT] to [exp]");
                                  $$ = make_node(TYPE_FLOAT, NULL, NULL);
                                  $$->data.fval = yylval.fval;}
                                  
    | bool                      { DEBUG_LOG("Reduce [bool] to [exp]");
                                  $$ = make_node(TYPE_BOOL, NULL, NULL);
                                  $$->data.ival = yylval.ival; }

    | var

    | exp op exp                { DEBUG_LOG("Reduce [exp op exp] to [exp]");  
                                  if ($1->type != $3->type) {
                                    DEBUG_LOG("ERROR: type mismatch - type of $1 is %d, type of $2 is %d\n", $1->type, $3->type);
                                    YYERROR;
                                  }
                                  
                                  int exp_type = $1->type;
                                  switch ($2) /* op */
                                  {
                                    case TYPE_OP_ADD:
                                    case TYPE_OP_SUB:
                                    case TYPE_OP_MUL:
                                    case TYPE_OP_DIV:
                                        if (exp_type != TYPE_INTEGER && exp_type != TYPE_FLOAT) {
                                            DEBUG_LOG("ERROR (1): bad type for op, type is %d\n", exp_type);
                                            YYERROR;
                                        }
                                        break;
                                    case TYPE_OP_GT:
                                    case TYPE_OP_GE:
                                    case TYPE_OP_LT:
                                    case TYPE_OP_LE:
                                        if (exp_type != TYPE_INTEGER && exp_type != TYPE_FLOAT) {
                                            DEBUG_LOG("ERROR (2): bad type for op, type is %d\n", exp_type);
                                            YYERROR;
                                        }
                                        
                                        exp_type = TYPE_BOOL;
                                        break;
                                    case TYPE_OP_EQ:
                                    case TYPE_OP_NE:
                                        exp_type = TYPE_BOOL;
                                        break;
                                    default:
                                        printf("Bad op type: %d", $2);
                                        assert(0);
                                        break;
                                  }
                                  
                                  $$ = make_node(exp_type, $1, $3);
                                  $$->op_type = $2; }

    | '(' exp ')'               { DEBUG_LOG("Reduce ['(' exp ')'] to [exp]");
                                  $$ = $2; }
;

op: TOKEN_PLUS                  { $$ = TYPE_OP_ADD; }
    | TOKEN_SUB                 { $$ = TYPE_OP_SUB; }
    | TOKEN_MUL                 { $$ = TYPE_OP_MUL; }
    | TOKEN_DIV                 { $$ = TYPE_OP_DIV; }
    | TOKEN_GT                  { $$ = TYPE_OP_GT; }
    | TOKEN_LT                  { $$ = TYPE_OP_LT; }
    | TOKEN_GE                  { $$ = TYPE_OP_GE; }
    | TOKEN_LE                  { $$ = TYPE_OP_LE; }
    | TOKEN_EQ                  { $$ = TYPE_OP_EQ; }
    | TOKEN_NE                  { $$ = TYPE_OP_NE; }
;

var: TOKEN_VAR                  { DEBUG_LOG("Reduce [TOKEN_VAR] to [var]");
                                  $$ = make_node(TYPE_VAR, NULL, NULL);
                                  $$->data.sval = yylval.sval; }

bool: TOKEN_TRUE
    | TOKEN_FALSE

if_comm: TOKEN_IF exp comm_list elseif_list else_block TOKEN_END  { 
                                                          DEBUG_LOG("Reduce [TOKEN_IF exp comm_list elseif_list else_block TOKEN_END] to [if_comm]");
                                                          if ($2->type != TYPE_BOOL) {
                                                            DEBUG_LOG("ERROR: type mismatch - type of $2 ($d) is not TYPE_BOOL", $2->type);
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

while_comm: TOKEN_WHILE exp comm_list TOKEN_END         { DEBUG_LOG("Reduce [TOKEN_WHILE exp comm_list TOKEN_END] to [while_comm]");
                                                          if ($2->type != TYPE_BOOL) {
                                                            DEBUG_LOG("ERROR: type mismatch - type of $2 ($d) is not TYPE_BOOL", $2->type);
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
        printf("Symbol - name: %s, type: %s\n", ptr->name, strForType(ptr->type));
        ptr = ptr->next;
    }
    printf("-- Symbol Table - End --\n");
}

int var_num = 0;

typedef enum
{
    CODE_OP_ASSIGN, // add $dest $reg1 $zero
    CODE_OP_ADD, // add $dest $reg1 $reg2
    CODE_OP_SUB, // sub $dest $reg1 $reg2
    CODE_OP_MUL, // mult $dest $reg1 $reg2
    CODE_OP_DIV, // div $dest $reg1 $reg2
    CODE_OP_BEQ, // branch equal @todo: fixme, used in cases that need BGE
    CODE_OP_JUMP, // jump $label
    CODE_OP_LABEL, // label $name
    CODE_OP_LI, // load immediate integer $dest $value
    CODE_OP_SLT, // set less than $dest $reg1 $reg2
    CODE_OP_SLE, // set less or equal than $dest $reg1 $reg2
    CODE_OP_SEQ, // set equal $dest $reg1 $reg2
    CODE_OP_SNE, // set not equal $dest $reg1 $reg2
    CODE_PRINT_INTEGER,
    CODE_PRINT_FLOAT,
    CODE_PRINT_BOOL,
    CODE_PRINT_NEWLINE,
} CodeOpType;

// @todo
struct Code
{
    CodeOpType op;
    int dest;
    int val1;
    int val2;
    struct Code* next;
};

typedef struct Code Code;

Code* firstCode = NULL;
Code* lastCode = NULL;

void add_code(CodeOpType op, int dest, int val1, int val2)
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
}

int create_label()
{
    static label_counter = 0;
    return label_counter++;
}

int register_counter = 0;

int get_register_for_symbol(symbol_entry* sym)
{
    if (sym->_register == -1)
        sym->_register = register_counter++;
        
    return sym->_register;
}

// possibly return a variable type
void compile(parse_node* node)
{
    if (node == NULL)
        return;

    parse_node* left = node->left;
    parse_node* right = node->right;
    
    int var1, var2; // for compile_exp use
    switch (node->type)
    {
        case TYPE_ASSIGN: // left is VAR, right is exp
            var1 = compile_exp(left);
            var2 = compile_exp(right);
            add_code(CODE_OP_ASSIGN, var1, var2, 0); // add $var1 $var2 $zero
            break;
        case TYPE_IF: // left: exp, right: comm_list, next for elseif/else blocks
        {
            int label2 = create_label();
            while (node != NULL)
            {
                left = node->left;
                right = node->right;

                if (node->type != TYPE_ELSE)
                {
                    var1 = compile_exp(left);
                    int label1 = create_label();
                    add_code(CODE_OP_BEQ, var1, 0, label1); // beq $var1, $zero, L1
                    compile(right);
                    add_code(CODE_OP_JUMP, label2, 0, 0);
                    add_code(CODE_OP_LABEL, label1, 0, 0); // label L1
                    node = node->next;
                }
                else /* if (node->type == TYPE_ELSE) */
                {
                    compile(left); // left: comm_list
                    assert(node->next == NULL);
                    break; // node with TYPE_ELSE should be the last of the list, no need for jump L2 either
                }
            }
            add_code(CODE_OP_LABEL, label2, 0, 0); // label L2
            break;
        }
        case TYPE_WHILE: // left: exp, right: comm_list
        {
            var1 = compile_exp(left);
            int label1 = create_label();
            add_code(CODE_OP_LABEL, label1, 0, 0); // make label L1
            int label2 = create_label();
            add_code(CODE_OP_BEQ, var1, 0, label2); // beq $var1, $zero, L2
            compile(right);
            add_code(CODE_OP_JUMP, label1, 0, 0); // make j L1
            add_code(CODE_OP_LABEL, label2, 0, 0); // make label L2
            break;
        }
        case TYPE_CONNECTION_NODE:
            compile(left);
            compile(right);
            break;
        case TYPE_PRINTLN:
            assert(right == NULL);
            var1 = compile_exp(left);
            switch (left->type)
            {
                case TYPE_VAR:
                {
                    symbol_entry* var_sym = get_symbol(left->data.sval);
                    switch (var_sym->type)
                    {
                        case TYPE_INTEGER:
                            add_code(CODE_PRINT_INTEGER, var1, 0, 0);
                            break;
                        case TYPE_FLOAT:
                            add_code(CODE_PRINT_FLOAT, var1, 0, 0);
                            break;
                        case TYPE_BOOL:
                            add_code(CODE_PRINT_BOOL, var1, 0, 0);
                            break;
                        default:
                            printf("TYPE_VAR has incorrect op_type %d\n", left->op_type);
                            assert(0);
                            break;
                    }
                    
                    break;
                }
                case TYPE_INTEGER:
                    add_code(CODE_PRINT_INTEGER, var1, 0, 0);
                    break;
                case TYPE_FLOAT:
                    add_code(CODE_PRINT_FLOAT, var1, 0, 0);
                    break;
                case TYPE_BOOL:
                    add_code(CODE_PRINT_BOOL, var1, 0, 0);
                    break;
                default:
                    printf("TYPE_PRINT has left child that with bad type\n");
                    assert(0);
                    break;
            }
            
            add_code(CODE_PRINT_NEWLINE, 0, 0, 0);
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
int compile_exp(parse_node* node)
{
    if (node == NULL)
        return -1;
        
    parse_node* left = node->left;
    parse_node* right = node->right;
    
    int var1, var2; // for compile_exp use
    symbol_entry* var_sym; // for variable use
    switch (node->op_type)
    {
        case TYPE_NONE: // leaf value
            switch (node->type)
            {
                case TYPE_VAR: // need to use sval to get the variable pointer (or create it)
                    var_sym = get_symbol(node->data.sval);
                    // @todo: somehow get an existing variable from var_sym or make a new one if it doesn't exist
                    return get_register_for_symbol(var_sym);
                case TYPE_INTEGER:
                case TYPE_BOOL:
                    // make li $register $value
                    add_code(CODE_OP_LI, register_counter, node->data.ival, 0);
                    return register_counter++;
                case TYPE_FLOAT:
                    // make li.s $register $value
                    // add_code(CODE_OP_LI, register_counter, node->data.fval);
                    return register_counter++;
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
            var1 = compile_exp(left);
            var2 = compile_exp(right);
            
            switch (node->op_type)
            {
                case TYPE_OP_ADD:
                    add_code(CODE_OP_ADD, register_counter, var1, var2);
                    break;
                case TYPE_OP_SUB:
                    add_code(CODE_OP_SUB, register_counter, var1, var2);
                    break;
                case TYPE_OP_MUL:
                    add_code(CODE_OP_MUL, register_counter, var1, var2);
                    break;
                case TYPE_OP_DIV:
                    add_code(CODE_OP_DIV, register_counter, var1, var2);
                    break;
                case TYPE_OP_GT:
                    add_code(CODE_OP_SLT, register_counter, var2, var1);
                    break;
                case TYPE_OP_GE:
                    add_code(CODE_OP_SLE, register_counter, var2, var1);
                    break;
                case TYPE_OP_LT:
                    add_code(CODE_OP_SLT, register_counter, var1, var2);
                    break;
                case TYPE_OP_LE:
                    add_code(CODE_OP_SLE, register_counter, var1, var2);
                    break;
                case TYPE_OP_EQ:
                    add_code(CODE_OP_SEQ, register_counter, var1, var2);
                    break;
                case TYPE_OP_NE:
                    add_code(CODE_OP_SNE, register_counter, var1, var2);
                    break;
                default:
                    assert(0);
                    break;
            }
            
            return register_counter++;
        default:
            assert(0);
            break;
    }
    
    return -1;
}
    
void convert_code_to_mips()
{
    printf(".data\n");
    // default strings
    printf("__newline__:\t.asciiz\t\"\\n\"\n");
    printf("__bool_true__:\t.asciiz\t\"true\"\n");
    printf("__bool_false__:\t.asciiz\t\"false\"\n");
    
    printf(".text\n");
    
    Code* code = firstCode;
    while (code != NULL)
    {
        switch (code->op)
        {
            case CODE_OP_ASSIGN:
                printf("\tadd $t%u, $t%u, $zero\n", code->dest, code->val1);
                break;
            case CODE_OP_ADD:
                printf("\tadd $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_SUB:
                printf("\tsub $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_MUL:
                printf("\tmul $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_DIV:
                printf("\tdiv $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_BEQ:
                printf("\tbeq $t%u, $zero, L%u\n", code->dest, code->val2);
                break;
            case CODE_OP_JUMP:
                printf("\tj L%u\n", code->dest);
                break;
            case CODE_OP_LABEL:
                printf("L%u:\n", code->dest);
                break;
            case CODE_OP_LI:
                printf("\tli $t%u, %u\n", code->dest, code->val1);
                break;
            case CODE_OP_SLT:
                printf("\tslt $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_SLE:
                printf("\tsle $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_SEQ:
                printf("\tseq $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_OP_SNE:
                printf("\tsne $t%u, $t%u, $t%u\n", code->dest, code->val1, code->val2);
                break;
            case CODE_PRINT_INTEGER:
                printf("\tli $v0, 1\n"); // print int code = 1
                printf("\tadd $a0, $t%u, $zero\n", code->dest);
                printf("\tsyscall\n");
                break;
            case CODE_PRINT_FLOAT:
                printf("\tli $v0, 3\n"); // print double code = 3
                printf("\tadd.d $f12, $f%u, $zero\n", code->dest);
                printf("\tsyscall\n");
                break;
            case CODE_PRINT_BOOL:
                break;
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
    // print_symbol_table();
    
    compile(root);
    
    convert_code_to_mips();
    
    // free up stuff
    free_parse_node(root); // delete the whole tree structure    
    while (symtable  != NULL)
    {
        symbol_entry* ptr = symtable->next;
        free(symtable);
        symtable = ptr;
    }
    return 0;
}
