# Parallel agent workflows

Parallel read-only analysis is usually safe. Parallel writers are safe only when file ownership is explicit and non-overlapping.

Recommended shape:

`recon → design → contract freeze → ownership audit → writers → tests → adversarial review`

Before launching a build-heavy workflow:

1. Check available memory and commit headroom.
2. Keep concurrent C++ builds bounded; separate build directories do not isolate a shared source tree.
3. Give every writer an owned-file list and a forbidden-file list.
4. Have one dispatcher run the definitive test suite after writers finish.
5. Record whether a reported test result was produced while other writers were active.

Treat model-generated patches as drafts. Require a diff review, relevant tests, and a size/scope sanity check before accepting automated repairs. Do not pass secrets, credentials, private transcripts, or proprietary source to an unapproved remote model.

In multi-worktree repositories, avoid shared stash state. Prefer explicit branches or temporary copies when a clean comparison is needed.
