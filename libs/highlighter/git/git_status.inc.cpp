static int print_long(git_status_list *status, request_t *req);
static int print_short(git_repository *repo, git_status_list *status,
                       request_t *req);
static int print_submod(git_submodule *sm, const char *name, void *payload,
                        request_t *req);

/**
 * This function print out an output similar to git's status command
 * in long form, including the command-line hints.
 */
static int print_long(git_status_list *status, request_t *req) {
  size_t i, maxi = git_status_list_entrycount(status);
  const git_status_entry *s;
  int header = 0, changes_in_index = 0;
  int changed_in_workdir = 0, rm_in_workdir = 0;
  const char *old_path, *new_path;

  /** Print index changes. */

  for (i = 0; i < maxi; ++i) {
    std::string istatus;

    s = git_status_byindex(status, i);

    if (s->status == GIT_STATUS_CURRENT)
      continue;

    if (s->status & GIT_STATUS_WT_DELETED)
      rm_in_workdir = 1;

    if (s->status & GIT_STATUS_INDEX_NEW)
      istatus = "new file: ";
    if (s->status & GIT_STATUS_INDEX_MODIFIED)
      istatus = "modified: ";
    if (s->status & GIT_STATUS_INDEX_DELETED)
      istatus = "deleted:  ";
    if (s->status & GIT_STATUS_INDEX_RENAMED)
      istatus = "renamed:  ";
    if (s->status & GIT_STATUS_INDEX_TYPECHANGE)
      istatus = "typechange:";

    if (istatus == "")
      continue;

    if (!header) {
      // printf("# Changes to be committed:\n");
      // printf("#   (use \"git reset HEAD <file>...\" to unstage)\n");
      // printf("#\n");
      req->response.push_back("# Changes to be commited:");
      header = 1;
    }

    old_path = s->head_to_index->old_file.path;
    new_path = s->head_to_index->new_file.path;

    if (old_path && new_path && strcmp(old_path, new_path)) {
      // printf("#\t%s  %s -> %s\n", istatus.c_str(), old_path, new_path);
      BEGIN_PRINTLN
      PUSH_PRINTLN_TAB
      PUSH_PRINTLN(istatus);
      PUSH_PRINTLN(" ");
      PUSH_PRINTLN(old_path);
      PUSH_PRINTLN(" -> ");
      PUSH_PRINTLN(new_path);
      END_PRINTLN
    } else {
      // printf("#\t%s  %s\n", istatus.c_str(), old_path ? old_path : new_path);
      BEGIN_PRINTLN
      PUSH_PRINTLN_TAB
      PUSH_PRINTLN(istatus);
      PUSH_PRINTLN(" ");
      if (old_path) {
        PUSH_PRINTLN(old_path);
      } else {
        PUSH_PRINTLN(new_path);
      }
      END_PRINTLN
    }
  }

  if (header) {
    changes_in_index = 1;
    // printf("#\n");
    PRINTLN_LN
  }
  header = 0;

  /** Print workdir changes to tracked files. */

  for (i = 0; i < maxi; ++i) {
    std::string wstatus;

    s = git_status_byindex(status, i);

    /**
     * With `GIT_STATUS_OPT_INCLUDE_UNMODIFIED` (not used in this example)
     * `index_to_workdir` may not be `NULL` even if there are
     * no differences, in which case it will be a `GIT_DELTA_UNMODIFIED`.
     */
    if (s->status == GIT_STATUS_CURRENT || s->index_to_workdir == NULL)
      continue;

    /** Print out the output since we know the file has some changes */
    if (s->status & GIT_STATUS_WT_MODIFIED)
      wstatus = "modified: ";
    if (s->status & GIT_STATUS_WT_DELETED)
      wstatus = "deleted:  ";
    if (s->status & GIT_STATUS_WT_RENAMED)
      wstatus = "renamed:  ";
    if (s->status & GIT_STATUS_WT_TYPECHANGE)
      wstatus = "typechange:";

    if (wstatus == "")
      continue;

    if (!header) {
      req->response.push_back("# Changes not staged for commit:");
      // printf("# Changes not staged for commit:\n");
      // printf("#   (use \"git add%s <file>...\" to update what will be
      // committed)\n", rm_in_workdir ? "/rm" : ""); printf("#   (use \"git
      // checkout -- <file>...\" to discard changes in working directory)\n");
      // printf("#\n");
      header = 1;
    }

    old_path = s->index_to_workdir->old_file.path;
    new_path = s->index_to_workdir->new_file.path;

    if (old_path && new_path && strcmp(old_path, new_path)) {
      // printf("#\t%s  %s -> %s\n", wstatus.c_str(), old_path, new_path);
      BEGIN_PRINTLN
      PUSH_PRINTLN_TAB
      PUSH_PRINTLN(wstatus);
      PUSH_PRINTLN(" ");
      PUSH_PRINTLN(old_path);
      PUSH_PRINTLN(" -> ");
      PUSH_PRINTLN(new_path);
      END_PRINTLN
    } else {
      BEGIN_PRINTLN
      PUSH_PRINTLN_TAB
      PUSH_PRINTLN(wstatus);
      PUSH_PRINTLN(" ");
      if (old_path) {
        PUSH_PRINTLN(old_path);
      } else {
        PUSH_PRINTLN(new_path);
      }
      END_PRINTLN

      // printf("#\t%s %s\n", wstatus.c_str(), old_path ? old_path : new_path);
    }
  }

  if (header) {
    changed_in_workdir = 1;
    // printf("#\n");
    PRINTLN_LN
  }

  /** Print untracked files. */

  header = 0;

  for (i = 0; i < maxi; ++i) {
    s = git_status_byindex(status, i);

    if (s->status == GIT_STATUS_WT_NEW) {

      if (!header) {
        req->response.push_back("# Untracked files:");
        // printf("# Untracked files:\n");
        // printf("#   (use \"git add <file>...\" to include in what will be
        // committed)\n"); printf("#\n");
        header = 1;
      }

      // printf("\t%s\n", s->index_to_workdir->old_file.path);
      BEGIN_PRINTLN
      PUSH_PRINTLN_TAB
      PUSH_PRINTLN(s->index_to_workdir->old_file.path);
      END_PRINTLN
    }
  }

  header = 0;

  /** Print ignored files. */
  for (i = 0; i < maxi; ++i) {
    s = git_status_byindex(status, i);

    if (s->status == GIT_STATUS_IGNORED) {

      if (!header) {
        req->response.push_back("# Ignored files:");
        // printf("#   (use \"git add -f <file>...\" to include in what will be
        // committed)\n"); printf("#\n");
        header = 1;
      }

      // printf("#\t%s\n", s->index_to_workdir->old_file.path);
      BEGIN_PRINTLN
      PUSH_PRINTLN_TAB
      PUSH_PRINTLN(s->index_to_workdir->old_file.path);
      END_PRINTLN
    }
  }

  if (!changes_in_index && changed_in_workdir) {
    // printf("# no changes added to commit (use \"git add\" and/or \"git commit
    // -a\")\n");
    req->response.push_back("# no changes added to commit (use \"git add\" "
                            "and/or \"git commit -a\")");
  }

  return 0;
}

