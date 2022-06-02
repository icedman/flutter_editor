#include "reader.h"
#include "pattern.h"

#include <fstream>
#include <iostream>
#include <vector>

namespace parse {

static bool convert_array(Json::Value const& patterns,
    std::vector<rule_ptr>& res)
{
    for (int i = 0; i < (int)patterns.size(); i++) {
        Json::Value rule = patterns[i];
        if (rule_ptr child = convert_json(rule)) {
            res.push_back(child);
        }
    }

    return true;
}

static bool convert_dictionary(Json::Value const& repository,
    repository_ptr& res)
{
    if (!repository.isObject()) {
        return false;
    }
    std::vector<std::string> keys = repository.getMemberNames();
    std::vector<std::string>::iterator it = keys.begin();
    while (it != keys.end()) {
        std::string first = *it;
        Json::Value second = repository[first];
        if (rule_ptr child = convert_json(second)) {
            res->emplace(first, child);
        }
        it++;
    }

    return true;
}

rule_ptr convert_json(Json::Value const& json, rule_ptr target)
{
    rule_ptr res = target;
    if (!res) {
        res = std::make_shared<rule_t>();
    }
    if (!json.isObject()) {
        return res;
    }

    //------------
    // strings
    //------------
    struct {
        const char* name;
        std::string* str;
    } map_strings[] = { { "name", &res->scope_string },
        { "scopeName", &res->scope_string },
        { "contentName", &res->content_scope_string },
        { "match", &res->match_string },
        { "begin", &res->match_string },
        { "while", &res->while_string },
        { "end", &res->end_string },
        { "applyEndPatternLast", &res->apply_end_last },
        { "include", &res->include_string },
        { 0, 0 } };

    for (int i = 0;; i++) {
        if (map_strings[i].name == 0) {
            break;
        }

        if (!json.isMember(map_strings[i].name)) {
            continue;
        }

        *map_strings[i].str = json[map_strings[i].name].asString();
    }

    //------------
    // dictionary
    //------------
    struct {
        const char* name;
        repository_ptr* repository;
    } map_dictionary[] = { { "captures", &res->captures },
        { "beginCaptures", &res->begin_captures },
        { "whileCaptures", &res->while_captures },
        { "endCaptures", &res->end_captures },
        { "repository", &res->repository },
        { "injections", &res->injection_rules },
        { 0, 0 } };

    for (int i = 0;; i++) {
        if (map_dictionary[i].name == 0) {
            break;
        }

        if (!json.isMember(map_dictionary[i].name)) {
            continue;
        }

        *map_dictionary[i].repository = std::make_shared<repository_t>();
        convert_dictionary(json[map_dictionary[i].name],
            *map_dictionary[i].repository);
    }

    //------------
    // array
    //------------
    convert_array(json["patterns"], res->children);
    return res;
}

Json::Value rule_to_json(rule_ptr const& res);

static bool array_to_json(Json::Value& target,
    std::vector<rule_ptr>& patterns)
{
    std::vector<rule_ptr>::iterator it = patterns.begin();
    while (it != patterns.end()) {
        target.append(rule_to_json(*it));
        it++;
    }
    return true;
}

static bool dictionary_to_json(Json::Value& target, repository_ptr& res)
{
    std::map<std::string, rule_ptr>::iterator it = res->begin();
    while (it != res->end()) {
        rule_ptr r = it->second;
        std::string name = it->first;
        Json::Value v = rule_to_json(r);
        target[name] = v;
        it++;
    }
    return true;
}

Json::Value rule_to_json(rule_ptr const& res)
{
    Json::Value json;

    json["_id"] = (int)res->rule_id;

    struct {
        const char* name;
        std::string* str;
    } map_strings[] = { { "name", &res->scope_string },
        { "scopeName", &res->scope_string },
        { "contentName", &res->content_scope_string },
        { "match", &res->match_string },
        { "begin", &res->match_string },
        { "while", &res->while_string },
        { "end", &res->end_string },
        { "applyEndPatternLast", &res->apply_end_last },
        { "include", &res->include_string },
        { 0, 0 } };

    for (int i = 0;; i++) {
        if (map_strings[i].name == 0) {
            break;
        }
        if (map_strings[i].str->length()) {
            json[map_strings[i].name] = *map_strings[i].str;
        }
    }

    //------------
    // dictionary
    //------------
    struct {
        const char* name;
        repository_ptr repository;
    } map_dictionary[] = { { "captures", res->captures },
        { "beginCaptures", res->begin_captures },
        { "whileCaptures", res->while_captures },
        { "endCaptures", res->end_captures },
        { "repository", res->repository },
        { "injections", res->injection_rules },
        { 0, 0 } };

    for (int i = 0;; i++) {
        if (map_dictionary[i].name == 0) {
            break;
        }
        if (map_dictionary[i].repository) {
            dictionary_to_json(json[map_dictionary[i].name],
                map_dictionary[i].repository);
        }
    }

    if (res->children.size()) {
        array_to_json(json["patterns"], res->children);
    }

    return json;
}

Json::Value loadJson(std::string filename)
{
    Json::Value root;
    std::ifstream ifs;
    ifs.open(filename);

    Json::CharReaderBuilder builder;
    JSONCPP_STRING errs;
    if (!parseFromStream(builder, ifs, &root, &errs)) {
        // cout << errs << endl;
        // return false;
    }

    // std::cout << root << std::endl;
    return root;
}

} // namespace parse
