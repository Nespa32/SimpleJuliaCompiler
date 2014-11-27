
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"

// global variable
symbol_entry* symtable = NULL;

symbol_entry* put_symbol(char* symname, int type)
{
    symbol_entry* ptr;
    ptr = (symbol_entry*)malloc(sizeof(symbol_entry));
    ptr->name = strdup(symname);
    ptr->type = type;
    ptr->next = (symbol_entry*)symtable;
    symtable = ptr;
    return ptr;
}

symbol_entry* get_symbol(char* symname)
{
    symbol_entry* ptr;
    for (ptr = symtable; ptr != (symbol_entry*)0; ptr = ptr->next)
    {
        if (strcmp(ptr->name, symname) == 0)
            return ptr;
    }

    return 0;
}