/**
 * This version of the output prefixes each path with two status
 * columns and shows submodule status information.
 */
static int print_short(git_repository *repo, git_status_list *status,
                       request_t *req) {
  size_t i, maxi = git_status_list_entrycount(status);
  const git_status_entry *s;
  char istatus, wstatus;
  const char *extra, *a, *b, *c;

  for (i = 0; i < maxi; ++i) {
    s = git_status_byindex(status, i);

    if (s->status == GIT_STATUS_CURRENT)
      continue;

    a = b = c = NULL;
    istatus = wstatus = ' ';
    extra = "";

    if (s->status & GIT_STATUS_INDEX_NEW)
      istatus = 'A';
    if (s->status & GIT_STATUS_INDEX_MODIFIED)
      istatus = 'M';
    if (s->status & GIT_STATUS_INDEX_DELETED)
      istatus = 'D';
    if (s->status & GIT_STATUS_INDEX_RENAMED)
      istatus = 'R';
    if (s->status & GIT_STATUS_INDEX_TYPECHANGE)
      istatus = 'T';

    if (s->status & GIT_STATUS_WT_NEW) {
      if (istatus == ' ')
        istatus = '?';
      wstatus = '?';
    }
    if (s->status & GIT_STATUS_WT_MODIFIED)
      wstatus = 'M';
    if (s->status & GIT_STATUS_WT_DELETED)
      wstatus = 'D';
    if (s->status & GIT_STATUS_WT_RENAMED)
      wstatus = 'R';
    if (s->status & GIT_STATUS_WT_TYPECHANGE)
      wstatus = 'T';

    if (s->status & GIT_STATUS_IGNORED) {
      istatus = '!';
      wstatus = '!';
    }

    if (istatus == '?' && wstatus == '?')
      continue;

    /**
     * A commit in a tree is how submodules are stored, so
     * let's go take a look at its status.
     */
    if (s->index_to_workdir &&
        s->index_to_workdir->new_file.mode == GIT_FILEMODE_COMMIT) {
      unsigned int smstatus = 0;

      if (!git_submodule_status(&smstatus, repo,
                                s->index_to_workdir->new_file.path,
                                GIT_SUBMODULE_IGNORE_UNSPECIFIED)) {
        if (smstatus & GIT_SUBMODULE_STATUS_WD_MODIFIED)
          extra = " (new commits)";
        else if (smstatus & GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED)
          extra = " (modified content)";
        else if (smstatus & GIT_SUBMODULE_STATUS_WD_WD_MODIFIED)
          extra = " (modified content)";
        else if (smstatus & GIT_SUBMODULE_STATUS_WD_UNTRACKED)
          extra = " (untracked content)";
      }
    }

    /**
     * Now that we have all the information, format the output.
     */

    if (s->head_to_index) {
      a = s->head_to_index->old_file.path;
      b = s->head_to_index->new_file.path;
    }
    if (s->index_to_workdir) {
      if (!a)
        a = s->index_to_workdir->old_file.path;
      if (!b)
        b = s->index_to_workdir->old_file.path;
      c = s->index_to_workdir->new_file.path;
    }

    if (istatus == 'R') {
      if (wstatus == 'R')
        printf("%c%c %s %s %s%s\n", istatus, wstatus, a, b, c, extra);
      else
        printf("%c%c %s %s%s\n", istatus, wstatus, a, b, extra);
    } else {
      if (wstatus == 'R')
        printf("%c%c %s %s%s\n", istatus, wstatus, a, c, extra);
      else
        printf("%c%c %s%s\n", istatus, wstatus, a, extra);
    }
  }

  for (i = 0; i < maxi; ++i) {
    s = git_status_byindex(status, i);

    if (s->status == GIT_STATUS_WT_NEW)
      printf("?? %s\n", s->index_to_workdir->old_file.path);
  }

  return 0;
}

