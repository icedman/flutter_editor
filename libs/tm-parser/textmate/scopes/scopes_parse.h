#ifndef SCOPES_PARSE_H
#define SCOPES_PARSE_H

#include "types.h"

namespace scope {

namespace parse {

    char const* selector(char const* first, char const* last,
        scope::types::selector_t& selector);

} // namespace parse

} // namespace scope

#endif