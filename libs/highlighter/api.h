#ifndef API_H
#define API_H

#ifdef WIN64
#define EXPORT __declspec(dllexport)
#else
#define EXPORT                                                                 \
  extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif

extern "C" {
#include <tree_sitter/api.h>
const TSLanguage *tree_sitter_javascript(void);
const TSLanguage *tree_sitter_c(void);
#define LANGUAGE tree_sitter_c
}

#include <functional>
#include <algorithm>
#include <memory>
#include <map>
#include <string>
#include <vector>
#include <json/json.h>
#include <time.h>
#include "textmate.h"

#define TIMER_BEGIN                                                            \
  clock_t start, end;                                                          \
  double cpu_time_used;                                                        \
  start = clock();

#define TIMER_RESET start = clock();

#define TIMER_END                                                              \
  end = clock();                                                               \
  cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;

void delay(int ms);

class Block : public block_data_t {
public:
  Block() : block_data_t(), blockId(0), nextId(0)
  {}

  std::string text;
  int blockId;
  int nextId;
};

typedef std::shared_ptr<Block> BlockPtr;

class Document {
public:
  Document();
  ~Document();

  int documentId;
  bool rebuild;
  std::string path;
  std::string contents;
  std::map<size_t, BlockPtr> blocks;
  TSTree *tree;

  BlockPtr start;
};

typedef std::shared_ptr<Document> DocumentPtr;

DocumentPtr get_document(int id);

struct message_t {
    int messageId;
    std::string receiver;
    std::string sender;
    std::string channel;
    Json::Value message;
};

struct listener_t {
    int listenerId;
    std::string listener;
    std::string channel;
    std::function<void(message_t, listener_t)> callback;
    std::function<void(listener_t)> poll;
};

#define REQUEST_TTL 30

struct request_t {
public:
  enum state_e { Waiting, Ready, Consumed };

  request_t() : state(state_e::Waiting), ttl(REQUEST_TTL), thread_id(0) {}

  state_e state;
  int ttl;
  long thread_id;

  message_t message;
  std::vector<std::string> response;
  
  void set_ready() { state = state_e::Ready; }
  void set_consumed() { state = state_e::Consumed; }
  void keep_alive() { ttl = REQUEST_TTL; }
  bool is_disposable() {
    if (state < state_e::Ready) {
      return false;
    }
    return --ttl <= 0;
  }
};

typedef std::shared_ptr<request_t> request_ptr;
typedef std::vector<request_ptr> request_list;

typedef std::vector<message_t> message_list;
typedef std::vector<listener_t> listener_list;

int add_listener(std::string listener, std::string channel,
  std::function<void(message_t, listener_t)> message_callback,
  std::function<void(listener_t)> poll_callback);
void remove_listener(int id);
void post_message(message_t msg);
void dispatch_messages();
void poll_requests(request_list requests);

#endif // API_H
