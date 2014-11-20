
%{
#include <stdio.h>
#include <stdlib.h>
%} 

%token INTEGER FLOAT BOOL
%token SEPARATOR IF WHILE ELSEIF ELSE END
%token PRINTLN VAR_OR_FN
%token '=' ';'
%token '+' '-' '*' '/'
%token '(' ')'

%left '+' '-'
%left '*' '/'
%left '!'

%start program
%%

program: /* empty */
       | program command        { printf("[program : program command] "); }
;

command : exp                   { printf("[command : exp] "); }
        | if_exp                { printf("[command : if_exp] "); }
        | while_exp             { printf("[command : while_exp] "); }    
;

exp: INTEGER                    { printf("[exp : INTEGER] "); }
    | FLOAT                     { printf("[exp : FLOAT] "); }
    | exp op exp                { printf("[exp : exp op exp] "); }
    | '(' exp ')'               { printf("[exp : '(' exp ')'] "); }
;

op: '+' | '-' | '*' | '/' | '>' | '<'
;

if_exp: IF exp exp END          { printf("[if_exp : IF exp exp END] "); }    
;

while_exp: WHILE exp exp END
;

elseif: /* empty */
    | ELSEIF exp exp
;

else: /* empty */
    | ELSE exp_list
;

exp_list: exp
    | exp exp_list
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
