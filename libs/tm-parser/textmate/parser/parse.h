#ifndef PARSE_PARSE_H
#define PARSE_PARSE_H

#include <map>
#include <string>
#include <vector>

#include "extension.h"
#include "private.h"
#include "scope.h"

namespace parse {
struct stack_t;
typedef std::shared_ptr<stack_t> stack_ptr;

void set_extensions(extension_list* extensions);

stack_ptr parse(char const* first, char const* last, stack_ptr stack,
    std::map<size_t, scope::scope_t>& scopes, bool firstLine);
bool equal(stack_ptr lhs, stack_ptr rhs);

} // namespace parse

#endif