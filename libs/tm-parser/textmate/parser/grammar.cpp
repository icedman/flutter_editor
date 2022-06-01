#include <cstring>
#include <iostream>
#include <memory>
#include <vector>

#include "extension.h"
#include "grammar.h"
#include "onigmognu.h"
#include "parse.h"
#include "private.h"
#include "reader.h"
#include <pthread.h>

namespace parse {

extension_list* extensions = nullptr;

void set_extensions(extension_list* exts)
{
    extensions = exts;
}

int grammar_t::running_threads = 0;

grammar_t::grammar_t(Json::Value const& json)
{
    std::string scopeName = json["scopeName"].asString();
    _rule = add_grammar(scopeName, json);

    // Json::Value parsed = rule_to_json(_rule);
    // std::cout << parsed << std::endl;
    // doc = parsed;

    doc = json;
}

grammar_t::~grammar_t() {}

static bool pattern_has_back_reference(std::string const& ptrn)
{
    bool escape = false;
    for (char const& ch : ptrn) {
        if (escape && isdigit(ch)) {
            // D(DBF_Parser, bug("%s: %s\n", ptrn.c_str(), "YES"););
            return true;
        }
        escape = !escape && ch == '\\';
    }
    // D(DBF_Parser, bug("%s: %s\n", ptrn.c_str(), "NO"););
    return false;
}

static bool pattern_has_anchor(std::string const& ptrn)
{
    bool escape = false;
    for (char const& ch : ptrn) {
        if (escape && ch == 'G')
            return true;
        escape = !escape && ch == '\\';
    }
    return false;
}

// =============
// = grammar_t =
// =============

static void compile_patterns(rule_t* rule)
{
    if (rule->match_string != NULL_STR) {
        rule->match_pattern = regexp::pattern_t(rule->match_string);
        rule->match_pattern_is_anchored = pattern_has_anchor(rule->match_string);
        // if(!rule->match_pattern)
        //   os_log_error(OS_LOG_DEFAULT, "Bad begin/match pattern for %{public}s",
        //   rule->scope_string.c_str());
    }

    if (rule->while_string != NULL_STR && !pattern_has_back_reference(rule->while_string)) {
        rule->while_pattern = regexp::pattern_t(rule->while_string);
        // if(!rule->while_pattern)
        //   os_log_error(OS_LOG_DEFAULT, "Bad while pattern for %{public}s",
        //   rule->scope_string.c_str());
    }

    if (rule->end_string != NULL_STR && !pattern_has_back_reference(rule->end_string)) {
        rule->end_pattern = regexp::pattern_t(rule->end_string);
        // if(!rule->end_pattern)
        //   os_log_error(OS_LOG_DEFAULT, "Bad end pattern for %{public}s",
        //   rule->scope_string.c_str());
    }

    for (rule_ptr child : rule->children)
        compile_patterns(child.get());

    repository_ptr maps[] = { rule->repository, rule->injection_rules,
        rule->captures, rule->begin_captures,
        rule->while_captures, rule->end_captures };
    for (auto const& map : maps) {
        if (!map)
            continue;

        for (auto const& pair : *map)
            compile_patterns(pair.second.get());
    }

    // if (rule->injection_rules)
    //   std::copy(rule->injection_rules->begin(), rule->injection_rules->end(),
    //             back_inserter(rule->injections));
    // rule->injection_rules.reset();
}

void grammar_t::setup_includes(rule_ptr const& rule, rule_ptr const& base,
    rule_ptr const& self,
    rule_stack_t const& stack)
{

    std::string const include = rule->include_string;
    if (include == "$base") {
        rule->include = base.get();
    } else if (include == "$self") {
        rule->include = self.get();
    } else if (include != NULL_STR) {
        static auto find_repository_item = [](rule_t const* rule,
                                               std::string const& name) -> rule_t* {
            if (rule->repository) {
                auto it = rule->repository->find(name);
                if (it != rule->repository->end())
                    return it->second.get();
            }
            return nullptr;
        };

        if (include[0] == '#') {
            std::string const name = include.substr(1);
            for (rule_stack_t const* node = &stack; node && !rule->include;
                 node = node->parent)
                rule->include = find_repository_item(node->rule, name);
        } else {
            std::string::size_type fragment = include.find('#');
            if (rule_ptr grammar = find_grammar(include.substr(0, fragment), base))
                rule->include = fragment == std::string::npos
                    ? grammar.get()
                    : find_repository_item(
                        grammar.get(), include.substr(fragment + 1));
        }

        if (!rule->include) {
            // if (base != self)
            //     printf("%s → %s: include not found ‘%s’\n", base->scope_string.c_str(),
            //         self->scope_string.c_str(), include.c_str());
            // else
            //     printf("%s: include not found ‘%s’\n",
            //         self->scope_string.c_str(), include.c_str());
        }
    } else {
        for (rule_ptr child : rule->children)
            setup_includes(child, base, self, rule_stack_t(rule.get(), &stack));

        repository_ptr maps[] = { rule->repository, rule->injection_rules,
            rule->captures, rule->begin_captures,
            rule->while_captures, rule->end_captures };
        for (auto const& map : maps) {
            if (!map)
                continue;

            for (auto const& pair : *map)
                setup_includes(pair.second, base, self,
                    rule_stack_t(rule.get(), &stack));
        }
    }
}

std::vector<std::pair<scope::selector_t, rule_ptr>>
grammar_t::injection_grammars()
{
    std::vector<std::pair<scope::selector_t, rule_ptr>> res;

    // TODO find grammar in directory
    // for(auto item : bundles::query(bundles::kFieldAny, NULL_STR,
    // scope::wildcard, bundles::kItemTypeGrammar))
    // {
    //   std::string injectionSelector =
    //   item->value_for_field(bundles::kFieldGrammarInjectionSelector);
    //   if(injectionSelector != NULL_STR)
    //   {
    //     if(rule_ptr grammar = convert_plist(item->plist()))
    //     {
    //       setup_includes(grammar, grammar, grammar,
    //       rule_stack_t(grammar.get())); compile_patterns(grammar.get());
    //       res.emplace_back(injectionSelector, grammar);
    //     }
    //   }
    // }

    return res;
}

rule_ptr grammar_t::find_grammar(std::string const& scope,
    rule_ptr const& base)
{
    auto it = _grammars.find(scope);
    if (it != _grammars.end())
        return it->second;

    if (extensions != nullptr) {
        bool found = false;
        std::string path;
        for (auto ext : *extensions) {
            if (found)
                break;
            if (!ext.hasGrammars)
                continue;
            for (auto gm : ext.grammars) {
                if (gm.scopeName == scope) {
                    path = gm.path;
                    found = true;
                    break;
                }
            }
        }

        if (found) {
            return add_grammar(scope, path, base, true);
        }
    }

    return nullptr;
}

void* grammar_t::setup_includes_thread(void* arg)
{
    grammar_t::setup_includes_payload_t* p = (grammar_t::setup_includes_payload_t*)arg;
    if (p->path != "") {
        Json::Value json = load_plist_or_json(p->path);
        convert_json(json, p->self);
    }
    compile_patterns(p->self.get());
    p->_this->setup_includes(p->rule, p->base, p->self, p->stack);
    delete p;
    running_threads--;
    return NULL;
}

rule_ptr grammar_t::add_grammar(std::string const& scope,
    Json::Value const& json, rule_ptr const& base, bool spawn_thread)
{
    #ifdef DISABLE_ADD_GRAMMAR_THREADS
    spawn_thread = false;
    #endif

    rule_ptr grammar = convert_json(json);
    if (grammar) {
        _grammars.emplace(scope, grammar);

        if (spawn_thread) {
            setup_includes_payload_t* p = new setup_includes_payload_t();
            p->_this = this;
            p->rule = grammar;
            p->base = base ? base : grammar;
            p->self = grammar;
            p->stack = rule_stack_t(grammar.get());
            running_threads++;
            pthread_t thread_id;
            pthread_create(&thread_id, NULL,
                &setup_includes_thread, (void*)(p));

        } else {
            compile_patterns(grammar.get());
            setup_includes(grammar, base ? base : grammar, grammar,
                rule_stack_t(grammar.get()));
        }
    }

    return grammar;
}

rule_ptr grammar_t::add_grammar(std::string const& scope, std::string const& path,
    rule_ptr const& base, bool spawn_thread)
{
    #ifdef DISABLE_ADD_GRAMMAR_THREADS
    spawn_thread = false;
    #endif

    rule_ptr grammar = std::make_shared<rule_t>();
    if (grammar) {
        _grammars.emplace(scope, grammar);

        if (spawn_thread) {
            setup_includes_payload_t* p = new setup_includes_payload_t();
            p->_this = this;
            p->rule = grammar;
            p->base = base ? base : grammar;
            p->self = grammar;
            p->stack = rule_stack_t(grammar.get());
            p->path = path;
            running_threads++;
            pthread_t thread_id;
            pthread_create(&thread_id, NULL,
                &setup_includes_thread, (void*)(p));

        } else {
            if (path != "") {
                Json::Value json = load_plist_or_json(path);
                convert_json(json, grammar);
            }
            compile_patterns(grammar.get());
            setup_includes(grammar, base ? base : grammar, grammar,
                rule_stack_t(grammar.get()));
        }
    }

    return grammar;
}

stack_ptr grammar_t::seed() const
{
    return std::make_shared<stack_t>(_rule.get(),
        _rule ? _rule->scope_string : "");
}

grammar_ptr parse_grammar(Json::Value const& json)
{
    return std::make_shared<grammar_t>(json);
}

rule_ptr rule_find_rule(rule_ptr rule, int rule_id)
{
    if (rule->rule_id == rule_id) {
        return rule;
    }

    if (rule->captures) {
        std::map<std::string, rule_ptr>::iterator it = rule->captures->begin();
        while (it != rule->captures->end()) {
            rule_ptr res = rule_find_rule(it->second, rule_id);
            if (res)
                return res;
            it++;
        }
    }

    if (rule->begin_captures) {
        std::map<std::string, rule_ptr>::iterator it = rule->begin_captures->begin();
        while (it != rule->begin_captures->end()) {
            rule_ptr res = rule_find_rule(it->second, rule_id);
            if (res)
                return res;
            it++;
        }
    }

    if (rule->while_captures) {
        std::map<std::string, rule_ptr>::iterator it = rule->while_captures->begin();
        while (it != rule->while_captures->end()) {
            rule_ptr res = rule_find_rule(it->second, rule_id);
            if (res)
                return res;
            it++;
        }
    }

    if (rule->end_captures) {
        std::map<std::string, rule_ptr>::iterator it = rule->end_captures->begin();
        while (it != rule->end_captures->end()) {
            rule_ptr res = rule_find_rule(it->second, rule_id);
            if (res)
                return res;
            it++;
        }
    }

    if (rule->repository) {
        std::map<std::string, rule_ptr>::iterator it = rule->repository->begin();
        while (it != rule->repository->end()) {
            rule_ptr res = rule_find_rule(it->second, rule_id);
            if (res)
                return res;
            it++;
        }
    }

    if (rule->injection_rules) {
        std::map<std::string, rule_ptr>::iterator it = rule->injection_rules->begin();
        while (it != rule->injection_rules->end()) {
            rule_ptr res = rule_find_rule(it->second, rule_id);
            if (res)
                return res;
            it++;
        }
    }

    for (auto r : rule->children) {
        rule_ptr res = rule_find_rule(r, rule_id);
        if (res)
            return res;
    }

    return nullptr;
}

rule_ptr grammar_t::find_rule(grammar_t* grammar, int rule_id)
{
    for (auto r : _grammars) {
        rule_ptr res = rule_find_rule(r.second, rule_id);
        if (res)
            return res;
    }
    return nullptr;
}

} // namespace parse
