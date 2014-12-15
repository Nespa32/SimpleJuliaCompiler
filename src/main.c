 
#include "main.h"
/* needed for token enum */
#include "bison/parser.tab.h"

Code* firstCode = NULL;
Code* lastCode = NULL;

int label_counter = 0;
int symbol_int_register_counter = 0;
int symbol_float_register_counter = 1;
int temp_int_register_counter = 0;
int* temp_float_register_counter = &symbol_float_register_counter;

FloatImmediate* first_fp = NULL;
FloatImmediate* last_fp = NULL;
int fp_counter = 0;

const char* strForType(int type)
{
    switch (type)
    {
        case TYPE_VAR: return "TYPE_VAR";
        case TYPE_INTEGER: return "TYPE_INTEGER";
        case TYPE_FLOAT: return "TYPE_FLOAT";
        case TYPE_BOOL: return "TYPE_BOOL";
        case TYPE_OP_ADD: return "TYPE_OP_ADD";
        case TYPE_OP_SUB: return "TYPE_OP_SUB";
        case TYPE_OP_MUL: return "TYPE_OP_MUL";
        case TYPE_OP_DIV: return "TYPE_OP_DIV";
        case TYPE_OP_GT: return "TYPE_OP_GT";
        case TYPE_OP_GE: return "TYPE_OP_GE";
        case TYPE_OP_LT: return "TYPE_OP_LT";
        case TYPE_OP_LE: return "TYPE_OP_LE";
        case TYPE_OP_EQ: return "TYPE_OP_EQ";
        case TYPE_OP_NE: return "TYPE_OP_NE";
        case TYPE_OP_BITWISE_AND: return "TYPE_OP_BITWISE_AND";
        case TYPE_OP_BITWISE_OR: return "TYPE_OP_BITWISE_OR";
        case TYPE_OP_LOGICAL_AND: return "TYPE_OP_LOGICAL_AND";
        case TYPE_OP_LOGICAL_OR: return "TYPE_OP_LOGICAL_OR";
        case TYPE_OP_NEG: return "TYPE_OP_NEG";
        case TYPE_OP_MINUS: return "TYPE_OP_MINUS";
        case TYPE_ASSIGN: return "TYPE_ASSIGN";
        case TYPE_IF: return "TYPE_IF";
        case TYPE_WHILE: return "TYPE_WHILE";
        case TYPE_ELSEIF: return "TYPE_ELSEIF";
        case TYPE_ELSE: return "TYPE_ELSE";
        case TYPE_CONNECTION_NODE: return "TYPE_CONNECTION_NODE";
    }

    return "<undefined>"; // shitty compilers (like this one) might complain
}

void print_tree(parse_node* node)
{
    if (node == NULL)
        return;

    static int spaces = 1;
    
    int i = 0;
    for (; i < spaces; ++i)
        printf("-");
    
    parse_node* left = node->left;
    parse_node* right = node->right;
    parse_node* next = node->next;
    
    char valStr[20];
    switch (node->type)
    {
        case TYPE_VAR:
            sprintf(valStr, "%s", node->data.sval);
            break;
        case TYPE_INTEGER:
            sprintf(valStr, "%d", node->data.ival);
            break;
        case TYPE_FLOAT:
            sprintf(valStr, "%f", node->data.fval);
            break;
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
        case TYPE_ASSIGN:
        case TYPE_IF:
        case TYPE_WHILE:
        case TYPE_ELSEIF:
        case TYPE_ELSE:
        case TYPE_CONNECTION_NODE:
        default:
            sprintf(valStr, "None");
            break;
    }

    printf(" [Node] Type: %s, Val: %s, Left: %s, Right: %s, Next: %s\n",
        strForType(node->type),
        valStr,
        left ? "Yes" : "No",
        right ? "Yes" : "No",
        next ? "Yes" : "No");

    ++spaces;
    print_tree(left);
    print_tree(right);
    --spaces;
    
    print_tree(next);
}

void print_symbol_table()
{
    printf("-- Symbol Table - Start --\n");
    symbol_entry* ptr = symtable;
    while (ptr != NULL)
    {
        printf("Symbol - name: %s, type: %s, register: %u\n", ptr->name, strForType(ptr->type), ptr->_register);
        ptr = ptr->next;
    }
    printf("-- Symbol Table - End --\n");
}

