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

    git push ci HEAD:refs/for/master,each

Having a variable specifying distributions to build on, can allow selecting
them when pushing:

    git push ci HEAD:refs/for/master,debian,rhel,fedora

Or with selecting the commits to build:

    git push ci HEAD:refs/for/master,each,gentoo,arch

Full tags need not be specified in the reference names, prefixes are
sufficient. Assuming there is no ambiguity, the above can be abbreviated to:

    git push ci HEAD:refs/for/master,e,g,a

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
