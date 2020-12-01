licenses(["notice"])  # Apache 2

load(
    "@envoy//bazel:envoy_build_system.bzl",
    "envoy_cc_binary",
    "envoy_package",
)

envoy_package()

envoy_cc_binary(
    name = "envoy",
    repository = "@envoy",
    deps = [
        "//qatzip/compressor:config",
        "@envoy//source/exe:envoy_main_entry_lib",
    ],
)
