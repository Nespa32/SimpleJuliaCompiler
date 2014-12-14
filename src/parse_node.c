
#include <stdlib.h>
#include "parse_node.h"

// global variable
parse_node* root = (parse_node*)0;

parse_node* alloc_parse_node()
{
    parse_node* node = (parse_node*)malloc(sizeof(parse_node));
    node->type = 0;
    node->op_type = 0;
    node->left = NULL;
    node->right = NULL;
    node->next = NULL;
    return node;
}

void free_parse_node(parse_node* node)
{
    if (node == NULL)
        return;

    parse_node* left = node->left;
    parse_node* right = node->right;
    parse_node* next = node->next;
    free(node);
    free_parse_node(left);
    free_parse_node(right);
    free_parse_node(next);
}