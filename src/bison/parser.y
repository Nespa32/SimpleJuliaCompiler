
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
%token <sval> STRING
%token <node> SEPARATOR IF WHILE ELSEIF ELSE END
%token PRINTLN
%token <id> VAR
%token '=' ';'
%token '+' '-' '*' '/'
%token '>' '<'
%token '(' ')'

%left '>' '<'
%left '+' '-'
%left '*' '/'
%left '!'
%left '='

%type<node> comm_list command if_exp while_exp exp exp_list elseif_list elseif_block else_block

%start program
%%

program : comm_list             { root = $1; }
;

comm_list : command             { DEBUG_LOG("Reduce [command] to [comm_list]\n");
                                  $$ = $1; }

        | command comm_list     { DEBUG_LOG("Reduce [command comm_list] to [comm_list]\n"); 
                                  $$ = make_node(0 /* @todo: give proper type */, $1, $2); }
;

command : if_exp                { DEBUG_LOG("Reduce [if_exp] to [command]\n");
                                  $$ = $1; }

        | while_exp             { DEBUG_LOG("Reduce [while_exp] to [command]\n");
                                  $$ = $1; }

        | exp                   { DEBUG_LOG("Reduce [exp] to [command]\n");
                                  $$ = $1; }
;

exp: INTEGER                    { DEBUG_LOG("Reduce [INTEGER] to [exp]\n");
                                  $$ = make_node(INTEGER, NULL, NULL);
                                  $$->data.ival = yylval.ival; }

    | FLOAT                     { DEBUG_LOG("Reduce [FLOAT] to [exp]\n");
                                  $$ = make_node(FLOAT, NULL, NULL);
                                  $$->data.fval = yylval.fval;}

    | exp op exp                { DEBUG_LOG("Reduce [exp op exp] to [exp]\n");
                                  if ($1->type != $3->type) {
                                    DEBUG_LOG("ERROR: type mismatch (1) \n");
                                    YYERROR;
                                  }
                                  $$ = make_node($1->type, $1, $3); }

    | '(' exp ')'               { DEBUG_LOG("Reduce ['(' exp ')'] to [exp]\n");
                                  $$ = $2; }
    
    | exp '=' exp               { DEBUG_LOG("Reduce [exp '=' exp] to [exp]\n");
                                  if ($1->type != $3->type) {
                                    DEBUG_LOG("ERROR: type mismatch (1) \n");
                                    YYERROR;
                                  }
                                  $$ = make_node($1->type, $1, $3); }
;

op: '+' | '-' | '*' | '/' | '>' | '<'
;

if_exp: IF exp exp_list elseif_list else_block END      { DEBUG_LOG("Reduce [IF exp exp_list elseif_list else_block END] to [if_exp]\n");
                                                          /* if ($2->type != BOOL) {
                                                            DEBUG_LOG("ERROR: type mismatch (1) \n");
                                                            YYERROR;
                                                          } */
                                                        
                                                          $$ = make_node(0 /* @todo: give proper type */, $2, $3);
                                                          $$->next = make_node(0 /* @todo: give proper type */, $4, $5); }
;

while_exp: WHILE exp exp_list END                       { DEBUG_LOG("Reduce [IF exp exp_list elseif_list else_block END] to [if_exp]\n");
                                                          /* if ($2->type != BOOL) {
                                                            DEBUG_LOG("ERROR: type mismatch (1) \n");
                                                            YYERROR;
                                                          } */
                                                          
                                                          $$ = make_node(0 /* @todo: give proper type */, $2, $3); }
;

elseif_list: /* empty */                { $$ = NULL; }            
           | elseif_list elseif_block   { $$ = make_node(0 /* @todo: give proper type */, $1, $2); }
;
            
elseif_block: ELSEIF exp exp_list       { $$ = make_node(0 /* @todo: give proper type */, $2, $3); }
;

else_block: /* empty */                 { $$ = NULL; }
    | ELSE exp_list                     { $$ = $2; }
;

exp_list: exp                           { DEBUG_LOG("Reduce [exp] to [exp_list]\n");
                                          $$ = $1; }

    | exp_list sep exp                  { DEBUG_LOG("Reduce [exp_list exp] to [exp_list]\n");
                                          $$ = make_node(0 /* @todo: give proper type */, $1, $3); }
;

sep : /* empty */                       { }
    | SEPARATOR

%%

int yyerror(char *s) {
    printf("yyerror: %s\n", s);
    return 0;
}

int spaces = 0;

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
    
    char* typeStr;
    char valStr[20];
    switch (node->type)
    {
        case INTEGER:
            typeStr = "INTEGER";
            sprintf(valStr, "%d", node->data.ival);
            break;
        case FLOAT:
            typeStr = "FLOAT";
            sprintf(valStr, "%f", node->data.fval);
            break;
        case STRING:
            typeStr = "STRING";
            sprintf(valStr, "%s", node->data.sval);
            break;
        case VAR:
            typeStr = "VAR";
            sprintf(valStr, "%s", node->data.sval);
            break;
        default:
            typeStr = "UNK";
            sprintf(valStr, "None");
            break;
    }

    printf(" [Node] Type: %s, Val: %s, Left: %s, Right: %s, Next: %s\n",
        typeStr,
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

int main() {
    int result = yyparse();
    if (result == 0)
        fprintf(stderr, "Parser: Success.\n");
    else
        fprintf(stderr, "Parser: Error (%d).\n", result);
     
    print_tree(root);
    free_parse_node(root); // delete the whole tree structure
    return 0;
}
