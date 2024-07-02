load("@rules_tf//tf/toolchains/terraform:toolchain.bzl", "terraform_download")
load("@rules_tf//tf:toolchains.bzl", "tf_toolchains")

def detect_host_platform(ctx):
    arch = ctx.os.arch
    if arch == "aarch64":
        arch = "arm64"
    elif arch == "x86_64":
        arch = "amd64"

    return ctx.os.name, arch

def _repo_name(*, module, tool, index, suffix = ""):
    # Keep the version out of the repository name if possible to prevent unnecessary rebuilds when
    # it changes.
    return "{name}_{version}_download_{tool}_{index}{suffix}".format(
        # "main_" is not a valid module name and thus can't collide.
        name = module.name or "main_",
        version = module.version,
        tool = tool,
        index = index,
        suffix = suffix,
    )

def _tf_repositories(ctx):
    host_detected_os, host_detected_arch = detect_host_platform(ctx)
    terraform_toolchains = []

    for module in ctx.modules:
        for index, version_tag in enumerate(module.tags.download):
            tf_repo_name = _repo_name(
                module=module,
                tool = "tf",
                index = index,
                suffix = "_{}_{}".format(host_detected_os, host_detected_arch),
            )
            terraform_download(
                    name = tf_repo_name,
                    version = version_tag.version,
                    os = host_detected_os,
                    arch = host_detected_arch,
                    mirror = version_tag.mirror,
            )

            terraform_toolchains.append(tf_repo_name)

    tf_toolchains(
        name = "tf_toolchains",
        terraform_repos = terraform_toolchains,
        os = host_detected_os,
        arch = host_detected_arch,
    )

_version_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
    },
)

tf_repositories = module_extension(
    implementation = _tf_repositories,
    tag_classes = {
        "download": _version_tag,
    },
    os_dependent = True,
    arch_dependent = True,
)
