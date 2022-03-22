#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"

#include <time.h>

using namespace parse;

grammar_ptr load(std::string path)
{
    Json::Value json = loadJson(path);
    return parse_grammar(json);
}

void read_and_parse_a_grammar(const char* grammar, const char* out)
{
    grammar_ptr gm;
    gm = load(grammar);

    std::string path;
    path = "tests/results/read/";
    path += out;
    // gm.save(path);
    // gm.dump();

    path = "tests/results/parsed/";
    path += out;
    // gm.save(path);
}

void test_read_and_parse()
{
    const char* grammars[] = { "hello.json",
        "json.json",
        "c.json",
        "html.json",
        "javascript.json",
        "coffee-script.json"
        // "php.json",
        "sql.json",
        "text.json",
        "ruby.json",
        "scss.json",
        "c-plus-plus.json",
        0 };

    for (int i = 0;; i++) {
        if (grammars[i] == 0) {
            break;
        }
        std::string path = "test-cases/first-mate/fixtures/";
        path += grammars[i];
        read_and_parse_a_grammar(path.c_str(), grammars[i]);
    }
}

void test_hello()
{
    grammar_ptr gm;
    gm = load("test-cases/first-mate/fixtures/hello.json");
    std::cout << gm->document() << std::endl;
    // gm.dump();

    // 01234 6789Xab
    // hello world!

    const char* first = "hello world!";
    const char* last = first + strlen(first);

    std::map<size_t, scope::scope_t> scopes;
    stack_ptr stack = parse::parse(first, last, gm->seed(), scopes, true);
}

void test_coffee()
{
    grammar_ptr gm;
    gm = load("test-cases/suite1/fixtures/coffee-script.json");
    std::cout << gm->document() << std::endl;

    Json::Value tests = loadJson("test-cases/first-mate/tests.json");
    for (int i = 0; i < (int)tests.size(); i++) {
        Json::Value t = tests[i];
        std::string scopeName = t["grammarScopeName"].asString();
        // std::cout << scopeName << std::endl;
        // continue;

        if (scopeName == "source.c") {
            std::cout << t << std::endl;
            continue;

            Json::Value lines = t["lines"];

            for (int j = 0; j < (int)lines.size(); j++) {
                Json::Value tl = lines[j];
                if (!tl.null) {
                    std::string str = tl["line"].asString();
                    std::cout << tl << std::endl;
                }
            }
        }
    }
}

void dump_tokens(std::map<size_t, scope::scope_t>& scopes)
{
    std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
    while (it != scopes.end()) {
        size_t n = it->first;
        scope::scope_t scope = it->second;
        std::cout << n << " size:" << scope.size() << " atoms:"
                  << to_s(scope).c_str()
                  << std::endl;

        it++;
    }
}

void theme_tokens(std::map<size_t, scope::scope_t>& scopes, theme_ptr theme)
{
    std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
    while (it != scopes.end()) {
        size_t n = it->first;
        scope::scope_t scope = it->second;
        style_t s = theme->styles_for_scope(scope);

        std::cout << n << " size:" << scope.size() << " last:" << scope.back().c_str()
                  << " " << s.foreground.red << ", " << s.foreground.green << ", " << s.foreground.blue
                  << std::endl;

        it++;
    }
}

int test_c()
{
    int lines = 0;

    grammar_ptr gm;
    // gm = load("test-cases/first-mate/fixtures/c.json");
    gm = load("extensions/cpp/syntaxes/cpp.tmLanguage.json");
    // std::cout << gm->document() << std::endl;

    Json::Value root = parse::loadJson("test-cases/themes/light_vs.json");
    theme_ptr theme = parse_theme(root);

    // FILE* fp = fopen("tests/cases/sqlite3.c", "r");
    // FILE* fp = fopen("tests/cases/test.cpp", "r");
    FILE* fp = fopen("tests/cases/tinywl.c", "r");
    char str[1024];

    for (int i = 0; i < 1; i++) {
        fseek(fp, 0, SEEK_SET);
        bool firstLine = true;

        parse::stack_ptr parser_state = gm->seed();
        while (fgets(str, 1000, fp)) {

            std::string ss(str, strlen(str));
            ss += "\n";

            const char* first = ss.c_str();
            const char* last = first + ss.length();

            std::cout << "------------------------" << std::endl;
            std::cout << str << std::endl;

            std::map<size_t, scope::scope_t> scopes;
            parser_state = parse::parse(first, last, parser_state, scopes, firstLine);
            dump_tokens(scopes);
            lines++;

            // theme_tokens(scopes, theme);

            firstLine = false;

            // break;
        }
    }

    fclose(fp);

    return lines;
}

void test_markdown()
{
    grammar_ptr gm;
    gm = load("extensions/markdown-basics/syntaxes/markdown.tmLanguage.json");
    // std::cout << gm->document() << std::endl;

    Json::Value root = parse::loadJson("test-cases/themes/light_vs.json");
    theme_ptr theme = parse_theme(root);

    // FILE* fp = fopen("tests/cases/sqlite3.c", "r");
    FILE* fp = fopen("tests/cases/README.md", "r");
    // FILE* fp = fopen("tests/cases/tinywl.c", "r");
    char str[1024];

    for (int i = 0; i < 1; i++) {
        fseek(fp, 0, SEEK_SET);
        bool firstLine = true;
        parse::stack_ptr parser_state = gm->seed();
        while (fgets(str, 1000, fp)) {

            const char* first = str;
            const char* last = first + strlen(first);

            // std::cout << ".";
            std::cout << str << std::endl;

            std::map<size_t, scope::scope_t> scopes;
            parser_state = parse::parse(first, last, parser_state, scopes, firstLine);
            dump_tokens(scopes);

            // theme_tokens(scopes, theme);

            firstLine = false;

            // break;
        }
    }

    fclose(fp);
}

void test_stream()
{
    grammar_ptr gm;
    gm = load("extensions/cpp/syntaxes/cpp.tmLanguage.json");

    Json::Value root = parse::loadJson("test-cases/themes/light_vs.json");
    theme_ptr theme = parse_theme(root);

    std::ifstream file = std::ifstream("tests/cases/test.cpp", std::ifstream::in);

    int lines[32];

    std::string content;
    std::string line;
    size_t pos = file.tellg();
    size_t lineNo = 0;
    while (std::getline(file, line)) {
        lines[lineNo++] = pos;
        pos = file.tellg();
        content += line + "\n";
    }
    content += "\n\n";
    lines[lineNo] = pos;

    bool firstLine = true;
    parse::stack_ptr parser_state = gm->seed();

    const char* cstr = content.c_str();
    for (int i = 0; i < lineNo; i++) {
        const char* start = cstr + lines[i];
        size_t len = (cstr + lines[i + 1]) - start;
        std::string test = std::string(start, len);

        std::cout << test << std::endl;

        std::map<size_t, scope::scope_t> scopes;
        parser_state = parse::parse(start, start + len, parser_state, scopes, firstLine);
        dump_tokens(scopes);
        break;

        firstLine = false;
    }
    // printf("%s\n", content.c_str());
}

int main(int argc, char** argv)
{
    clock_t start, end;
    double cpu_time_used;
    start = clock();

    int lines = 1;

    // test_read_and_parse();
    // test_hello();
    // test_coffee();
    lines = test_c();
    // test_stream();

    // test_markdown();
    // test_plist();

    end = clock();
    cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;
    std::cout << std::endl
              << "done in " << cpu_time_used << "s " << (cpu_time_used/lines) << "s/line" << std::endl;
    return 0;
}