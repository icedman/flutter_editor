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

#include <set>
#include "extensions/util.h"

static request_list ssh_requests;

#define STRING_BUFFER_SIZE 2048

struct transport_t;

int sftp_run(std::string cmd, transport_t* transport);

struct transport_t {

    Json::Value json;
    request_t* req;

    // extracted at prepare
    std::string user;
    std::string url;
    std::string basePath;
    std::string entryPath;
    std::string password;
    std::string remotePath;
    std::string key;
    std::string keyPub;

    void prepare()
    {
        basePath = json["basePath"].asString();
        entryPath = json["path"].asString();
        // printf("%s\n", basePath.c_str());

        std::set<char> delims = { '@' };
        std::vector<std::string> spath = split_path(basePath, delims);
        if (spath.size() == 2) {
            user = spath[0];
            url = spath[1];
        }

        if (user.length() == 0 || url.length() == 0) {
            return;
        }

        password = json["passphrase"].asString();
        remotePath = entryPath;

        key = "";
        keyPub = "";
        if (json.isMember("identityKey") && json["identityKey"].asString().length() > 0) {
            key = json["identityKey"].asString();
            keyPub = key + ".pub";
        }
    }

    bool openDirectory(std::string path)
    {
        prepare();

        if (path.length() > 0) {
            remotePath = path;
        }

        sftp_run("dir", this);
        return true;
    }

    std::string localPath(std::string path)
    {
        std::string _path = path;
        _path += basePath; //json["basePath"].asString();

        std::ostringstream filePath;
        filePath << temporary_directory();
        filePath << "/";
        filePath << murmur_hash(_path.c_str(), _path.length(), 0xf1);
        filePath << ".tmp";
        return filePath.str();
    }

    std::string downloadFile(std::string path)
    {
        prepare();

        if (path.length() > 0) {
            remotePath = path;
        }

        sftp_run("download", this);
        return localPath(path);
    }

    std::string uploadFile(std::string path)
    {
        prepare();

        if (path.length() > 0) {
            remotePath = path;
        }

        sftp_run("upload", this);
        return localPath(path);
    }

    void run(std::string cmd) {
        prepare();
        sftp_run(cmd, this);
    }
};

