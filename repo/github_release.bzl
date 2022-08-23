load("@bazel_tools//tools/build_defs/repo:utils.bzl",
     "patch",
     "update_attrs",
     "workspace_and_buildfile")

def _github_release_impl(ctx):
    if ctx.attr.override_path:
        path = ctx.path(ctx.attr.override_path)
        if path.exists:
            print("An override_path for {} was provided, and it exists: {}".format(
                    ctx.attr.name, ctx.attr.override_path))
            print("Using this instead of the remote. Note that this should not be relied " +
                  "upon when committing, as it violates hermeticity. A local repository " +
                  "cannot be accessed by any other machine.")
            ctx.symlink(ctx.attr.override_path, "")
            return
        else:
            print("An override_path for {} was provided, but it does not exist: {}".format(
                    ctx.attr.name, ctx.attr.override_path))
            print("Using remote instead.")
    url_format = "https://github.com/{}/{}/archive/{}.{}"
    prefix_format = "{}-{}"
    if not ctx.attr.owner:
        fail("An owner must be provided")
    if not ctx.attr.repository:
        fail("A repository must be provided")
    if not ctx.attr.version:
        fail("A version must be provided, e.g. '1.0.0'")
    extension = ctx.attr.type if ctx.attr.type else "tar.gz"
    
    url = url_format.format(ctx.attr.owner,
                            ctx.attr.repository,
                            ctx.attr.version,
                            extension)
    strip_prefix = prefix_format.format(ctx.attr.repository,
                                 ctx.attr.version)
    auth = {}
    if ctx.attr.token:
        auth[url] = {
            'type': 'pattern',
            'pattern': 'Basic {}'.format(ctx.attr.token)
        }
    print(auth)
    download_info = ctx.download_and_extract(
        [url],
        "",
        ctx.attr.sha256,
        extension,
        strip_prefix,
        canonical_id = ctx.attr.canonical_id,
        auth = auth
    )
    workspace_and_buildfile(ctx)
    patch(ctx)
    return update_attrs(ctx.attr, _github_release_attrs.keys(), {"sha256": download_info.sha256})

