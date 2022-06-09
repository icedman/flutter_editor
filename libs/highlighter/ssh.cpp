#include "api.h"
#include <stdio.h>

extern "C" {
#include "git2.h"
#include "libssh2.h"
#include "libssh2_sftp.h"
}

#include <pthread.h>

#define HAVE_SYS_SOCKET_H
// #define HAVE_NETINET_IN_H
#define HAVE_ARPA_INET_H

#ifdef HAVE_WINSOCK2_H
#include <winsock2.h>
#endif
#ifdef HAVE_SYS_SOCKET_H
#include <sys/socket.h>
#endif
#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_ARPA_INET_H
#include <arpa/inet.h>
#endif
#ifdef HAVE_INTTYPES_H
#include <inttypes.h>
#endif

#include <algorithm>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/types.h>

#ifdef WIN32
#define __FILESIZE "I64"
#else
#define __FILESIZE "llu"
#endif

static request_list ssh_requests;

void *ssh_thread(void *arg) {
    request_t *req = (request_t*)arg;

    Json::Value message = req->message.message["message"];
    std::string cmd = message["command"].asString();
    
    // printf(">%s\n", request->message
    // printf(">>>callback 1! %s\n", message.toStyledString().c_str());;

    req->state = request_t::state_e::Ready;
    return NULL;
}

void ssh_command_callback(message_t m, listener_t l) {
    request_ptr request = std::make_shared<request_t>();
    request->message = m;
    ssh_requests.push_back(request);
    pthread_create((pthread_t *)&(request->thread_id), NULL,
                 &ssh_thread, (void *)(request.get()));
}

void ssh_poll_callback(listener_t l) {
    poll_requests(ssh_requests);
}

void ssh_init()
{
    printf("ssh enabled\n");
    add_listener("ssh_global", "ssh", &ssh_command_callback, &ssh_poll_callback);
}

void ssh_shutdown()
{
}
