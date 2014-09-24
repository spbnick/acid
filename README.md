ACID
====
— Another CI Dispatcher

ACID is a basic toolset for triggering CI builds for commits pushed to a
special Git repository (similar to Gerrit) and for new commits detected in the
origin Git repo (similar to post-update hook). This fulfills basic
requirements for pre- and post-commit CI respectively.

ACID can be configured and invoked to trigger builds (execute shell scripts)
for each, or only the last commit being pushed to the origin or the special
pre-commit repo.

It allows configuring arbitrary variables with a finite set of values (tags),
to be accepted as part of the reference name being pushed to, and then
supplied to the build-triggering scripts.

Both exclusive and inclusive tag set (scalar and array) variables are
supported. Variables are verified to have unique tag sets, so they can be
mixed in the reference names. An exclusive "scope" variable allowing
specifying which commits to test - each, or last, must be defined in the
configuration.

Triggering a pre-commit build for every commit designated for the master
branch might look like this:

    git push ci HEAD:master,each

Having a variable specifying distributions to build on, can allow selecting
them when pushing:

    git push ci HEAD:master,debian,rhel,fedora

Or with selecting the commits to build:

    git push ci HEAD:master,each,gentoo,arch

Full tags need not be specified in the reference names, prefixes are
sufficient. Assuming there is no ambiguity, the above can be abbreviated to:

    git push ci HEAD:master,e,g,a

Each branch configuration must specify three tag set "masks": one selecting
tags available for specifying in the pre-commit push reference names, another
specifying defaults for any variable tags missing from there, and the third
one selecting tags to use for post-commit builds. All these masks can use
extended glob patterns to simplify matching.

Implementation
--------------

ACID is in a proof-of-concept stage and is implemented in Bash at the moment
(don't hit me too hard). It relies on having a frequently updated (e.g. by
cron) clone of the origin repo (mirror). This mirror's git configuration is
where ACID stores its settings.

Post-commit triggering is implemented by `acid-update` comparing the mirror's
tracking and local branches and starting builds for any new commits.

Pre-commit push-triggering is implemented by setting up an ssh server with
user accounts assigned special `acid-shell` shell, which emulates `git-shell`,
and allows pushes with the help of `acid-receive-pack` - a `git-receive-pack`
wrapper. The wrapper clones the mirror of the origin repo to a temporary
directory, sets up special pre- and post-receive hooks for it and hands over
the protocol conversation to `git-receive-pack` pointed to this temporary
clone.

The pre-receive hook, handled by `acid-pre-receive`, prevents invalid
reference updates from being pushed. The post-receive hook, handled by
`acid-post-receive`, parses pushed reference names, extracting the target
branch and optional CI parameters, and pushes each new commit to a separate
reference in the mirror repo, from where they can be retrieved by the
triggered builds.

After `git-receive-pack` completes, `acid-receive-pack` regains control and
removes the temporary clone of the mirror repo.

Options
-------

ACID retrieves its configuration from the mirror's git configuration. The
following is the reference to the supported options.

acid
> General ACID configuration.

acid.script-pfx
> Prefix to be added to commit-handling script before execution. Can be used
> to add variable and function definitions common to both pre- and post-commit
> trigger scripts. Optional.

acid.script-sfx
> Suffix to be added to commit-handling script before execution. Can be used
> to add cleanup common to both pre- and post-commit trigger scripts.
> Optional.

acid-pre
> Pre-review commit handling configuration.

acid-pre.script
> Script to execute upon detection of a pre-review commit (pre-commit
> trigger), i.e. on push to the mirror. Will have `acid.script-pfx` and
> `acid.script-sfx` added to the front and the back correspondingly, before
> execution. Optional.

acid-post
> Post-review commit handling configuration.

acid-post.script
> Script to execute upon detection of a post-review commit (pre-commit
> trigger), i.e. upon noticing new origin commits when refreshing the mirror.
> Will have `acid.script-pfx` and `acid.script-sfx` added to the front and the
> back correspondingly, before execution. Optional.

acid-var.\*
> ACID variable definitions. Name of the section determines variable name.

acid-var.\*.type
> Variable type, either one of these:
>
> - inclusive - array value, one tag minimum, all tags maximum;
> - exclusive - scalar value, always one tag;
> - scope - scalar value specifying which commits to run triggers for (each,
>           or only the last), always one of two tags.
>
> Required.

acid-var.\*.desc
> Variable description, used in online help. Optional.

acid-var.\*.tag
> Variable value tag. First word is the tag name, remainder is the optional
> tag description used in online help. Option is repeated for each tag.

branch.\*.acid-enabled
> Boolean option enabling ACID handling of the branch. Optional.

branch.\*.acid-pre-selected
> A space-separated set of glob patterns matching tags available for
> selection via target reference names, when pushing pre-review commits.
> Required, if acid-enabled is true.

branch.\*.acid-pre-defaults
> A space-separated set of glob patterns matching tags to be used as
> defaults when a variable doesn't have any of its tags specified in the
> target reference name, when pushing pre-review commits. Should not match
> ambiguous tag sets. Required, if acid-enabled is true.

branch.\*.acid-post-selected
> A space-separated set of glob patterns matching tags to use as variable
> values for handling post-review commits. Should not match ambiguous tag
> sets. Required, if acid-enabled is true.

Scripts
-------

Both pre- and post-review commit-handling scripts receive the same
environment. They are executed in the mirror repo's `GIT_DIR`, have `branch`
variable set to the name of the target branch and `commit` variable set to the
commit hash.

ACID variable values are stored in similarly-named indexed array variables,
but having `var_` prefix attached. I.e. selected ACID variable tags become
array elements.

Example
-------

The following Git config snippet was used by the sssd project to trigger
Jenkins CI jobs.

    [branch "master"]
        remote = origin
        merge = refs/heads/master
        acid-enabled = true
        acid-pre-selected = *
        acid-pre-defaults = debian* rhel* fedora* last essential
        acid-post-selected = debian* rhel* fedora* each rigorous

    [acid]
        script-pfx = " \
            set -e -u -o pipefail; \
            function queue() { \
                declare -r localpart=\"$1\"; \
                declare desc; \
                declare url=\"http://localhost:8080/job/ci/buildWithParameters?\"; \
                desc=`git log -n1 --oneline \"$commit\"`; \
                echo \"Queueing for $var_tests / ${var_distro[*]}:\" >&2; \
                echo \"         $desc\" >&2; \
                echo >&2; \
                url+=\"delay=0sec&revision=$commit&tests=$var_tests&\"; \
                url+=\"labels=${var_distro[*]}&email=$localpart@redhat.com\"; \
                wget --quiet -O/dev/null -- \"$url\" >&2; \
            }; \
        "

    [acid-pre]
        script = "queue \"$USER\""
    [acid-post]
        script = "queue sssd-ci"

    [acid-var "tests"]
        desc = test set to execute
        type = exclusive
        tag = essential         8m, build, test with Valgrind
        tag = moderate          15m, essential, distcheck, mock
        tag = rigorous          25m, moderate, clang analyzer, code coverage

    [acid-var "distro"]
        desc = distribution to run on
        type = inclusive
        tag = debian_testing    Debian Testing
        tag = fedora20          Fedora 20
        tag = fedora_rawhide    Fedora Rawhide
        tag = rhel6             RHEL6
        tag = rhel7             RHEL7

    [acid-var "scope"]
        desc = which commits to test
        type = scope
        each = each     each commit
        last = last     only the last commit
