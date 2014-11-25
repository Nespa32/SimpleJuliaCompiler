/* SYMBOL TABLE */
struct symbol_entry
{
    char* name;
    int type;
    struct symbol_entry* next;
};

typedef struct symbol_entry symbol_entry;

/* functions */
symbol_entry* put_symbol(char* symname, int type);
symbol_entry* get_symbol(char* symname);

/* global variable */
extern symbol_entry* symtable;