CompileData mk_compile_data()
{
    CompileData data;
    data.type = CODE_VAL_NONE;
    data.registerType = CODE_REGISTER_NONE;
    data.data.ival = 0;
    return data;
}

CompileData create_label()
{
    CompileData data = mk_compile_data();
    data.type = CODE_VAL_LABEL;
    data.data.ival = label_counter++;
    return data;
}

void add_code(CodeOpType op, CompileData dest, CompileData val1, CompileData val2)
{
    Code* c = (Code*)malloc(sizeof(Code));
    if (firstCode == NULL)
    {
        firstCode = c;
        lastCode = c;
    }
    else
    {
        lastCode->next = c;
        lastCode = c;
    }
    
    c->op = op;
    c->dest = dest;
    c->val1 = val1;
    c->val2 = val2;
    c->next = NULL;
    
    if (op == CODE_OP_LI_F)
    {
        // the hacks we do for love
        int id = add_fp(c->val1.data.fval);
        c->val1.type = CODE_VAL_FLOAT_MEMORY;
        c->val1.registerType = CODE_REGISTER_NONE;
        c->val1.data.ival = id;
    }
}

int add_fp(float value)
{
    FloatImmediate* fp = (FloatImmediate*)malloc(sizeof(FloatImmediate));
    if (first_fp == NULL)
    {
        first_fp = fp;
        last_fp = fp;
    }
    else
    {
        last_fp->next = fp;
        last_fp = fp;
    }
    
    fp->id = fp_counter++;
    fp->value = value;
    fp->next = NULL;
    return fp->id;
}

void print_float_variables()
{
    FloatImmediate* fp = first_fp;
    while (fp != NULL)
    {
        printf("fp%u:\t.float\t%f\n", fp->id, fp->value);
        fp = fp->next;
    }
}

int get_register_for_symbol(parse_node* node)
{
    symbol_entry* sym = get_symbol(node->data.sval);
    if (!sym)
    {
        printf("Var %s not initialized! Exiting!\n", node->data.sval);
        exit(1);
    }
    
    if (sym->_register == -1)
        sym->_register = sym->type == TYPE_FLOAT ? symbol_float_register_counter++ : symbol_int_register_counter++;
        
    return sym->_register;
}

