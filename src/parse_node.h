
struct parser_node
{
    /* values */
    int type;
    
    struct parser_node* left;
    struct parser_node* right;
};

typedef struct parser_node parser_node;

extern parser_node* root;
