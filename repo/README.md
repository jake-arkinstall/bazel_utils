# github_release.bzl

Downloads a bazel repository from github, using the project, repository, version,
and an optional login token to form an URL to a .tar.gz archive. This is downloaded
as a compressed archive file, decompressed, and its targets are made available for
binding.

## Why?

The use case for this method is predominantly when you want to access a
private github repository without the need for a netrc file.

Netrc files can be somewhat cumbersome to work with in Bazel. The netrc parameter
to http_archive must be an absolute path, thus tied to your filesystem, which seems
to go against the core use case of Bazel. If you specify a relative path, it tries
to access it from the wrong place: `/.cache/bazel/path/to/external/other_project/.netrc`.
Of course, if you could access the `.netrc` file in the external project, you wouldn't
need a `.netrc` file in the first place.

A netrc file needn't be necessary, and I will be putting in a pull request to the
bazel project soon, but I need this now.

## Getting started

First you need to be able to access github_release from your workspace.

To do this, you can fetch it with http_archive:

```
load(
    '@bazel_tools//tools/build_defs/repo:http.bzl',
    'http_archive'
)

http_archive(
    name = "com_github_arkinstall_utils",
    url = "https://github.com/jake-arkinstall/bazel_utils/archive/1.0.2.tar.gz",
    strip_prefix = "bazel_utils-1.0.2",
    sha256 = "794f6c0fa0b3ad4029d698d5c00806a20c2a9378d842398b271831e70c1031a6"
)

load('@com_github_arkinstall_utils//repo:github_release.bzl', 'github_release')
```

And then progress to the next section.


## How to use with public github repositories

Say you wish to pull version 1.0.2 of this repository, which resides at
`https://github.com/jake-arkinstall/bazel_utils/archive/1.0.2.tar.gz`

You can do so by having this in your workspace:
```
github_release(
    name = "some_name",
    owner = "jake-arkinstall",
    repository = "bazel_utils",
    version = "1.0.2",
    sha256 = "794f6c0fa0b3ad4029d698d5c00806a20c2a9378d842398b271831e70c1031a6"
)
```

You can now access the repository through `@some_name//`.

github_release supports all of the parameters from http_archive, excluding
`url`, `urls`, `netrc`, `auth_patterns`, and `strip_prefix`, as these are
instead infered from the main arguments. You can (and should) pass a sha256
parameter, which will be output for you if you omit it, as well as patch arguments,
build_file, workspace_file, canonical_id, and so on. Except for the sha256
paramter, the other http_archive parameters have NOT been tested, but they
are implemented in the same way as in http_archive as of bazel version 3.7.0.

## Private Repositories:

If this were a private repository, and your account has access to it, you can
generate a token at https://github.com/settings/tokens/new and pass it to a 
`token` parameter:

```
github_release(
    name = "some_name",
    owner = "jake-arkinstall",
    repository = "bazel_utils",
    version = "1.0.2",
    token = "[your-token]",
)
```

Of course, this is not particularly secure, especially if you are working
in a team. The best solution is to create a bazel file, e.g. `security.bzl`,
and define your token in there:

```
GITHUB_TOKEN = "[your-token]"
```

Then import it in your workspace and use it as follows:

```
load('//:security.bzl', 'GITHUB_TOKEN')
github_release(
    name = "some_name",
    owner = "jake-arkinstall",
    repository = "bazel_utils",
    version = "1.0.2",
    token = GITHUB_TOKEN,
)
```

Make sure you add security.bzl to your gitignore file. If you aren't sure
what that means, here's a tutorial suitable for beginners:
https://www.bmc.com/blogs/gitignore/

Additionally, you may choose to add a security.bzl.default file which contains

```
GITHUB_TOKEN = '[please insert your token here]'
```

and instruct users, through the README.md file or similar, to copy it and
add their own key, in the safe knowledge that their local version will not
be included in any commits.
