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
#include <json/json.h>
#include <memory>
#include <map>
#include "textmate.h"

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

typedef std::vector<message_t> message_list;
typedef std::vector<listener_t> listener_list;

int add_listener(std::string listener, std::string channel, std::function<void(message_t, listener_t)> callback);
void remove_listener(int id);
void post_message(message_t msg);
void dispatch_messages();

#endif // API_H