enum {
  OUTPUT_DIFF = (1 << 0),
  OUTPUT_STAT = (1 << 1),
  OUTPUT_SHORTSTAT = (1 << 2),
  OUTPUT_NUMSTAT = (1 << 3),
  OUTPUT_SUMMARY = (1 << 4)
};

enum { CACHE_NORMAL = 0, CACHE_ONLY = 1, CACHE_NONE = 2 };

/** The 'opts' struct captures all the various parsed command line options. */
struct diff_opts {
  git_diff_options diffopts;
  git_diff_find_options findopts;
  int color;
  int cache;
  int output;
  git_diff_format_t format;
  const char *treeish1;
  const char *treeish2;
  const char *dir;
  bool begin;
};

struct diff_color_print_t {
  int color;
  request_t *req;
  diff_opts *opts;
};

static const char *colors[] = {
    "\033[m",   /* reset */
    "\033[1m",  /* bold */
    "\033[31m", /* red */
    "\033[32m", /* green */
    "\033[36m"  /* cyan */
};

static const char *_colors[] = {
    "",      /* reset */
    "bold",  /* bold */
    "red",   /* red */
    "green", /* green */
    "cyan"   /* cyan */
};

int diff_output(const git_diff_delta *d, const git_diff_hunk *h,
                const git_diff_line *l, void *p, request_t *req,
                diff_opts *opts) {
  FILE *fp = (FILE *)p;

  (void)d;
  (void)h;

  std::ostringstream ss;
  if (l->origin == GIT_DIFF_LINE_CONTEXT ||
      l->origin == GIT_DIFF_LINE_ADDITION ||
      l->origin == GIT_DIFF_LINE_DELETION) {
    if (fp)
      fputc(l->origin, fp);
    ss << l->origin;
  }

  // git diff path_spec:git_diff.inc.cpp
  if (fp)
    fwrite(l->content, 1, l->content_len, fp);
  ss << std::string(l->content, l->content_len);

  // printf("%s\n", ss.str().c_str());

  std::string s = ss.str();
  if (s.find("diff --git") != std::string::npos) {
    std::string path = opts->dir;
    opts->begin = (s.find(path) != std::string::npos);
  }

  if (!opts->begin) {
    return 0;
  }

  req->response.push_back(ss.str());
  return 0;
}

/** This implements very rudimentary colorized output. */
static int diff_color_printer(const git_diff_delta *delta,
                              const git_diff_hunk *hunk,
                              const git_diff_line *line, void *data) {
  diff_color_print_t *payload = (diff_color_print_t *)data;
  // int *last_color = (int*)data, color = 0;
  int last_color = payload->color;
  request_t *req = payload->req;
  int color = 0;

  diff_opts *opts = payload->opts;

  (void)delta;
  (void)hunk;

  if (last_color >= 0) {
    switch (line->origin) {
    case GIT_DIFF_LINE_ADDITION:
      color = 3;
      break;
    case GIT_DIFF_LINE_DELETION:
      color = 2;
      break;
    case GIT_DIFF_LINE_ADD_EOFNL:
      color = 3;
      break;
    case GIT_DIFF_LINE_DEL_EOFNL:
      color = 2;
      break;
    case GIT_DIFF_LINE_FILE_HDR:
      color = 1;
      break;
    case GIT_DIFF_LINE_HUNK_HDR:
      color = 4;
      break;
    default:
      break;
    }

    if (color != last_color) {
      // if (last_color == 1 || color == 1)
      //     fputs(colors[0], stdout);
      // fputs(colors[color], stdout);
      // req->response.push_back(_colors[color]);
      last_color = color;
    }
  }

  return diff_output(delta, hunk, line, NULL /*stdout*/, req, opts);
}

/** Display diff output with "--stat", "--numstat", or "--shortstat" */
static void diff_print_stats(git_diff *diff, struct diff_opts *o,
                             request_t *req) {
  git_diff_stats *stats;
  git_buf b = GIT_BUF_INIT_CONST(NULL, 0);
  // git_diff_stats_format_t format = GIT_DIFF_STATS_NONE;
  int format = 0;

  int error = 0;

  error = git_diff_get_stats(&stats, diff);
  if (error < 0) {
    goto cleanup;
  }

  if (o->output & OUTPUT_STAT)
    format |= GIT_DIFF_STATS_FULL;
  if (o->output & OUTPUT_SHORTSTAT)
    format |= GIT_DIFF_STATS_SHORT;
  if (o->output & OUTPUT_NUMSTAT)
    format |= GIT_DIFF_STATS_NUMBER;
  if (o->output & OUTPUT_SUMMARY)
    format |= GIT_DIFF_STATS_INCLUDE_SUMMARY;

  // GIT_EXTERN(int) git_diff_stats_to_buf(
  //     git_buf *out,
  //     const git_diff_stats *stats,
  //     git_diff_stats_format_t format,
  //     size_t width);

  error = git_diff_stats_to_buf(&b, stats, (git_diff_stats_format_t)format, 80);
  if (error < 0) {
    goto cleanup;
  }

  fputs(b.ptr, stdout);
  // req->response.push_back(b.ptr);

cleanup:

  git_buf_dispose(&b);
  git_diff_stats_free(stats);
}

