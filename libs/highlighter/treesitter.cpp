#include "api.h"

#ifdef ENABLE_TREESITTER

extern "C" {
#include <tree_sitter/api.h>
const TSLanguage *tree_sitter_javascript(void);
const TSLanguage *tree_sitter_c(void);
#define LANGUAGE tree_sitter_c
}

#include <fstream>
#include <iostream>
#include <pthread.h>

static request_list treesitter_requests;

void *treesitter_thread(void *arg) {
  request_t *req = (request_t *)arg;

  Json::Value message = req->message.message["message"];
  std::string cmd = message["command"].asString();

  // printf(">%s\n", request->message
  // printf(">>>callback 1! %s\n", message.toStyledString().c_str());;

  req->state = request_t::state_e::Ready;
  return NULL;
}

void treesitter_command_callback(message_t m, listener_t l) {
  request_ptr request = std::make_shared<request_t>();
  request->message = m;
  treesitter_requests.push_back(request);
  pthread_create((pthread_t *)&(request->thread_id), NULL, &treesitter_thread,
                 (void *)(request.get()));
}

void treesitter_poll_callback(listener_t l) {
  poll_requests(treesitter_requests);
}

void walk_tree(TSTreeCursor *cursor, int depth, int line,
               std::vector<TSNode> *nodes) {
  TSNode node = ts_tree_cursor_current_node(cursor);
  int start = ts_node_start_byte(node);
  int end = ts_node_end_byte(node);

  const char *type = ts_node_type(node);
  TSPoint startPoint = ts_node_start_point(node);
  TSPoint endPoint = ts_node_end_point(node);
  if (line != -1 && (line < startPoint.row || line > endPoint.row)) {
    return;
  }

  if (startPoint.row == line || endPoint.row == line) {
    // for(int i=0; i<depth; i++) {
    //   printf(" ");
    // }
    printf("(%d,%d) (%d,%d) [ %s ]\n", startPoint.row, startPoint.column,
           endPoint.row, endPoint.column, type);
    if (nodes != NULL) {
      nodes->push_back(node);
    }
  }

  if (!ts_tree_cursor_goto_first_child(cursor)) {
    return;
  }

  do {
    walk_tree(cursor, depth + 1, line, nodes);
  } while (ts_tree_cursor_goto_next_sibling(cursor));
}

void build_tree(const char *buffer, int len, Document *doc) {
  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, LANGUAGE())) {
    fprintf(stderr, "Invalid language\n");
  }

  TSTree *tree = ts_parser_parse_string(parser, NULL, buffer, len);

  TSNode root_node = ts_tree_root_node(tree);
  TSTreeCursor cursor = ts_tree_cursor_new(root_node);

  doc->tree = tree;
  // ts_tree_delete(tree);
  ts_parser_delete(parser);
}

void rebuild_tree(Document *doc) {
  std::shared_ptr<Block> block = doc->start;
  doc->contents = "";
  while (block) {
    doc->contents += block->text;
    doc->contents += "\n";
    if (block->nextId == 0)
      break;
    // printf(">>%s\n", block->text.c_str());
    block = doc->blocks[block->nextId];
  }
  // printf(">%s\n", contents.c_str());

  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, LANGUAGE())) {
    fprintf(stderr, "Invalid language\n");
  }

  if (doc->tree) {
    ts_tree_delete(doc->tree);
  }

  TSTree *tree = ts_parser_parse_string(parser, NULL, doc->contents.c_str(),
                                        doc->contents.size());
  doc->contents = "";

  TSNode root_node = ts_tree_root_node(tree);
  TSTreeCursor cursor = ts_tree_cursor_new(root_node);
  // walk_tree(&cursor, 0, -1, NULL);

  doc->tree = tree;
  doc->rebuild = false;

  // ts_tree_delete(tree);
  ts_parser_delete(parser);
}

EXPORT
void run_tree_sitter(int documentId, char *path) {
  DocumentPtr doc = get_document(documentId);
  if (doc == NULL) {
    doc = std::make_shared<Document>();
  }

  if (strlen(path) > 0) {
    std::ifstream t(path);
    std::stringstream buffer;
    buffer << t.rdbuf();
    build_tree(buffer.str().c_str(), buffer.str().length(), doc.get());
    doc->rebuild = false;
  }
}

void treesitter_init() {
  printf("treesitter enabled\n");
  add_listener("treesitter_global", "treesitter", &treesitter_command_callback,
               &treesitter_poll_callback);
}

void treesitter_shutdown() {}

#endif