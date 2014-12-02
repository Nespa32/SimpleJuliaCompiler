
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
        if (__parser_debug__  != 0)     \
            printf(__VA_ARGS__);        \
    } while (0)

/* @todo:
- else if chaining returns a parse error
*/

enum {
    TYPE_NONE,
    TYPE_VAR,
    TYPE_INTEGER,
    TYPE_FLOAT,
    TYPE_STRING,
    TYPE_OP,
    TYPE_ASSIGN,
    TYPE_IF,
    TYPE_WHILE,
    TYPE_ELSEIF,
    TYPE_ELSE,
    TYPE_OTHER,
};

%}

%union {
    char* id; /* identifiers */
    char* sval; /* strings */
    int ival; /* integers */
    double fval; /* floats/doubles */
    parse_node* node; /* node for tree structure */
}

%token <ival> BOOL
%token <ival> INTEGER
%token <fval> FLOAT
%token <sval> STRING VAR
%token <node> SEPARATOR IF WHILE ELSEIF ELSE END
%token PRINTLN
%token '=' ';'
%token '+' '-' '*' '/'
%token '>' '<'
%token '(' ')'

%left '>' '<'
%left '+' '-'
%left '*' '/'
%left '!'
%left '='

%type<node> comm_list command if_comm while_comm var exp elseif_list elseif_block else_block

%start program
%%

program : comm_list             { root = $1; }
;

comm_list : command             { DEBUG_LOG("Reduce [command] to [comm_list]\n");
                                  $$ = $1; }

        | command comm_list     { DEBUG_LOG("Reduce [command comm_list] to [comm_list]\n"); 
                                  $$ = make_node(TYPE_OTHER, $1, $2); }
;

command : if_comm               { DEBUG_LOG("Reduce [if_comm] to [command]\n");
                                  $$ = $1; }

        | while_comm            { DEBUG_LOG("Reduce [while_comm] to [command]\n");
                                  $$ = $1; }

        | var '=' exp           { DEBUG_LOG("Reduce [var '=' exp] to [command]\n");
                                  put_symbol($1->data.sval, $3->type);
                                  $$ = make_node(TYPE_ASSIGN, $1, $3); }
;

exp: INTEGER                    { DEBUG_LOG("Reduce [INTEGER] to [exp]\n");
                                  $$ = make_node(TYPE_INTEGER, NULL, NULL);
                                  $$->data.ival = yylval.ival; }

    | FLOAT                     { DEBUG_LOG("Reduce [FLOAT] to [exp]\n");
                                  $$ = make_node(TYPE_FLOAT, NULL, NULL);
                                  $$->data.fval = yylval.fval;}

    | var
                                  
    | STRING                    { DEBUG_LOG("Reduce [STRING] to [exp]\n");
                                  $$ = make_node(TYPE_STRING, NULL, NULL);
                                  $$->data.sval = yylval.sval; }   

    | exp op exp                { DEBUG_LOG("Reduce [exp op exp] to [exp]\n");
                                  if ($1->type != $3->type) {
                                    DEBUG_LOG("ERROR: type mismatch (1) \n");
                                    YYERROR;
                                  }
                                  $$ = make_node(TYPE_OP, $1, $3); }

    | '(' exp ')'               { DEBUG_LOG("Reduce ['(' exp ')'] to [exp]\n");
                                  $$ = $2; }
;

op: '+' | '-' | '*' | '/' | '>' | '<'
;

var: VAR                        { DEBUG_LOG("Reduce [VAR] to [var]\n");
                                  $$ = make_node(TYPE_VAR, NULL, NULL);
                                  $$->data.sval = yylval.sval; }

if_comm: IF exp comm_list elseif_list else_block END    { DEBUG_LOG("Reduce [IF exp comm_list elseif_list else_block END] to [if_comm]\n");
                                                          /* if ($2->type != BOOL) {
                                                            DEBUG_LOG("ERROR: type mismatch (1) \n");
                                                            YYERROR;
                                                          } */
                                                        
                                                          $$ = make_node(TYPE_IF, $2, $3);
                                                          $$->next = make_node(TYPE_OTHER, $4, $5); }
;

while_comm: WHILE exp comm_list END                     { DEBUG_LOG("Reduce [IF exp comm_list elseif_list else_block END] to [if_comm]\n");
                                                          /* if ($2->type != BOOL) {
                                                            DEBUG_LOG("ERROR: type mismatch (1) \n");
                                                            YYERROR;
                                                          } */
                                                          
                                                          $$ = make_node(TYPE_WHILE, $2, $3); }
;

elseif_list: /* empty */                { $$ = NULL; }            
           | elseif_list elseif_block   { $$ = make_node(TYPE_OTHER, $1, $2); }
;
            
elseif_block: ELSEIF exp comm_list      { $$ = make_node(TYPE_ELSEIF, $2, $3); }
;

else_block: /* empty */                 { $$ = NULL; }
    | ELSE comm_list                    { $$ = make_node(TYPE_ELSE, $2, NULL); }
;

%%

int yyerror(char *s) {
    printf("yyerror: %s\n", s);
    return 0;
}

int spaces = 0;

const char* strForType(int type)
{
    switch (type)
    {
        case TYPE_VAR: return "TYPE_VAR";
        case TYPE_INTEGER: return "TYPE_INTEGER";
        case TYPE_FLOAT: return "TYPE_FLOAT";
        case TYPE_STRING: return "TYPE_STRING";
        case TYPE_OP: return "TYPE_OP";
        case TYPE_ASSIGN: return "TYPE_ASSIGN";
        case TYPE_IF: return "TYPE_IF";
        case TYPE_WHILE: return "TYPE_WHILE";
        case TYPE_ELSEIF: return "TYPE_ELSEIF";
        case TYPE_ELSE: return "TYPE_ELSE";
        case TYPE_OTHER: return "TYPE_OTHER";
    }
    return TYPE_NONE; // shitty compilers (like this one) might complain
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
        case TYPE_STRING:
            sprintf(valStr, "%s", node->data.sval);
            break;
        case TYPE_INTEGER:
            sprintf(valStr, "%d", node->data.ival);
            break;
        case TYPE_FLOAT:
            sprintf(valStr, "%f", node->data.fval);
            break;
        case TYPE_OP:
        case TYPE_ASSIGN:
        case TYPE_IF:
        case TYPE_WHILE:
        case TYPE_ELSEIF:
        case TYPE_ELSE:
        case TYPE_OTHER:
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
    print_tree(next);
    --spaces;
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

// @todo
struct Code
{
    int op;
    int dest;
    int val1;
    int val2;
};

typedef struct Code Code;

// possibly return a variable type
void compile(parse_node* node)
{
    switch (node->type)
    {
        case TYPE_VAR:
        case TYPE_INTEGER:
        case TYPE_FLOAT:
        case TYPE_STRING:
        case TYPE_OP:
        case TYPE_ASSIGN:
        case TYPE_IF:
        case TYPE_WHILE:
        case TYPE_ELSEIF:
        case TYPE_ELSE:
        case TYPE_OTHER:
        default:
            break;
    }
}

// return number of the variable that contains the result
int compile_exp(parse_node* node)
{

}

int main() {
    int result = yyparse();
    if (result == 0)
        fprintf(stderr, "Parser: Success.\n");
    else
        fprintf(stderr, "Parser: Error (%d).\n", result);
     
    print_tree(root);
    print_symbol_table();
    
    compile(root);
    
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
