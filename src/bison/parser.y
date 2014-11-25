
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../symbol_table.h"
#include "../parse_node.h"

/* type of $$ in semantic actions */
// #define YYSTYPE parse_node*

/* @todo:
- else if chaining returns a parse error
*/

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
%token '(' ')'

%left '+' '-'
%left '*' '/'
%left '!'
%left '='

%start program
%%

program: /* empty */
       | program command        { printf("[program : program command] "); }
       | program command SEPARATOR { printf("[program : program command SEPARATOR] "); }
;

command : exp                   { printf("[command : exp] "); }
        | if_exp                { printf("[command : if_exp] "); }
        | while_exp             { printf("[command : while_exp] "); }    
;

exp: INTEGER                    { printf("[exp : INTEGER] ");
                                  $$.node = (parse_node*)malloc(sizeof(parse_node)); 
                                  $$.node->type = INTEGER; }
    | FLOAT                     { printf("[exp : FLOAT] "); }
    | exp op exp                { printf("[exp : exp op exp] "); }
    | '(' exp ')'               { printf("[exp : '(' exp ')'] "); }
    | exp '=' exp               { printf("[exp : exp '=' exp] "); }
;

op: '+' | '-' | '*' | '/' | '>' | '<'
;

if_exp: IF exp SEPARATOR exp_list elseif_list else_block END          { printf("[if_exp  ] "); }    
;

while_exp: WHILE exp SEPARATOR exp_list END
;

elseif_list: /* empty */
            elseif_list elseif_block
            
elseif_block: ELSEIF exp SEPARATOR exp_list     { printf("[elseif_block 2] "); }
;

else_block: /* empty */
    | ELSE SEPARATOR exp_list
;

exp_list: exp SEPARATOR         { printf("[exp_list : exp SEPARATOR] "); }
    | exp SEPARATOR exp_list    { printf("[exp_list : exp SEPARATOR exp_list] "); }              
;

%%

int yyerror(char *s) {
    printf("yyerror: %s\n", s);
    return 0;
}

int main() {
    int result = yyparse();
    if (result == 0)
        fprintf(stderr, "Parser: Success.\n");
    else
        fprintf(stderr, "Parser: Error (%d).\n", result);
     
    return 0;
}
