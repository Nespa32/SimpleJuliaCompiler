
%{

#include "../main.h"

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


