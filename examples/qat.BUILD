licenses(["notice"])  # Apache 2

# This is an example on how to package QAT libraries with bazel
#
# To try, modify the WORKSPACE in the following way:
#
# http_archive(
#     name = "qat",
#     build_file = "@//:qat.BUILD",
#     patch_cmds = [
#         "sed 's/-fno-strict-overflow//' quickassist/build_system/build_files/defenses.mk",
#         "sed -i 's/-fno-strict-overflow//' quickassist/build_system/build_files/defenses.mk",
#         "sed -i -e 's/cmn_ko$//' -e 's/lac_kernel$//' quickassist/Makefile",
#     ],
#     urls = ["https://01.org/sites/default/files/downloads/qat1.7.l.4.10.0-00014.tar.gz"],
#     sha256 = "bf777c7194245cb5ad07804847b92b8d149fee603edfbd572addb62c61100df6",
# )

load("@rules_foreign_cc//tools/build_defs:configure.bzl", "configure_make")

filegroup(
    name = "all",
    srcs = glob(["**"]),
)

configure_make(
    name = "qat",
    lib_source = "@qat//:all",
    visibility = ["//visibility:public"],
    configure_in_place = True,
    configure_env_vars = {
	"KERNEL_SOURCE_ROOT": "/tmp",
    },
    make_commands = [
        "[[ \
           ! -f $BUILD_TMPDIR/build/libqat.a || \
           ! -f $BUILD_TMPDIR/build/libusdm_drv.a  || \
           ! -f $BUILD_TMPDIR/build/libosal.a || \
           ! -f $BUILD_TMPDIR/build/libadf.a \
         ]] && make quickassist-all",
        "mkdir -p $BUILD_TMPDIR/$INSTALL_PREFIX/lib",
        "cp -v $BUILD_TMPDIR/build/*.a $BUILD_TMPDIR/$INSTALL_PREFIX/lib/",
        "mkdir -p $BUILD_TMPDIR/$INSTALL_PREFIX/include",
        "cp -v $BUILD_TMPDIR/quickassist/include/*.h $BUILD_TMPDIR/$INSTALL_PREFIX/include/",
        "cp -v $BUILD_TMPDIR/quickassist/include/dc/*.h $BUILD_TMPDIR/$INSTALL_PREFIX/include/",
        "cp -v $BUILD_TMPDIR/quickassist/lookaside/access_layer/include/*.h $BUILD_TMPDIR/$INSTALL_PREFIX/include/",
        "cp -v $BUILD_TMPDIR/quickassist/utilities/libusdm_drv/*.h $BUILD_TMPDIR/$INSTALL_PREFIX/include/",
],
    static_libraries = [
        "libqat.a",
        "libusdm_drv.a",
        "libosal.a",
        "libadf.a",
    ],
    out_include_dir = "include",
    linkopts = ["-ludev"],
)
