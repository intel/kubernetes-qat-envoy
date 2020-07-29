licenses(["notice"])  # Apache 2

load(
    "@envoy//bazel:envoy_build_system.bzl",
    "envoy_cc_binary",
    "envoy_cc_library",
    "envoy_package",
)

envoy_package()

load("@envoy_api//bazel:api_build_system.bzl", "api_proto_package")

envoy_cc_binary(
    name = "envoy",
    repository = "@envoy",
    deps = [
        ":qatzip_config",
        "@envoy//source/exe:envoy_main_entry_lib",
    ],
)

api_proto_package(
    deps = [
        "@envoy_api//envoy/extensions/filters/http/compressor/v3:pkg",
    ],
)

envoy_cc_library(
    name = "qatzip_filter_lib",
    srcs = ["qatzip_filter.cc"],
    hdrs = ["qatzip_filter.h"],
    repository = "@envoy",
    deps = [
        ":pkg_cc_proto",
        "//envoy_qatzip/compressor:qatzip_compressor_lib",
        "@envoy//include/envoy/thread_local:thread_local_interface",
        "@envoy//source/extensions/filters/http:well_known_names",
        "@envoy//source/extensions/filters/http/common:factory_base_lib",
        "@envoy//source/extensions/filters/http/common/compressor:compressor_lib",
        "@qatzip",
    ],
)

envoy_cc_library(
    name = "qatzip_config",
    srcs = [
        "config.cc",
        "config.h",
    ],
    repository = "@envoy",
    deps = [
        ":qatzip_filter_lib",
        "@envoy//include/envoy/network:filter_interface",
        "@envoy//include/envoy/registry",
        "@envoy//include/envoy/server:filter_config_interface",
    ],
)