// possibly return a variable type
void compile(parse_node* node)
{
    if (node == NULL)
        return;

    parse_node* left = node->left;
    parse_node* right = node->right;
    
    CompileData leftData;
    CompileData rightData;
    switch (node->type)
    {
        case TYPE_ASSIGN: // left is VAR, right is exp
            leftData = compile_exp(left);
            rightData = compile_exp(right);
            if (rightData.type != CODE_VAL_REGISTER) // needs to be a register
            {
                CompileData destData = mk_compile_data();
                int* destRegister = right->type == TYPE_FLOAT ? temp_float_register_counter : &temp_int_register_counter;
                destData.type = CODE_VAL_REGISTER;
                destData.registerType = right->type == TYPE_FLOAT ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                destData.data.ival = (*destRegister)++;
                add_code(right->type == TYPE_FLOAT ? CODE_OP_LI_F : CODE_OP_LI, destData, rightData, mk_compile_data());
                rightData = destData;
            }
            
            add_code(right->type == TYPE_FLOAT ? CODE_OP_ASSIGN_F : CODE_OP_ASSIGN, leftData, rightData, mk_compile_data()); // add $var1 $var2 $zero
            break;
        case TYPE_IF: // left: exp, right: comm_list, next for elseif/else blocks
        {
            CompileData label2 = create_label();
            while (node != NULL)
            {
                left = node->left;
                right = node->right;

                if (node->type != TYPE_ELSE)
                {
                    leftData = compile_exp(left);
                    CompileData label1 = create_label();
                    if (leftData.registerType == CODE_REGISTER_FLOAT)
                        leftData.registerType = CODE_REGISTER_TEMP;

                    add_code(CODE_OP_BEQ, leftData, mk_compile_data(), label1); // beq $var1, $zero, L1
                    compile(right);
                    add_code(CODE_OP_JUMP, label2, mk_compile_data(), mk_compile_data());
                    add_code(CODE_OP_LABEL, label1, mk_compile_data(), mk_compile_data()); // label L1
                    node = node->next;
                }
                else /* if (node->type == TYPE_ELSE) */
                {
                    compile(left); // left: comm_list
                    assert(node->next == NULL);
                    break; // node with TYPE_ELSE should be the last of the list, no need for jump L2 either
                }
            }
            add_code(CODE_OP_LABEL, label2, mk_compile_data(), mk_compile_data()); // label L2
            break;
        }
        case TYPE_WHILE: // left: exp, right: comm_list
        {
            CompileData label1 = create_label();
            add_code(CODE_OP_LABEL, label1, mk_compile_data(), mk_compile_data()); // make label L1
            leftData = compile_exp(left);
            CompileData label2 = create_label();
            if (leftData.registerType == CODE_REGISTER_FLOAT)
                leftData.registerType = CODE_REGISTER_TEMP;
                        
            add_code(CODE_OP_BEQ, leftData, mk_compile_data(), label2); // beq $var1, $zero, L2
            compile(right);
            add_code(CODE_OP_JUMP, label1, mk_compile_data(), mk_compile_data()); // make j L1
            add_code(CODE_OP_LABEL, label2, mk_compile_data(), mk_compile_data()); // make label L2
            break;
        }
        case TYPE_CONNECTION_NODE:
            compile(left);
            compile(right);
            break;
        case TYPE_PRINTLN:
            assert(right == NULL);
            leftData = compile_exp(left);
            switch (left->type)
            {
                case TYPE_VAR:
                {
                    symbol_entry* var_sym = get_symbol(left->data.sval);
                    if (!var_sym)
                    {
                        printf("Var %s not initialized! Exiting!\n", left->data.sval);
                        exit(1);
                    }
                    
                    switch (var_sym->type)
                    {
                        case TYPE_INTEGER:
                            add_code(CODE_PRINT_INTEGER, leftData, mk_compile_data(), mk_compile_data());
                            break;
                        case TYPE_FLOAT:
                            add_code(CODE_PRINT_FLOAT, leftData, mk_compile_data(), mk_compile_data());
                            break;
                        case TYPE_BOOL:
                            add_code(CODE_PRINT_BOOL, leftData, mk_compile_data(), mk_compile_data());
                            break;
                        default:
                            printf("TYPE_VAR has incorrect op_type %d\n", left->op_type);
                            assert(0);
                            break;
                    }
                    
                    break;
                }
                case TYPE_INTEGER:
                    add_code(CODE_PRINT_INTEGER, leftData, mk_compile_data(), mk_compile_data());
                    break;
                case TYPE_FLOAT:
                    add_code(CODE_PRINT_FLOAT, leftData, mk_compile_data(), mk_compile_data());
                    break;
                case TYPE_BOOL:
                    add_code(CODE_PRINT_BOOL, leftData, mk_compile_data(), mk_compile_data());
                    break;
                default:
                    printf("TYPE_PRINT has left child that with bad type\n");
                    assert(0);
                    break;
            }
            
            add_code(CODE_PRINT_NEWLINE, mk_compile_data(), mk_compile_data(), mk_compile_data());
            break;
        case TYPE_VAR:
        case TYPE_INTEGER:
        case TYPE_FLOAT:
        case TYPE_BOOL:
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
        default:
            assert(0);
            break;
    }
}

