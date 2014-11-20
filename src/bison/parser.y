
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* type of $$ in semantic actions */
/* #define YYSTYPE double */
%} 

%union {
    char* id; /* identifiers */
    char* sval; /* strings */
    int ival; /* integers */
    double fval; /* floats/doubles */
}

%token INTEGER FLOAT BOOL STRING
%token SEPARATOR IF WHILE ELSEIF ELSE END
%token PRINTLN
%token <id> VAR_OR_FN
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

exp: INTEGER                    { printf("[exp : INTEGER] "); }
    | FLOAT                     { printf("[exp : FLOAT] "); }
    | exp op exp                { printf("[exp : exp op exp] "); }
    | '(' exp ')'               { printf("[exp : '(' exp ')'] "); }
    | exp '=' exp               { printf("[exp : exp '=' exp] "); }
;

op: '+' | '-' | '*' | '/' | '>' | '<'
;

if_exp: IF exp SEPARATOR exp_list elseif_block else_block END          { printf("[if_exp  ] "); }    
;

while_exp: WHILE exp SEPARATOR exp_list END
;

elseif_block: /* empty */
    | ELSEIF exp SEPARATOR exp_list
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
