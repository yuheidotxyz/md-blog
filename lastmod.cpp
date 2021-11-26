#include <bits/stdc++.h>
#include <git2.h>
#define check(error) \
    if (error)       \
        return exit(git_error_last()->message);
int exit(std::string err = "")
{
    git_libgit2_shutdown();
    if (err == "")
        return 0;
    std::cerr << err << std::endl;
    return 1;
}
int main(int argc, char *argv[])
{
    if (argc <= 1)
        return 0;
    std::string absolute_path = argv[1];

    git_libgit2_init();

    git_repository *repo = NULL;
    check(git_repository_open_ext(&repo, absolute_path.c_str(), 0, NULL));

    std::string base = git_repository_path(repo), relative_path = absolute_path;
    base.erase(base.end() - 5, base.end()); // 末尾から5文字(".git/")削除
    relative_path.erase(0, base.length());

    git_object *_head_commit = NULL;
    check(git_revparse_single(&_head_commit, repo, "HEAD^{commit}"));
    git_commit *head_commit = (git_commit *)_head_commit;
    git_tree *head_tree = NULL;
    check(git_commit_tree(&head_tree, head_commit));
    git_tree_entry *head_blob = NULL;
    check(git_tree_entry_bypath(&head_blob, head_tree, relative_path.c_str()));

    std::time_t lastmod = std::numeric_limits<std::time_t>::lowest();

    std::queue<git_commit *> que;
    que.push(head_commit);
    while (!que.empty())
    {
        git_commit *commit = que.front();
        que.pop();

        unsigned int par_len = git_commit_parentcount(commit);
        bool pushed_flag = false;
        for (unsigned int i = 0; i < par_len; i++)
        {
            git_commit *par = NULL;
            check(git_commit_parent(&par, commit, i));
            git_tree *par_tree = NULL;
            check(git_commit_tree(&par_tree, par));
            git_tree_entry *par_blob = NULL;
            if (git_tree_entry_bypath(&par_blob, par_tree, relative_path.c_str()) == 0 &&
                git_oid_equal(git_tree_entry_id(head_blob), git_tree_entry_id(par_blob)))
            {
                pushed_flag = true;
                que.push(par);
            }
        }
        if (!pushed_flag)
        {
            lastmod = std::max(lastmod, git_commit_author(commit)->when.time);
        }
    }
    std::cout << lastmod;
    return exit();
}