#include "api.h"
#include <stdio.h>

extern "C" {
#include "git2.h"
}

#include <json/json.h>
#include <pthread.h>

#include <string>
#include <iostream>

char default_name[64] = { 0 };
char default_remote[64] = { 0 };
char default_branch[64] = { 0 };

#define BEGIN_PRINTLN \
    {                 \
        std::ostringstream ss;

#define PUSH_PRINTLN(msg) ss << msg;

#define END_PRINTLN                    \
    printf("%s\n", ss.str().c_str()); \
    }

#define PRINTLN_LN printf("\n");
#define PRINTF(a, b) { char tmp[250]; sprintf(tmp, a, b); PUSH_PRINTLN(tmp); }
#define PUSH_PRINTLN_TAB ss << "\t";

#define GOTO_CLEANUP_ON_ERROR              \
    {                                      \
        std::ostringstream ss;             \
        ss << "error ";                    \
        ss << error;                       \
        ss << " : ";                       \
        ss << git_error_last()->message;   \
        printf("%s\n", ss.str().c_str()); \
        goto cleanup;                      \
    }

static int show_branch(git_repository* repo, int group)
{
    int error = 0;
    const char* branch = NULL;
    git_reference* head = NULL;

    error = git_repository_head(&head, repo);

    if (error == GIT_EUNBORNBRANCH || error == GIT_ENOTFOUND)
        branch = NULL;
    else if (!error) {
        branch = git_reference_shorthand(head);
        strcpy(default_branch, branch);
    } else if (error < 0) {
        GOTO_CLEANUP_ON_ERROR
    }
    // check_lg2(error, "failed to get current branch", NULL);

    // if (format == FORMAT_LONG)
    //     _printf("# On branch %s\n",
    //         branch ? branch : "Not currently on any branch.");
    // else
    //     _printf("## %s\n", branch ? branch : "HEAD (no branch)");

    BEGIN_PRINTLN
    // PUSH_PRINTLN("branch: ");
    if (branch) {
        PUSH_PRINTLN(branch);
    } else {
        PUSH_PRINTLN("HEAD (no branch)");
    }
    END_PRINTLN
    PRINTLN_LN

cleanup:
    git_reference_free(head);
    return error;
}

#include "git/git_status.inc.cpp"

EXPORT
void git_init()
{
    printf(">git init\n");
    strcpy(default_remote, "origin");
    git_libgit2_init();

    Json::Value obj;
    obj["path"] = "./";
    // _git_log(obj, 0);
    _git_status(obj, 0);
}

EXPORT
void git_shutdown()
{
    git_libgit2_shutdown();
}
