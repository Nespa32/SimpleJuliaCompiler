
struct parse_node
{
    /* values */
    int type;
    
    struct parse_node* left;
    struct parse_node* right;
    
    struct parse_node* next; // for list constructs
};

typedef struct parse_node parse_node;

/* functions involving parse_node */
parse_node* alloc_parse_node();
void free_parse_node(parse_node* node);

/* global variables */
extern parse_node* root;
