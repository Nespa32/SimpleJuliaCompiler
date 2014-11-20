
%{
#include <stdio.h>
#include <stdlib.h>
%} 

%start Program
%%

Program: 


%%

int yyerror(char *s) {
    printf("yyerror: %s\n", s);
    return 0;
}

int main() {
    if (yyparse())
        fprintf(stderr, "Parser: Success.\n");
    else
        fprintf(stderr, "Parser: Error.\n");
     
    return 0;
}
