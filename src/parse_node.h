
struct parse_node
{
    /* values */
    int type;
    
    struct parse_node* left;
    struct parse_node* right;
};

typedef struct parse_node parse_node;

extern parse_node* root;
