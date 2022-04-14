#ifndef PARSE_GRAMMAR_H
#define PARSE_GRAMMAR_H

#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "json/json.h"
#include "private.h"
#include "scope.h"

namespace parse {

struct rule_t;
struct stack_t;
typedef std::shared_ptr<rule_t> rule_ptr;
typedef std::shared_ptr<stack_t> stack_ptr;

struct stack_serialized_t {
    int rule_id;

    std::string scope;

    std::string scope_string;
    std::string content_scope_string = NULL_STR;

    std::string while_pattern;
    std::string end_pattern;

    size_t anchor;
    bool zw_begin_match;
    bool apply_end_last;
};

struct grammar_t {

    grammar_t(Json::Value const& json);
    ~grammar_t();

    stack_ptr seed() const;
    std::mutex& mutex() { return _mutex; }
    Json::Value document() { return doc; }

    stack_serialized_t serialize_state(stack_ptr stack);
    stack_ptr unserialize_state(stack_serialized_t stack);

private:
    struct rule_stack_t {
        rule_stack_t(rule_t const* rule, rule_stack_t const* parent = nullptr)
            : rule(rule)
            , parent(parent)
        {
        }

        rule_t const* rule;
        rule_stack_t const* parent;
    };

    void setup_includes(rule_ptr const& rule, rule_ptr const& base,
        rule_ptr const& self, rule_stack_t const& stack);
    rule_ptr find_grammar(std::string const& scope, rule_ptr const& base);
    rule_ptr add_grammar(std::string const& scope, Json::Value const& json,
        rule_ptr const& base = rule_ptr());
    std::vector<std::pair<scope::selector_t, rule_ptr>> injection_grammars();

    rule_ptr _rule;
    std::mutex _mutex;
    std::map<std::string, rule_ptr> _grammars;
    Json::Value doc;

    rule_ptr find_rule(grammar_t* grammar, int id);
};

typedef std::shared_ptr<grammar_t> grammar_ptr;
grammar_ptr parse_grammar(Json::Value const& json);

} // namespace parse

#endif