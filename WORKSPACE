workspace(name = "kubernetes_qat_envoy")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "qatzip",
    build_file = "@//:qatzip.BUILD",
    sha256 = "461c155fa9153c217c5dc7d7cf44cb31106ab6e5754a7ee5fbd8121b4c6cdd4b",
    strip_prefix = "QATzip-1.0.1",
    urls = ["https://github.com/intel/QATzip/archive/v1.0.1.tar.gz"],
)

new_local_repository(
    name = "openssl",
    build_file = "envoy-openssl/openssl_host_shared.BUILD",
    path = "/usr/lib64",
)

new_local_repository(
    name = "qat",
    build_file = "qat_host_shared.BUILD",
    path = "/",
)

local_repository(
    name = "envoy_openssl",
    path = "envoy-openssl",
)

local_repository(
    name = "envoy_build_config",
    path = "envoy-openssl/envoy_build_config",
)

local_repository(
    name = "envoy",
    path = "envoy",
    repo_mapping = {
        "@boringssl": "@openssl",
    },
)

load("@envoy//bazel:api_binding.bzl", "envoy_api_binding")

envoy_api_binding()

load("@envoy//bazel:api_repositories.bzl", "envoy_api_dependencies")

envoy_api_dependencies()

load("@envoy//bazel:repositories.bzl", "envoy_dependencies")

envoy_dependencies()

load("@envoy//bazel:repositories_extra.bzl", "envoy_dependencies_extra")

envoy_dependencies_extra()

load("@envoy//bazel:dependency_imports.bzl", "envoy_dependency_imports")

envoy_dependency_imports()

# TODO: update to the latest release which doesn't build currently.
http_archive(
    name = "com_github_google_jwt_verify_patched",
    patch_args = ["-p1"],
    patches = ["@envoy_openssl//:jwt_verify-make-compatible-with-openssl.patch"],
    sha256 = "118f955620509f1634cbd918c63234d2048dce56b1815caf348d78e3c3dc899c",
    strip_prefix = "jwt_verify_lib-44291b2ee4c19631e5a0a0bf4f965436a9364ca7",
    urls = ["https://github.com/google/jwt_verify_lib/archive/44291b2ee4c19631e5a0a0bf4f965436a9364ca7.tar.gz"],
)

# TODO: Consider not using `bind`. See https://github.com/bazelbuild/bazel/issues/1952 for details.
bind(
    name = "jwt_verify_lib",
    actual = "@com_github_google_jwt_verify_patched//:jwt_verify_lib",
)
