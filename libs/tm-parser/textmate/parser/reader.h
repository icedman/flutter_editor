#ifndef PARSE_READER_H
#define PARSE_READER_H

#include <json/json.h>
#include <string>
#include <vector>

#include "grammar.h"
#include "private.h"

namespace parse {

rule_ptr convert_json(Json::Value const& json);

Json::Value rule_to_json(rule_ptr const& rule);

Json::Value loadJson(std::string filename);

} // namespace parse

#endif