licenses(["notice"])  # Apache 2

load(
    "@envoy//bazel:envoy_build_system.bzl",
    "envoy_cc_library",
    "envoy_package",
)

envoy_package()

envoy_cc_library(
    name = "qatzip_compressor_lib",
    srcs = ["qatzip_compressor_impl.cc"],
    hdrs = ["qatzip_compressor_impl.h"],
	repository = "@envoy",
    deps = [
		"@qatzip//:qatzip",
        "@envoy//include/envoy/compressor:compressor_interface",
    ],
)
