licenses(["notice"])  # Apache 2

cc_library(
    name = "host-qat",
    srcs = [
        "usr/lib/libqat_s.so",
        "usr/lib/libusdm_drv_s.so",
    ],
	hdrs = glob([
		"QAT_Lib/quickassist/**/*.h",
	]),
	includes = [
		"QAT_Lib/quickassist/include",
		"QAT_Lib/quickassist/include/dc",
		"QAT_Lib/quickassist/lookaside/access_layer/include",
		"QAT_Lib/quickassist/utilities/libusdm_drv",
	],
    linkstatic = False,
    visibility = ["//visibility:public"],
)

alias(
    name = "qat",
    actual = "host-qat",
    visibility = ["//visibility:public"],
)