int sftp_run(std::string cmd, transport_t* transport)
{
    const char* keyfile1 = "~/.ssh/id_rsa.pub";
    const char* keyfile2 = "~/.ssh/id_rsa";
    const char* username = "username";
    const char* password = "password";
    unsigned long hostaddr;
    int rc, sock, i, auth_pw = 0;
    struct sockaddr_in sin;
    const char* fingerprint;
    char* userauthlist;
    LIBSSH2_SESSION* session = NULL;
    const char* sftppath = "/tmp/directory";
    LIBSSH2_SFTP* sftp_session = NULL;
    LIBSSH2_SFTP_HANDLE* sftp_handle = NULL;

    request_t* req = transport->req;
    int error = 0;

    hostaddr = inet_addr(transport->url.c_str());
    username = transport->user.c_str();
    password = transport->password.c_str();
    sftppath = transport->remotePath.c_str();

    std::string filePath = transport->localPath(sftppath);

    // if download & filePath exists... no need to fetch
#ifdef WIN32
    WSADATA wsadata;
    int err;

    err = WSAStartup(MAKEWORD(2, 0), &wsadata);
    if (err != 0) {
        fprintf(stderr, "WSAStartup failed with error %d\n", err);
        req->response.push_back("error : WSAStartup failed");
        return -1;
    }
#endif

    // rc = libssh2_init(0);
    // if (rc != 0) {
    //     fprintf(stderr, "libssh2 initialization failed (%d)\n", rc);
    //     // req->response.push_back("libssh2 init failed");
    //     return 1;
    // }

    /*
     * The application code is responsible for creating the socket
     * and establishing the connection
     */
    sock = socket(AF_INET, SOCK_STREAM, 0);

    sin.sin_family = AF_INET;
    sin.sin_port = htons(22);
    sin.sin_addr.s_addr = hostaddr;
    if (connect(sock, (struct sockaddr*)(&sin),
            sizeof(struct sockaddr_in))
        != 0) {
        fprintf(stderr, "failed to connect!\n");
        req->response.push_back("error : socket connect failed");
        goto shutdown;
    }

    /* Create a session instance
     */
    session = libssh2_session_init();
    if (!session)
        goto shutdown;

    /* ... start it up. This will trade welcome banners, exchange keys,
     * and setup crypto, compression, and MAC layers
     */
    rc = libssh2_session_handshake(session, sock);
    if (rc) {
        fprintf(stderr, "Failure establishing SSH session: %d\n", rc);
        req->response.push_back("error : ssh handshake failed");
        goto shutdown;
    }

    /* At this point we havn't yet authenticated.  The first thing to do
     * is check the hostkey's fingerprint against our known hosts Your app
     * may have it hard coded, may go to a file, may present it to the
     * user, that's your call
     */
    fingerprint = libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA1);
    fprintf(stderr, "Fingerprint: ");
    for (i = 0; i < 20; i++) {
        fprintf(stderr, "%02X ", (unsigned char)fingerprint[i]);
    }
    fprintf(stderr, "\n");

    /* check what authentication methods are available */
    userauthlist = libssh2_userauth_list(session, username, strlen(username));
    fprintf(stderr, "Authentication methods: %s\n", userauthlist);
    if (strstr(userauthlist, "password") != NULL) {
        auth_pw |= 1;
    }
    if (strstr(userauthlist, "keyboard-interactive") != NULL) {
        auth_pw |= 2;
    }
    if (strstr(userauthlist, "publickey") != NULL) {
        auth_pw |= 4;
    }

    /* if we got an 5. argument we set this option if supported */
    if (auth_pw & 4 && transport->key.length() > 0) {
        auth_pw = 4;
        keyfile2 = transport->key.c_str();
        keyfile1 = transport->keyPub.c_str();
    }

    if (auth_pw & 1) {
        /* We could authenticate via password */
        if (libssh2_userauth_password(session, username, password)) {
            fprintf(stderr, "\tAuthentication by password failed!\n");
            printf("%s %s\n", username, password);
            req->response.push_back("error : authentication by password failed");
            goto shutdown;
        } else {
            fprintf(stderr, "\tAuthentication by password succeeded.\n");
        }
    }

    else if (auth_pw & 4) {
        /* Or by public key */
        if (libssh2_userauth_publickey_fromfile(session, username, keyfile1,
                keyfile2, password)) {
            fprintf(stderr, "\tAuthentication by public key failed! %s %s %s\n", keyfile1, keyfile2, password);
            req->response.push_back("error : authentication by public key failed");
            goto shutdown;
        } else {
            fprintf(stderr, "\tAuthentication by public key succeeded.\n");
        }
    } else {
        fprintf(stderr, "No supported authentication methods found!\n");
        goto shutdown;
    }

    fprintf(stderr, "libssh2_sftp_init()!\n");
    sftp_session = libssh2_sftp_init(session);

    if (!sftp_session) {
        fprintf(stderr, "Unable to init SFTP session\n");
        req->response.push_back("error : unable to init SFTP session");
        goto shutdown;
    }

    /* Since we have not set non-blocking, tell libssh2 we are blocking */
    libssh2_session_set_blocking(session, 1);

    if (cmd == "dir") {
        fprintf(stderr, "libssh2_sftp_opendir()!\n");
        /* Request a dir listing via SFTP */
        sftp_handle = libssh2_sftp_opendir(sftp_session, sftppath);

        if (!sftp_handle) {
            fprintf(stderr, "Unable to open dir with SFTP\n");
            req->response.push_back("error : unable to open dir with SFTP");
            goto shutdown;
        }
        fprintf(stderr, "libssh2_sftp_opendir() is done, now receive listing!\n");
        do {
            char mem[512];
            char longentry[512];
            LIBSSH2_SFTP_ATTRIBUTES attrs;

            /* loop until we fail */
            rc = libssh2_sftp_readdir_ex(sftp_handle, mem, sizeof(mem),
                longentry, sizeof(longentry), &attrs);

            if (rc > 0) {
                // todo
                // transport_entry_t entry;
                // entry.path = sftppath;
                // entry.path += "/";
                // entry.path += mem;
                // entry.fullPath = cleanPath(entry.path);
                // entry.isDirectory = false;
                // if (LIBSSH2_SFTP_S_ISDIR(attrs.permissions)) {
                //     entry.isDirectory = true;
                // }

                if (mem[0] != '.') {
                //     transport->entries.emplace_back(entry);
                    std::ostringstream filePath;
                    if (LIBSSH2_SFTP_S_ISDIR(attrs.permissions)) {
                        filePath << "dir;";
                    } else {
                        filePath << "file;";
                    }
                    filePath << sftppath;
                    filePath << "/";
                    filePath << mem;
                    req->response.push_back(clean_path(filePath.str()));
                }

            } else
                break;

        } while (1);

        libssh2_sftp_closedir(sftp_handle);
    }

    if (cmd == "download") {
        printf("download: %s >> %s\n", sftppath, filePath.c_str());

        sftp_handle = libssh2_sftp_open(sftp_session, sftppath, LIBSSH2_FXF_READ, 0);

        if (!sftp_handle) {
            fprintf(stderr, "Unable to open file with SFTP: %ld\n",
                libssh2_sftp_last_error(sftp_session));
            req->response.push_back("error : unable to open file with SFTP");
            goto shutdown;
        }

        FILE* fp = fopen(filePath.c_str(), "w");
        if (!fp) {
            libssh2_sftp_close(sftp_handle);
            goto shutdown;
        }

        fprintf(stderr, "libssh2_sftp_open() is done, now receive data!\n");
        do {
            char mem[1024];

            /* loop until we fail */
            fprintf(stderr, "libssh2_sftp_read()!\n");
            rc = libssh2_sftp_read(sftp_handle, mem, sizeof(mem));
            if (rc > 0) {
                // for (int i = 0; i < rc; i++) {
                //     printf("%c", mem[i]);
                // }
                fwrite(mem, sizeof(char), rc, fp);
                // write(1, mem, rc);
            } else {
                break;
            }
        } while (1);
        printf("\n");

        fclose(fp);
        libssh2_sftp_close(sftp_handle);
    }

    if (cmd == "upload") {
        char mem[STRING_BUFFER_SIZE];
        size_t nread;
        char* ptr;

        // struct stat fileinfo;

        std::string localPath = transport->localPath(transport->remotePath);
        FILE* fp = fopen(localPath.c_str(), "r");
        if (!fp) {
            fprintf(stderr, "Unable to open local file\n");
            req->response.push_back("error : unable to open local file");
            goto shutdown;
        }

        sftp_handle = libssh2_sftp_open(sftp_session, sftppath,
            LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC,
            LIBSSH2_SFTP_S_IRUSR | LIBSSH2_SFTP_S_IWUSR | LIBSSH2_SFTP_S_IRGRP | LIBSSH2_SFTP_S_IROTH);

        if (!sftp_handle) {
            fprintf(stderr, "Unable to open file with SFTP\n");
            req->response.push_back("error : unable to open file with SFTP");
            goto shutdown;
        }

        printf("upload: %s >> %s\n", localPath.c_str(), sftppath);

        fprintf(stderr, "libssh2_sftp_open() is done, now send data!\n");
        do {
            nread = fread(mem, sizeof(char), STRING_BUFFER_SIZE, fp);
            if (nread <= 0) {
                /* end of file */
                break;
            }
            ptr = mem;

            // for (int i = 0; i < nread; i++) {
            //     printf("%c", mem[i]);
            // }

            rc = 0;
            do {
                /* write data in a loop until we block */
                rc = libssh2_sftp_write(sftp_handle, ptr, nread);
                if (rc < 0)
                    break;
                ptr += rc;
                nread -= rc;
            } while (nread);

        } while (rc > 0);

        fclose(fp);
        libssh2_sftp_close(sftp_handle);
    }

    if (cmd == "mkdir") {
        rc = libssh2_sftp_mkdir(sftp_session, sftppath,
            LIBSSH2_SFTP_S_IRWXU | LIBSSH2_SFTP_S_IRGRP | LIBSSH2_SFTP_S_IXGRP | LIBSSH2_SFTP_S_IROTH | LIBSSH2_SFTP_S_IXOTH);
        if (rc) {
            fprintf(stderr, "libssh2_sftp_mkdir failed: %d\n", rc);
            req->response.push_back("error : unable to mkdir with SFTP");
            goto shutdown;
        }
    }

    if (cmd == "rmdir") {
        rc = libssh2_sftp_rmdir(sftp_session, sftppath);
        printf("delete %s\n", sftppath);
        if (rc) {
            fprintf(stderr, "libssh2_sftp_rmdir failed: %d\n", rc);
            req->response.push_back("error : unable to rmdir with SFTP");
            goto shutdown;
        }
    }

    if (cmd == "unlink") {
        rc = libssh2_sftp_unlink(sftp_session, sftppath);
        printf("delete %s\n", sftppath);
        if (rc) {
            fprintf(stderr, "libssh2_sftp_unlink failed: %d\n", rc);
            req->response.push_back("error : unable to unlink with SFTP");
            goto shutdown;
        }
    }

    if (cmd == "rename") {
        std::string destpath = transport->json["newPath"].asString();
        rc = libssh2_sftp_rename_ex(sftp_session, sftppath, strlen(sftppath),
            destpath.c_str(), destpath.length(),
            LIBSSH2_SFTP_S_IRWXU | LIBSSH2_SFTP_S_IRGRP | LIBSSH2_SFTP_S_IXGRP | LIBSSH2_SFTP_S_IROTH | LIBSSH2_SFTP_S_IXOTH);
        if (rc) {
            fprintf(stderr, "libssh2_sftp_rename_ex failed: %d\n", rc);
            req->response.push_back("error : unable to rename with SFTP");
            goto shutdown;
        }
    }