_github_release_attrs = {
    "owner": attr.string(
        doc = 
            "The owner of the github project. Used to generate the url to the archive " +
            "in the form `https://github.com/{owner}/{repository}/archive/{version}.{ext}`."
    ),
    "repository": attr.string(
        doc = 
            "The name of the repository. Used to generate the url to the archive " +
            "in the form `https://github.com/{owner}/{repository}/archive/{version}.{ext}`, " +
            "and to strip the prefix in the form `{repository}_{version}`"
    ),
    "version": attr.string(
        doc = 
            "The tagged version of the repository. Used to generate the url to the archive " +
            "in the form `https://github.com/{owner}/{repository}/archive/{version}.{ext}`, " +
            "and to strip the prefix in the form `{repository}_{version}`"
    ),
    "token": attr.string(
        doc = 
            "The github token required to access the repository, if it is not publicly " + 
            "accessible. If your account can access this repository, but you do not have " +
            "a suitable key, go to https://github.com/settings/tokens and generate a new " + 
            "token. Make sure you only provide it with repo scope for security reasons."
    ),
    "type": attr.string(
        doc = 
            "The file extension to download of the github project. Used to generate the " + 
            "url to the archive in the form " + 
            "`https://github.com/{owner}/{repository}/archive/{version}.{ext}`, " +
            "where we substitute `ext` for `type` for consistency with http_archive parameters. " +
            "As with http_archive, the following are supported, but ensure github provides whichever " +
            "extension you're choosing: `\"zip\"`, `\"jar\"`, `\"war\"`, `\"tar\"`, `\"tar.gz\"`, " +
            "`\"tgz\"`, `\"tar.xz\"`, `\"tar.bz2\"`."
    ),
    "sha256": attr.string(
        doc =
            "The expected SHA-256 of the file downloaded. This must match the SHA-256 " +
            "of the file downloaded. _It is a security risk to omit the SHA-256 as remote " +
            "files can change._ At best omitting this field will make your build non-hermetic. " +
            "It is optional to make development easier but should be set before shipping.",
    ),
    "override_path": attr.string(
        doc = 
            "If provided, and if override_path exists, then it will be used as a local repository " +
            "instead of fetching the remote. This is useful in development environments, where you " +
            "want to try modifications to a remote repository without committing and tagging them.",
    ),
    "canonical_id": attr.string(
        doc =
            "A canonical id of the archive downloaded. If specified and non-empty, bazel " +
            "will not take the archive from cache, unless it was added to the cache by a " +
            "request with the same canonical id."
    ),
    "patches": attr.label_list(
        default = [],
        doc =
            "A list of files that are to be applied as patches after " +
            "extracting the archive. By default, it uses the Bazel-native patch implementation " +
            "which doesn't support fuzz match and binary patch, but Bazel will fall back to use " +
            "patch command line tool if `patch_tool` attribute is specified or there are " +
            "arguments other than `-p` in `patch_args` attribute.",
    ),
    "patch_tool": attr.string(
        default = "",
        doc = "The patch(1) utility to use. If this is specified, Bazel will use the specifed " +
              "patch tool instead of the Bazel-native patch implementation.",
    ),
    "patch_args": attr.string_list(
        default = ["-p0"],
        doc =
            "The arguments given to the patch tool. Defaults to -p0, " +
            "however -p1 will usually be needed for patches generated by " +
            "git. If multiple -p arguments are specified, the last one will take effect." +
            "If arguments other than -p are specified, Bazel will fall back to use patch " +
            "command line tool instead of the Bazel-native patch implementation. When falling " +
            "back to patch command line tool and patch_tool attribute is not specified, " +
            "`patch` will be used.",
    ),
    "patch_cmds": attr.string_list(
        default = [],
        doc = "Sequence of Bash commands to be applied on Linux/Macos after patches are applied.",
    ),
    "patch_cmds_win": attr.string_list(
        default = [],
        doc = "Sequence of Powershell commands to be applied on Windows after patches are " +
              "applied. If this attribute is not set, patch_cmds will be executed on Windows, " +
              "which requires Bash binary to exist.",
    ),
    "build_file": attr.label(
        allow_single_file = True,
        doc =
            "The file to use as the BUILD file for this repository." +
            "This attribute is an absolute label (use '@//' for the main " +
            "repo). The file does not need to be named BUILD, but can " +
            "be (something like BUILD.new-repo-name may work well for " +
            "distinguishing it from the repository's actual BUILD files. " +
            "Either build_file or build_file_content can be specified, but " +
            "not both.",
    ),
    "build_file_content": attr.string(
        doc =
            "The content for the BUILD file for this repository. " +
            "Either build_file or build_file_content can be specified, but " +
            "not both.",
    ),
    "workspace_file": attr.label(
        doc =
            "The file to use as the `WORKSPACE` file for this repository. " +
            "Either `workspace_file` or `workspace_file_content` can be " +
            "specified, or neither, but not both.",
    ),
    "workspace_file_content": attr.string(
        doc =
            "The content for the WORKSPACE file for this repository. " +
            "Either `workspace_file` or `workspace_file_content` can be " +
            "specified, or neither, but not both.",
    ),
}

github_release = repository_rule(
    implementation = _github_release_impl,
    attrs = _github_release_attrs,
    doc = """
Downloads a bazel repository from github, using the project, repository, version,
and an optional login token to form an URL to a .tar.gz archive. This is downloaded
as a compressed archive file, decompressed, and its targets are made available for
binding.

Why?
-----

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

How to use with public github repositories
------------------------------------------

Say you wish to pull version 1.0.3 of this repository, which resides at
`https://github.com/jake-arkinstall/bazel_utils/archive/1.0.3.tar.gz`

You can do so by having this in your workspace:
```
github_release(
    name = "some_name",
    owner = "jake-arkinstall",
    repository = "bazel_utils",
    version = "1.0.3",
    sha256 = "8616f3beb416e3e0399b3c14eb9dcdf77239f12fdaeb9729449850329b99e989"
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

Private Repositories:
---------------------

If this were a private repository, and your account has access to it, you can
generate a token at https://github.com/settings/tokens/new and pass it to a 
`token` parameter:

```
github_release(
    name = "some_name",
    owner = "jake-arkinstall",
    repository = "bazel_utils",
    version = "1.0.3",
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
    version = "1.0.3",
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
""")