void treeish_to_tree(git_tree **out, git_repository *repo, const char *treeish,
                     request_t *req) {
  git_object *obj = NULL;
  int error = 0;
  error = git_revparse_single(&obj, repo, treeish);
  if (error < 0) {
    GOTO_CLEANUP_ON_ERROR
  }

  error = git_object_peel((git_object **)out, obj, GIT_OBJECT_TREE);
  if (error < 0) {
    GOTO_CLEANUP_ON_ERROR
  }

cleanup:
  git_object_free(obj);
}

int _git_diff(Json::Value json, request_t *req) {
  std::string localPath = json["path"].asString();
  std::string pathSpec = json["path_spec"].asString().c_str();

  if (pathSpec.length() > localPath.length()) {
    pathSpec = pathSpec.substr(localPath.length() + 1);
  }

  if (pathSpec.length() == 0) {
    pathSpec = ".";
  }

  req->response.push_back("diff");
  int error = 0;
  git_repository *repo = NULL;
  git_tree *t1 = NULL, *t2 = NULL;
  git_diff *diff;
  struct diff_opts o = {GIT_DIFF_OPTIONS_INIT,
                        GIT_DIFF_FIND_OPTIONS_INIT,
                        -1,
                        0,
                        0,
                        GIT_DIFF_FORMAT_PATCH,
                        NULL,
                        NULL,
                        pathSpec.c_str(),
                        pathSpec.length() == 1};

  const char *git_base_path = localPath.c_str();
  error = open_repository(&repo, git_base_path);
  if (error < 0) {
    GOTO_CLEANUP_ON_ERROR
  }

  /**
   * Possible argument patterns:
   *
   *  * &lt;sha1&gt; &lt;sha2&gt;
   *  * &lt;sha1&gt; --cached
   *  * &lt;sha1&gt;
   *  * --cached
   *  * --nocache (don't use index data in diff at all)
   *  * nothing
   *
   * Currently ranged arguments like &lt;sha1&gt;..&lt;sha2&gt; and
   * &lt;sha1&gt;...&lt;sha2&gt; are not supported in this example
   */

  if (o.treeish1)
    treeish_to_tree(&t1, repo, o.treeish1, req);
  if (o.treeish2)
    treeish_to_tree(&t2, repo, o.treeish2, req);

  if (t1 && t2) {
    error = git_diff_tree_to_tree(&diff, repo, t1, t2, &o.diffopts);
    if (error < 0) {
      GOTO_CLEANUP_ON_ERROR
    }
  } else if (o.cache != CACHE_NORMAL) {
    if (!t1)
      treeish_to_tree(&t1, repo, "HEAD", req);

    if (o.cache == CACHE_NONE) {
      error = git_diff_tree_to_workdir(&diff, repo, t1, &o.diffopts);
      if (error < 0) {
        GOTO_CLEANUP_ON_ERROR
      }
    } else {
      error = git_diff_tree_to_index(&diff, repo, t1, NULL, &o.diffopts);
      if (error < 0) {
        GOTO_CLEANUP_ON_ERROR
      }
    }
  } else if (t1) {
    error = git_diff_tree_to_workdir_with_index(&diff, repo, t1, &o.diffopts);
    if (error < 0) {
      GOTO_CLEANUP_ON_ERROR
    }
  } else {
    error = git_diff_index_to_workdir(&diff, repo, NULL, &o.diffopts);
    if (error < 0) {
      GOTO_CLEANUP_ON_ERROR
    }
  }

  /** Apply rename and copy detection if requested. */
  if ((o.findopts.flags & GIT_DIFF_FIND_ALL) != 0) {
    error = git_diff_find_similar(diff, &o.findopts);
    if (error < 0) {
      GOTO_CLEANUP_ON_ERROR
    }
  }

  /** Generate simple output using libgit2 display helper. */

  if (!o.output)
    o.output = OUTPUT_DIFF;

  if (o.output != OUTPUT_DIFF)
    diff_print_stats(diff, &o, req);

  if ((o.output & OUTPUT_DIFF) != 0) {
    if (o.color >= 0)
      fputs(colors[0], stdout);

    diff_color_print_t pr;
    pr.color = o.color;
    pr.req = req;
    pr.opts = &o;

    error = git_diff_print(diff, o.format, diff_color_printer, &pr);
    if (error < 0) {
      GOTO_CLEANUP_ON_ERROR
    }

    if (o.color >= 0)
      fputs(colors[0], stdout);
  }

  /** Cleanup before exiting. */

cleanup:
  git_repository_free(repo);

  req->response.push_back("done");
  return error;
}