// return number of the variable that contains the result
CompileData compile_exp(parse_node* node)
{
    CompileData returnData;
    returnData.type = CODE_VAL_REGISTER;
    returnData.data.ival = -1;
    if (node == NULL)
    {
        printf("compile_exp for NULL node");
        assert(0);
        return returnData;
    }
        
    parse_node* left = node->left;
    parse_node* right = node->right;
    
    switch (node->op_type)
    {
        case TYPE_NONE: // leaf value
            switch (node->type)
            {
                case TYPE_VAR: // need to use sval to get the variable pointer (or create it)
                {
                    int isFloat = 0;
                    symbol_entry* sym = get_symbol(node->data.sval);
                    if (sym && sym->type == TYPE_FLOAT)
                        isFloat = 1;
                        
                    returnData.type = CODE_VAL_REGISTER;
                    returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_SAVED;
                    returnData.data.ival = get_register_for_symbol(node);
                    return returnData;
                }
                case TYPE_INTEGER:
                case TYPE_BOOL:
                    returnData.type = CODE_VAL_INT_VALUE;
                    returnData.data.ival = node->data.ival;
                    return returnData;
                case TYPE_FLOAT:
                    returnData.type = CODE_VAL_FLOAT_VALUE;
                    returnData.data.fval = node->data.fval;
                    return returnData;
                default:
                    printf("Bad node type: %d\n", node->type);
                    assert(0);
                    break;
            }
            break;
        case TYPE_OP_ADD:
        case TYPE_OP_SUB:
        case TYPE_OP_MUL:
        case TYPE_OP_DIV:
        case TYPE_OP_GT:
        case TYPE_OP_GE:
        case TYPE_OP_LT:
        case TYPE_OP_LE:
        case TYPE_OP_EQ:
        case TYPE_OP_NE:
        case TYPE_OP_BITWISE_AND:
        case TYPE_OP_BITWISE_OR:
        case TYPE_OP_LOGICAL_AND:
        case TYPE_OP_LOGICAL_OR:
        {
            CompileData leftData = compile_exp(left);
            CompileData rightData = compile_exp(right);
            
            int isFloat = 0;
            if (left->type == TYPE_FLOAT || right->type == TYPE_FLOAT)
                isFloat = 1;
            else if (left->type == TYPE_VAR)
            {
                symbol_entry* sym = get_symbol(left->data.sval);
                if (sym && sym->type == TYPE_FLOAT)
                    isFloat = 1;
            }
            
            // both nodes are values
            if (leftData.type != CODE_VAL_REGISTER && rightData.type != CODE_VAL_REGISTER)
            {
                returnData.type = isFloat ? CODE_VAL_FLOAT_VALUE : CODE_VAL_INT_VALUE;
                switch (node->op_type)
                {
                    case TYPE_OP_ADD:
                        if (isFloat)
                            returnData.data.fval = leftData.data.fval + rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival + rightData.data.ival;
                        break;
                    case TYPE_OP_SUB:
                        if (isFloat)
                            returnData.data.fval = leftData.data.fval - rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival - rightData.data.ival;
                        break;
                    case TYPE_OP_MUL:
                        if (isFloat)
                            returnData.data.fval = leftData.data.fval * rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival * rightData.data.ival;
                        break;
                    case TYPE_OP_DIV:
                        if (isFloat)
                        {
                            if (rightData.data.fval == 0)
                            {
                                printf("Error: division by zero");
                                exit(1);
                            }
                            
                            returnData.data.fval = leftData.data.fval / rightData.data.fval;
                        }
                        else
                        {
                            if (rightData.data.ival == 0)
                            {
                                printf("Error: division by zero");
                                exit(1);
                            }
                            
                            returnData.data.ival = leftData.data.ival / rightData.data.ival;
                        }
                        break;
                    case TYPE_OP_GT:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval > rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival > rightData.data.ival;
                        break;
                    case TYPE_OP_GE:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval >= rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival >= rightData.data.ival;
                        break;
                    case TYPE_OP_LT:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval < rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival < rightData.data.ival;
                        break;
                    case TYPE_OP_LE:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval <= rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival <= rightData.data.ival;
                        break;
                    case TYPE_OP_EQ:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval == rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival == rightData.data.ival;
                        break;
                    case TYPE_OP_NE:
                        if (isFloat)
                            returnData.data.ival = leftData.data.fval != rightData.data.fval;
                        else
                            returnData.data.ival = leftData.data.ival != rightData.data.ival;
                        break;
                    case TYPE_OP_BITWISE_AND:
                        returnData.data.ival = leftData.data.ival & rightData.data.ival;
                        break;
                    case TYPE_OP_BITWISE_OR:
                        returnData.data.ival = leftData.data.ival | rightData.data.ival;
                        break;
                    case TYPE_OP_LOGICAL_AND:
                        returnData.data.ival = leftData.data.ival && rightData.data.ival;
                        break;
                    case TYPE_OP_LOGICAL_OR:
                        returnData.data.ival = leftData.data.ival || rightData.data.ival;
                        break;
                    default:
                        assert(0);
                        break;
                }
                
                return returnData;
            }
            // one of the nodes is a value, another is a register
            else if (leftData.type != CODE_VAL_REGISTER || rightData.type != CODE_VAL_REGISTER)
            {
                CompileData* registerData = leftData.type == CODE_VAL_REGISTER ? &leftData : &rightData;
                CompileData* valueData = leftData.type != CODE_VAL_REGISTER ? &leftData : &rightData;
                
                int* destRegister = isFloat ? temp_float_register_counter : &temp_int_register_counter;
                CompileData destData = mk_compile_data();
                destData.type = CODE_VAL_REGISTER;
                destData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                destData.data.ival = *destRegister;
                
                switch (node->op_type)
                {
                    case TYPE_OP_ADD:
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_ADD_F : CODE_OP_ADD, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_SUB:
                        // b = 34 - a
                        // b = a + (-34)
                        if (valueData == &leftData)
                        {
                            if (isFloat)
                                valueData->data.fval *= -1;
                            else
                                valueData->data.ival *= -1;
                        }
                        
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_SUB_F : CODE_OP_SUB, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_MUL:
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_MUL_F : CODE_OP_MUL, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_DIV:
                        if (isFloat) // we always need new registers for floats, no immediates
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *valueData, mk_compile_data());
                            valueData->type = CODE_VAL_REGISTER;
                            valueData->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            valueData->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        // order must be kept for division, we create a new register if needed for a direct value
                        else if (valueData == &leftData)
                        {
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, leftData, mk_compile_data());
                            leftData.type = CODE_VAL_REGISTER;
                            leftData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            leftData.data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        add_code(isFloat ? CODE_OP_DIV_F : CODE_OP_DIV, destData, leftData, rightData);
                        break;
                    case TYPE_OP_GT:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, rightData, leftData);
                        break;
                    case TYPE_OP_GE:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, rightData, leftData);
                        break;
                    case TYPE_OP_LT:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LE:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_EQ:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SEQ_F : CODE_OP_SEQ, destData, leftData, rightData);
                        break;
                    case TYPE_OP_NE:
                        {
                            CompileData* ptr = valueData == &leftData ? &leftData : &rightData;
                            add_code(isFloat ? CODE_OP_LI_F : CODE_OP_LI, destData, *ptr, mk_compile_data());
                            ptr->type = CODE_VAL_REGISTER;
                            ptr->registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                            ptr->data.ival = destData.data.ival;
                            
                            destData.data.ival = ++(*destRegister);
                        }
                        
                        // always temp
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SNE_F : CODE_OP_SNE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_BITWISE_AND:
                        add_code(CODE_OP_BITWISE_AND, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_BITWISE_OR:
                        add_code(CODE_OP_BITWISE_OR, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_LOGICAL_AND:
                        add_code(CODE_OP_LOGICAL_AND, destData, *registerData, *valueData);
                        break;
                    case TYPE_OP_LOGICAL_OR:
                        add_code(CODE_OP_LOGICAL_OR, destData, *registerData, *valueData);
                        break;
                    default:
                        assert(0);
                        break;
                }
            
                returnData.type = CODE_VAL_REGISTER;
                returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                returnData.data.ival = *destRegister;
                ++(*destRegister);
                return returnData;
            }
            // both nodes are registers
            else
            {
                int* destRegister = isFloat ? temp_float_register_counter : &temp_int_register_counter;
                CompileData destData = mk_compile_data();
                destData.type = CODE_VAL_REGISTER;
                destData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                destData.data.ival = *destRegister;
                
                switch (node->op_type)
                {
                    case TYPE_OP_ADD:
                        add_code(isFloat ? CODE_OP_ADD_F : CODE_OP_ADD, destData, leftData, rightData);
                        break;
                    case TYPE_OP_SUB:
                        add_code(isFloat ? CODE_OP_SUB_F : CODE_OP_SUB, destData, leftData, rightData);
                        break;
                    case TYPE_OP_MUL:
                        add_code(isFloat ? CODE_OP_MUL_F : CODE_OP_MUL, destData, leftData, rightData);
                        break;
                    case TYPE_OP_DIV:
                        add_code(isFloat ? CODE_OP_DIV_F : CODE_OP_DIV, destData, leftData, rightData);
                        break;
                    case TYPE_OP_GT:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, rightData, leftData);
                        break;
                    case TYPE_OP_GE:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, rightData, leftData);
                        break;
                    case TYPE_OP_LT:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLT_F : CODE_OP_SLT, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LE:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SLE_F : CODE_OP_SLE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_EQ:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SEQ_F : CODE_OP_SEQ, destData, leftData, rightData);
                        break;
                    case TYPE_OP_NE:
                        destData.registerType = CODE_REGISTER_TEMP;
                        add_code(isFloat ? CODE_OP_SNE_F : CODE_OP_SNE, destData, leftData, rightData);
                        break;
                    case TYPE_OP_BITWISE_AND:
                        add_code(CODE_OP_BITWISE_AND, destData, leftData, rightData);
                        break;
                    case TYPE_OP_BITWISE_OR:
                        add_code(CODE_OP_BITWISE_OR, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LOGICAL_AND:
                        add_code(CODE_OP_LOGICAL_AND, destData, leftData, rightData);
                        break;
                    case TYPE_OP_LOGICAL_OR:
                        add_code(CODE_OP_LOGICAL_OR, destData, leftData, rightData);
                        break;
                    default:
                        assert(0);
                        break;
                }
                
                returnData.type = CODE_VAL_REGISTER;
                returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                returnData.data.ival = *destRegister;
                ++(*destRegister);
                return returnData;
            }
            break;
        }
        case TYPE_OP_NEG:
        case TYPE_OP_MINUS:
        {
            CompileData leftData = compile_exp(left);
            
            int isFloat = 0;
            if (left->type == TYPE_FLOAT)
                isFloat = 1;
            else if (left->type == TYPE_VAR)
            {
                symbol_entry* sym = get_symbol(left->data.sval);
                if (sym && sym->type == TYPE_FLOAT)
                    isFloat = 1;
            }
            
            // it's an immediate value
            if (leftData.type != CODE_VAL_REGISTER)
            {
                returnData.type = isFloat ? CODE_VAL_FLOAT_VALUE : CODE_VAL_INT_VALUE;
                if  (node->op_type == TYPE_OP_NEG)
                    returnData.data.ival = !leftData.data.ival;
                else if (node->op_type == TYPE_OP_MINUS)
                {
                    if (isFloat)
                        returnData.data.fval = -leftData.data.fval;
                    else
                        returnData.data.ival = -leftData.data.ival;
                }
            }
            else
            {
                int* destRegister = isFloat ? temp_float_register_counter : &temp_int_register_counter;
                returnData.type = CODE_VAL_REGISTER;
                returnData.registerType = isFloat ? CODE_REGISTER_FLOAT : CODE_REGISTER_TEMP;
                returnData.data.ival = *destRegister;
                (*destRegister)++; // increment the register counter, we're adding an additional operation here
                
                CompileData rightData = mk_compile_data();

                if (node->op_type == TYPE_OP_NEG)
                {
                    CompileData label1 = create_label();
                    CompileData label2 = create_label();
                    if (leftData.registerType == CODE_REGISTER_FLOAT)
                        leftData.registerType = CODE_REGISTER_TEMP;

                    add_code(CODE_OP_BEQ, leftData, mk_compile_data(), label1); // beq $var1, $zero, L1
                    rightData.type = CODE_VAL_INT_VALUE;
                    rightData.data.ival = 0;
                    add_code(CODE_OP_LI, returnData, rightData, mk_compile_data());
                    add_code(CODE_OP_JUMP, label2, mk_compile_data(), mk_compile_data());
                    add_code(CODE_OP_LABEL, label1, mk_compile_data(), mk_compile_data()); // label L1
                    rightData.type = CODE_VAL_INT_VALUE;
                    rightData.data.ival = 1;
                    add_code(CODE_OP_LI, returnData, rightData, mk_compile_data());
                    add_code(CODE_OP_LABEL, label2, mk_compile_data(), mk_compile_data()); // label L2
                }
                else if (node->op_type == TYPE_OP_MINUS)
                {
                    rightData.type = isFloat ? CODE_VAL_FLOAT_VALUE : CODE_VAL_INT_VALUE;
                    if (isFloat)
                        rightData.data.fval = -1;
                    else
                        rightData.data.ival = -1;
                    
                    add_code(isFloat ? CODE_OP_MUL_F : CODE_OP_MUL, returnData, leftData, rightData);
                }
            }
            return returnData;
        }
        default:
            assert(0);
            break;
    }
    
    return returnData;
}
    
