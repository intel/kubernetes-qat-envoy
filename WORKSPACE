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
    path = "/usr/lib/x86_64-linux-gnu",
    build_file = "envoy-openssl/openssl_host_shared.BUILD"
)

new_local_repository(
    name = "qat",
    path = "/",
    build_file = "qat_host_shared.BUILD"
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

load("@envoy//bazel:dependency_imports.bzl", "envoy_dependency_imports")

envoy_dependency_imports()

load("@envoy//bazel:repository_locations.bzl", "REPOSITORY_LOCATIONS")

http_archive(
    name = "com_github_google_jwt_verify_patched",
    urls = REPOSITORY_LOCATIONS["com_github_google_jwt_verify"]["urls"],
    sha256 = REPOSITORY_LOCATIONS["com_github_google_jwt_verify"]["sha256"],
    strip_prefix = REPOSITORY_LOCATIONS["com_github_google_jwt_verify"].get("strip_prefix", ""),
    patches=["//:envoy-openssl/jwt_verify-make-compatible-with-openssl.patch"],
    patch_args=["-p1"]
)

# TODO: Consider not using `bind`. See https://github.com/bazelbuild/bazel/issues/1952 for details.
bind(
    name = "jwt_verify_lib",
    actual = "@com_github_google_jwt_verify_patched//:jwt_verify_lib",
)