shutdown:

    if (sftp_session) {
        libssh2_sftp_shutdown(sftp_session);
    }

    if (session) {
        libssh2_session_disconnect(session, "Normal Shutdown");
        libssh2_session_free(session);
    }

    if (sock) {
#ifdef WIN32
        closesocket(sock);
#else
        close(sock);
#endif
    }
    fprintf(stderr, "all done\n");

    // // TODO req->response.push_back("done");
    // libssh2_exit();

    return 0;
}

void *ssh_thread(void *arg) {
  request_t *req = (request_t *)arg;

  Json::Value message = req->message.message["message"];
  std::string cmd = message["command"].asString();

  transport_t transport;
  transport.json = message;
  transport.req = req;
  transport.run(cmd);

  // printf(">%s\n", request->message
  // printf(">>>callback 1! %s\n", message.toStyledString().c_str());;

  req->state = request_t::state_e::Ready;
  return NULL;
}

void ssh_command_callback(message_t m, listener_t l) {
  std::string message = m.message["message"].toStyledString();
  for (auto r : ssh_requests) {
    std::string rmsg = r->message.message["message"].toStyledString();
    if (message == rmsg) {
      post_reply(m, "error: similar request is pending");
      return;
    }
  }

  request_ptr request = std::make_shared<request_t>();
  request->message = m;
  ssh_requests.push_back(request);
  pthread_create((pthread_t *)&(request->thread_id), NULL, &ssh_thread,
                 (void *)(request.get()));
}

void ssh_poll_callback(listener_t l) { poll_requests(ssh_requests); }

void ssh_init() {
  printf("ssh enabled\n");
  libssh2_init(0);
  add_listener("ssh_global", "sftp", &ssh_command_callback, &ssh_poll_callback);
}

void ssh_shutdown() {}