const char* print_CompileData(CompileData data)
{
    if (data.type == CODE_VAL_NONE)
        return "<NULL>";
        
    #define MAX_FMT_STRING 10000
    static char temp_buffer[MAX_FMT_STRING];
    static char string[MAX_FMT_STRING];
    static int index = 0;
    char* buf;
    
    const char* varType = "";
    if (data.type == CODE_VAL_LABEL)
        varType = "L";
    else if (data.type == CODE_VAL_REGISTER)
    {
        if (data.registerType == CODE_REGISTER_SAVED)
            varType = "$s";
        else if (data.registerType == CODE_REGISTER_TEMP)
            varType = "$t";
        else // float?
            varType = "$f";
    }
    else if (data.type == CODE_VAL_FLOAT_MEMORY)
        varType = "fp";
        
    sprintf(temp_buffer, "%s%u", varType, data.data.ival);
    int len = strlen(temp_buffer);
    
    if (len + index >= MAX_FMT_STRING - 1)
        index = 0;
    
    buf = &string[index];
    memcpy(buf, temp_buffer, len + 1);

    index += len + 1;

    return buf;
}

void convert_code_to_mips()
{
    printf(".data\n");
    // default strings
    printf("__newline__:\t.asciiz\t\"\\n\"\n");
    printf("__bool_true__:\t.asciiz\t\"true\"\n");
    printf("__bool_false__:\t.asciiz\t\"false\"\n");
    
    print_float_variables();
    
    printf(".text\n");
    // default $f0 to zero, bloody MIPS doesn't allow $zero to be used
    printf("\tmtc1 $zero $f0\n");
	printf("\tcvt.s.w $f0, $f0\n");
    
    Code* code = firstCode;
    while (code != NULL)
    {
        const char* destStr = print_CompileData(code->dest);
        const char* val1Str = print_CompileData(code->val1);
        const char* val2Str = print_CompileData(code->val2);
    
        switch (code->op)
        {
            case CODE_OP_ASSIGN:
                printf("\tadd %s, %s, $zero\n", destStr, val1Str);
                break;
            case CODE_OP_ASSIGN_F:
                printf("\tadd.s %s, %s, $f0\n", destStr, val1Str);
                break;
            case CODE_OP_ADD:
                printf("\tadd %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_ADD_F:
                printf("\tadd.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SUB:
                printf("\tsub %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SUB_F:
                printf("\tsub.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_MUL:
                printf("\tmul %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_MUL_F:
                printf("\tmul.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_DIV:
                printf("\tdiv %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_DIV_F:
                printf("\tdiv.s %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_BEQ:
                printf("\tbeq %s, $zero, %s\n", destStr, val2Str);
                break;
            case CODE_OP_JUMP:
                printf("\tj %s\n", destStr);
                break;
            case CODE_OP_LABEL:
                printf("%s:\n", destStr);
                break;
            case CODE_OP_LI:
                printf("\tli %s, %s\n", destStr, val1Str);
                break;
            case CODE_OP_LI_F:
                printf("\tl.s %s, %s\n", destStr, val1Str);
                break;
            case CODE_OP_SLT:
                printf("\tslt %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SLT_F:
            {
                static slt_f_label = 0;
                printf("\tc.lt.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t slt_f_%u\n", slt_f_label);
                printf("\tli %s 0\n", destStr);
                printf("\tj slt_f_%u\n", slt_f_label + 1);
                printf("slt_f_%u:\n", slt_f_label);
                printf("\tli %s 1\n", destStr);
                printf("slt_f_%u:\n", slt_f_label + 1);
                slt_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_SLE:
                printf("\tsle %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SLE_F:
            {
                static sle_f_label = 0;
                printf("\tc.le.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t sle_f_%u\n", sle_f_label);
                printf("\tli %s 0\n", destStr);
                printf("\tj sle_f_%u\n", sle_f_label + 1);
                printf("sle_f_%u:\n", sle_f_label);
                printf("\tli %s 1\n", destStr);
                printf("sle_f_%u:\n", sle_f_label + 1);
                sle_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_SEQ:
                printf("\tseq %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SEQ_F:
            {
                static seq_f_label = 0;
                printf("\tc.eq.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t seq_f_%u\n", seq_f_label);
                printf("\tli %s 0\n", destStr);
                printf("\tj seq_f_%u\n", seq_f_label + 1);
                printf("seq_f_%u:\n", seq_f_label);
                printf("\tli %s 1\n", destStr);
                printf("seq_f_%u:\n", seq_f_label + 1);
                seq_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_SNE:
                printf("\tsne %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_SNE_F:
            {
                static sne_f_label = 0;
                printf("\tc.eq.s %s, %s\n", val1Str, val2Str);
                printf("\tbc1t sne_f_%u\n", sne_f_label);
                printf("\tli %s 1\n", destStr); // values switched on purpose
                printf("\tj sne_f_%u\n", sne_f_label + 1);
                printf("sne_f_%u:\n", sne_f_label);
                printf("\tli %s 0\n", destStr); // values switched on purpose
                printf("sne_f_%u:\n", sne_f_label + 1);
                sne_f_label += 2; // we use 2 labels here
                break;
            }
            case CODE_OP_BITWISE_AND:
                printf("\tand %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_BITWISE_OR:
                printf("\tor %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_LOGICAL_AND:
                printf("\tand %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_OP_LOGICAL_OR:
                printf("\tor %s, %s, %s\n", destStr, val1Str, val2Str);
                break;
            case CODE_PRINT_INTEGER:
                printf("\tli $v0, 1\n"); // print int code = 1
                printf("\tadd $a0, %s, $zero\n", destStr);
                printf("\tsyscall\n");
                break;
            case CODE_PRINT_FLOAT:
                printf("\tli $v0, 2\n"); // print float code = 2
                printf("\tadd.s $f12, %s, $f0\n", destStr);
                printf("\tsyscall\n");
                break;
            case CODE_PRINT_BOOL:
            {
                static int bool_label_counter = 0;
                int label1 = bool_label_counter++;
                int label2 = bool_label_counter++;
                
                printf("\tbeq %s, $zero, LBOOL%u\n", destStr, label1);
                
                // print if true
                printf("\tli $v0, 4\n"); // print string code = 4
                printf("\tla $a0, __bool_true__\n");
                printf("\tsyscall\n");
                // --
                
                printf("\tj LBOOL%u\n", label2);
                printf("LBOOL%u:\n", label1);
                
                // print if false
                printf("\tli $v0, 4\n"); // print string code = 4
                printf("\tla $a0, __bool_false__\n");
                printf("\tsyscall\n");
                // --
                
                printf("LBOOL%u:\n", label2);
                
                ++bool_label_counter;
                break;
            }
            case CODE_PRINT_NEWLINE:
                printf("\tli $v0, 4\n"); // print string code = 4
                printf("\tla $a0, __newline__\n");
                printf("\tsyscall\n");
                break;
            default:
                printf("Code op %d can't be converted to MIPS\n", code->op);
                assert(0);
                break;
        }
        
        code = code->next;
    }
}

int main() {
    int result = yyparse();
    if (result == 0)
        fprintf(stderr, "Parser: Success.\n");
    else
    {
        fprintf(stderr, "Parser: Error (%d).\n", result);
        return result;
    }
     
    // print_tree(root);
    
    compile(root);
    
    // print_symbol_table();
    
    convert_code_to_mips();
    
    // free up stuff
    free_parse_node(root); // delete the whole tree structure    
    while (symtable != NULL)
    {
        symbol_entry* ptr = symtable->next;
        free(symtable);
        symtable = ptr;
    }
    
    lastCode = NULL;
    while (firstCode != NULL)
    {
        Code* ptr = firstCode->next;
        free(firstCode);
        firstCode = ptr;
    }
    
    last_fp = NULL;
    while (first_fp != NULL)
    {
        FloatImmediate* ptr = first_fp->next;
        free(first_fp);
        first_fp = ptr;
    }
    return 0;
}

