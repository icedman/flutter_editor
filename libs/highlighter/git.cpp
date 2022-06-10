#include "api.h"
#include <stdio.h>

extern "C" {
#include "git2.h"
}

#include <pthread.h>

char default_name[64] = {0};
char default_remote[64] = {0};
char default_branch[64] = {0};

#define BEGIN_PRINTLN                                                          \
  {                                                                            \
    std::ostringstream ss;

#define PUSH_PRINTLN(msg) ss << msg;

#define END_PRINTLN                                                            \
  req->response.push_back(ss.str());                                           \
  }

#define PRINTLN_LN req->response.push_back("");
#define PRINTF(a, b)                                                           \
  {                                                                            \
    char tmp[250];                                                             \
    sprintf(tmp, a, b);                                                        \
    PUSH_PRINTLN(tmp);                                                         \
  }
#define PUSH_PRINTLN_TAB ss << "\t";

#define GOTO_CLEANUP_ON_ERROR                                                  \
  {                                                                            \
    std::ostringstream ss;                                                     \
    ss << "error ";                                                            \
    ss << error;                                                               \
    ss << " : ";                                                               \
    ss << git_error_last()->message;                                           \
    req->response.push_back(ss.str());                                         \
    goto cleanup;                                                              \
  }

static int show_branch(git_repository *repo, request_t *req) {
  int error = 0;
  const char *branch = NULL;
  git_reference *head = NULL;

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

static request_list git_requests;

void *git_thread(void *arg) {
  request_t *req = (request_t *)arg;

  Json::Value message = req->message.message["message"];
  std::string cmd = message["command"].asString();
  if (cmd == "status") {
    _git_status(message, req);
  }
  if (cmd == "log") {
    _git_log(message, req);
  }

  // printf(">%s\n", request->message
  // printf(">>>callback 1! %s\n", message.toStyledString().c_str());;

  req->state = request_t::state_e::Ready;
  return NULL;
}

void git_command_callback(message_t m, listener_t l) {
  std::string message = m.message["message"].toStyledString();
  for (auto r : git_requests) {
    std::string rmsg = r->message.message["message"].toStyledString();
    if (message == rmsg) {
      printf("the same request is pending\n");
      return;
    }
  }
  printf(">>>%s\n", message.c_str());

  request_ptr request = std::make_shared<request_t>();
  request->message = m;
  git_requests.push_back(request);
  pthread_create((pthread_t *)&(request->thread_id), NULL, &git_thread,
                 (void *)(request.get()));
}

void git_poll_callback(listener_t l) { poll_requests(git_requests); }

void git_init() {
  printf("git enabled\n");
  strcpy(default_remote, "origin");
  git_libgit2_init();

  add_listener("git_global", "git", &git_command_callback, &git_poll_callback);
}

void git_shutdown() { git_libgit2_shutdown(); }