static int print_submod(git_submodule *sm, const char *name, void *payload,
                        request_t *req) {
#if 0
    int *count = payload;
    (void)name;

    if (*count == 0)
        printf("# Submodules\n");
    (*count)++;

    printf("# - submodule '%s' at %s\n",
        git_submodule_name(sm), git_submodule_path(sm));
#endif
  return 0;
}

int _git_status(Json::Value json, request_t *req) {
  std::string localPath = json["path"].asString().c_str();
  git_status_list *status = NULL;
  git_status_options statusopt = GIT_STATUS_OPTIONS_INIT;

  statusopt.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;
  statusopt.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED |
                    GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX |
                    GIT_STATUS_OPT_SORT_CASE_SENSITIVELY;
  git_repository *repo = nullptr;

  int error = git_repository_open(&repo, localPath.c_str());
  if (error < 0) {
    GOTO_CLEANUP_ON_ERROR
  }

  if (git_repository_is_bare(repo)) {
    req->response.push_back("error : repository is bare");
    goto cleanup;
  }

  error = show_branch(repo, req);
  if (error < 0) {
    GOTO_CLEANUP_ON_ERROR
  }

  error = git_status_list_new(&status, repo, &statusopt);
  if (error < 0) {
    // check_lg2(error, "Could not get status", NULL);
    GOTO_CLEANUP_ON_ERROR
  }

  error = print_long(status, req);

cleanup:
  git_status_list_free(status);
  git_repository_free(repo);

  if (error >= 0) {
    req->response.push_back("done");
  }
  return error;
}

int _git_log(Json::Value json, request_t *req) {
  req->response.push_back("walk");

  std::string localPath = json["path"].asString().c_str();

  git_revwalk *walker = nullptr;

  {
    std::ostringstream ss;
    ss << localPath;
    req->response.push_back(ss.str());
  }

  git_repository *repo = nullptr;
  int error = git_repository_open(&repo, localPath.c_str());
  if (error < 0) {
    GOTO_CLEANUP_ON_ERROR
  }

  git_revwalk_new(&walker, repo);
  git_revwalk_sorting(walker, GIT_SORT_NONE);
  git_revwalk_push_head(walker);
  git_oid oid;

  while (!git_revwalk_next(&oid, walker)) {
    git_commit *commit = nullptr;
    git_commit_lookup(&commit, repo, &oid);

    std::ostringstream ss;
    ss << git_oid_tostr_s(&oid) << " " << git_commit_summary(commit)
       << std::endl;

    req->response.push_back(ss.str());
    git_commit_free(commit);
  }

cleanup:
  git_revwalk_free(walker);
  git_repository_free(repo);

  if (error >= 0) {
    req->response.push_back("done");
  }
  return error;
}
