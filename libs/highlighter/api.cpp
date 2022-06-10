#include "api.h"

std::map<size_t, DocumentPtr> documents;

void delay(int ms) {
  struct timespec waittime;
  waittime.tv_sec = (ms / 1000);
  ms = ms % 1000;
  waittime.tv_nsec = ms * 1000 * 1000;
  nanosleep(&waittime, NULL);
}

DocumentPtr get_document(int id) { return documents[id]; }

EXPORT
void create_document(int documentId, char *path) {
  if (documents[documentId] == NULL) {
    documents[documentId] = std::make_shared<Document>();
    if (path != NULL) {
      documents[documentId]->path = path;
    }
  }
}

EXPORT
void destroy_document(int documentId) { documents[documentId] = NULL; }

EXPORT
void add_block(int documentId, int blockId, int line) {
  if (documents[documentId] == NULL) {
    return;
  }
  if (documents[documentId]->blocks[blockId] == NULL) {
    documents[documentId]->blocks[blockId] = std::make_shared<Block>();
  }
}

EXPORT
void remove_block(int documentId, int blockId, int line) {
  if (documents[documentId] == NULL) {
    return;
  }
  documents[documentId]->blocks[blockId] = NULL;
}

EXPORT
void set_block(int documentId, int blockId, int line, char *text) {
  if (documents[documentId] == NULL) {
    create_document(documentId, NULL);
  }
  if (documents[documentId]->blocks[blockId] == NULL) {
    documents[documentId]->blocks[blockId] = std::make_shared<Block>();
  }

  if (documents[documentId]->blocks[blockId]->text != text) {
    // printf(">>[%s]\n[%s]\n",
    // documents[documentId]->blocks[blockId]->text.c_str(), text);
    documents[documentId]->blocks[blockId]->text = text;
    documents[documentId]->rebuild = true;
  }
  if (line == 0) {
    documents[documentId]->start = documents[documentId]->blocks[blockId];
  }
}

#define BUFF_LEN (1024 * 8)

static char _result[BUFF_LEN];
static int _listenerId = 0xff00;
static int _messageId = 0xff00;

static message_list incoming;
static message_list outgoing;
static listener_list listeners;

/*
void cb1(message_t m, listener_t l) {
    printf(">>>callback 1! %s\n", m.message.toStyledString().c_str());
}

void cb2(message_t m, listener_t l) {
    printf(">>>callback 2!\n");

    Json::Value json;
    json = "hello";

    message_t response = {
        .messageId = 0,
        .receiver = "whoever",
        .sender = "native",
        .channel = "",
        .message = json
    };

    post(response);
}

EXPORT void test()
{
    listeners.clear();
    add_listener("me", "lobby", &cb1, NULL);
    add_listener("me2", "lobby", &cb2, NULL);
    printf("listening...\n");
}
*/

EXPORT void send_message(char *message) {
  _messageId++;

  Json::Value json;
  Json::Reader reader;
  reader.parse(message, json);

  message_t m = {.messageId = _messageId,
                 .receiver = json["to"].asString(),
                 .sender = json["from"].asString(),
                 .channel = json["channel"].asString(),
                 .message = json};

  incoming.emplace_back(m);

  // printf(">%zu [%s] [%s]\n", incoming.size(), m.receiver.c_str(),
  // m.sender.c_str());
}

EXPORT char *receive_message() {
  strcpy(_result, "");
  if (outgoing.size() == 0)
    return _result;

  message_t m = outgoing[0];
  outgoing.erase(outgoing.begin());
  // printf("...%zu\n", outgoing.size());

  Json::Value json = m.message;
  json["to"] = m.receiver;
  json["from"] = m.sender;
  // json["channel"] = m.channel;
  // json["message"] = m.message;

  std::string res = json.toStyledString();
  if (res.length() >= BUFF_LEN) {
    strcpy(_result, "");
  } else {
    strcpy(_result, res.c_str());
  }

  return _result;
}

EXPORT int poll_messages() {
  dispatch_messages();
  return outgoing.size();
}

int add_listener(std::string listener, std::string channel,
                 std::function<void(message_t, listener_t)> message_callback,
                 std::function<void(listener_t)> poll_callback) {
  _listenerId++;
  listener_t l = {.listenerId = _listenerId,
                  .listener = listener,
                  .channel = channel,
                  .callback = message_callback,
                  .poll = poll_callback};
  listeners.emplace_back(l);
  return _listenerId;
}

void remove_listener(int id) {
  std::vector<listener_t>::iterator it = listeners.begin();
  while (it != listeners.end()) {
    if ((*it).listenerId == id) {
      listeners.erase(it);
      break;
    }
    it++;
  }
}

void post_message(message_t msg) {
  // check lock
  outgoing.emplace_back(msg);
}

void dispatch_messages() {
  // printf("dispatch_messages %d %d!\n", incoming.size(), listeners.size());
  // read incoming and dispatch

  int idx = 0;
  for (auto m : incoming) {
    for (auto l : listeners) {
      if ((m.receiver != "" && m.receiver != l.listener) ||
          (m.channel != "" && m.channel != l.channel)) {
        continue;
      }
      if (l.callback) {
        l.callback(m, l);
      }
    }
  }
  incoming.clear();

  for (auto l : listeners) {
    if (l.poll) {
      l.poll(l);
    }
  }
}

void poll_requests(request_list &requests) {
  std::vector<request_ptr> disposables;
  for (auto r : requests) {
    if (r->state < request_t::state_e::Ready) {
      continue;
    }
    // for(auto res : r->response) {
    //     printf(">%s\n", res.c_str());
    // }
    r->state = request_t::state_e::Consumed;
    disposables.push_back(r);
  }

  for (request_ptr d : disposables) {
    auto it = std::find(requests.begin(), requests.end(), d);
    if (it != requests.end()) {
      d->message.message["message"] = Json::arrayValue;
      for (auto r : d->response) {
        d->message.message["message"].append(r);
      }
      post_message(d->message);
      requests.erase(it);
    }
  }
}