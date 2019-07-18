#!/usr/bin/env bash
#
# Copyright (c) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

if [ -f /etc/os-release ]; then
	source /etc/os-release
else
	source /usr/lib/os-release
fi

readonly BAZEL_BIN="$(realpath "${PWD}"/bazel.sh)"
readonly SCRIPTS_DIR="$(realpath "$(dirname "$0")")"
readonly VERSIONS_FILE="${SCRIPTS_DIR}/../versions.yaml"
readonly OPENSSL_DIR="${SCRIPTS_DIR}/../openssl"
readonly QAT_ENGINE_DIR="${SCRIPTS_DIR}/../QAT_Engine"
readonly ENVOY_DIR="${SCRIPTS_DIR}/../envoy"
readonly QAT_LIB_DIR="${SCRIPTS_DIR}/../QAT_Lib"

#shellcheck source=lib.sh
source "${SCRIPTS_DIR}/lib.sh"

versions_yaml() {
	shyaml get-value "$1" < "${VERSIONS_FILE}"
}

install_bazel() {
	info "Download and install bazel"
	local bazel_url
	local bazel_version
	bazel_url="$(versions_yaml "tools.bazel.url")"
	bazel_version="$(versions_yaml "tools.bazel.version")"
	bazel_sha256="$(versions_yaml "tools.bazel.sha256")"
	curl -L "${bazel_url}/releases/download/${bazel_version}/bazel-${bazel_version}-installer-linux-x86_64.sh" -o "${BAZEL_BIN}"
	bazel_sha256_sum="$(sha256sum "${BAZEL_BIN}" | cut -d' ' -f1)"
	# check sha256
	if [ "${bazel_sha256_sum}" != "${bazel_sha256}" ]; then
		die "Mismatch bazel sha256. Expecting ${bazel_sha256}, got ${bazel_sha256_sum}"
	fi

	chmod +x "${BAZEL_BIN}"
}

setup() {
	case $ID in
		clear-linux*)
			export HOME=/root
			info "Clear Linux OS detected"
			rm -rf /run/lock/clrtrust.lock
			clrtrust generate
			swupd update
			swupd bundle-add os-core-dev
			;;
		debian|ubuntu)
			info "Debian/Ubuntu OS detected"
			# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199
			mkdir -p /usr/share/man/man1
			apt-get -o Acquire::Check-Valid-Until=false update
			apt-get -y install git libtool \
					cmake clang-format-7 automake ninja-build curl \
					git build-essential wget libudev-dev libssl-dev \
					openssl pkg-config autoconf autogen libtool \
					libssl-dev pkg-config zip g++ zlib1g-dev unzip \
					python python-pip curl gnupg2
			;;
	esac

	pip install shyaml

	install_bazel
	"${BAZEL_BIN}" --user
}

build_install_qat_library() {
	local qat_url
	local qat_version

	qat_url="$(versions_yaml "libraries.qat.url")"
	qat_version="$(versions_yaml "libraries.qat.version")"
	qat_sha256="$(versions_yaml "libraries.qat.sha256")"

	mkdir -p "${QAT_LIB_DIR}"
	pushd "${QAT_LIB_DIR}"

	qat_tar="qat.tgz"
	curl -L "${qat_url}/qat${qat_version}.tar.gz" -o "${qat_tar}"
	qat_sha256_sum="$(sha256sum "${qat_tar}" | cut -d' ' -f1)"
	# check sha256
	if [ "${qat_sha256_sum}" != "${qat_sha256}" ]; then
		die "Mismatch QAT sha256. Expecting ${qat_sha256}, got ${qat_sha256_sum}"
	fi
	tar -xf "${qat_tar}"

	sed -i -e 's/cmn_ko$//' quickassist/Makefile
	export ICP_ROOT="${QAT_LIB_DIR}" ICP_BUILD_OUTPUT="${QAT_LIB_DIR}/build" \
		   ICP_ENV_DIR="${QAT_LIB_DIR}/quickassist/build_system/build_files/env_files" \
		   ICP_BUILDSYSTEM_PATH="${QAT_LIB_DIR}/quickassist/build_system" KERNEL_SOURCE_ROOT=/tmp

	case $ID in
		clear-linux*)
			./configure
			;;
		debian|ubuntu)
			./configure --disable-qat-lkcf
			;;
	esac

	make -j "$(jobs)" -f quickassist/Makefile user
	make -j "$(jobs)" adf-ctl-all

	install -m 755 build/libqat_s.so /usr/lib/
	install -m 755 build/libusdm_drv_s.so /usr/lib/
	install -m 755 build/adf_ctl /usr/bin/
	install -d /etc/ld.so.conf.d
	echo /usr/lib/ > /etc/ld.so.conf.d/qat.conf
	ldconfig

	popd
}

configure_install_openssl() {
	pushd "${OPENSSL_DIR}"

	./config

	case $ID in
		debian|ubuntu)
			install -d /usr/local/lib/site_perl
			install -m 644 configdata.pm /usr/local/lib/site_perl/
			;;
	esac

	popd
}

build_install_qat_engine() {
	pushd "${QAT_ENGINE_DIR}"
	local distro_specific_opts=""

	case $ID in
		clear-linux*)
			export PERL5LIB="${OPENSSL_DIR}"
			distro_specific_opts="--enable-openssl_install_build_arch_path --with-openssl_install_dir=/usr/lib64"
			;;
		debian|ubuntu)
			mkdir -p /usr/lib/engines-1.1
			distro_specific_opts="--with-openssl_install_dir=/usr"
			;;
	esac

	./autogen.sh
	./configure --with-qat_dir="${QAT_LIB_DIR}" \
				--with-openssl_dir="${OPENSSL_DIR}" \
				--enable-upstream_driver \
				--enable-usdm --with-qat_install_dir=/usr/lib \
				${distro_specific_opts}
	make -j "$(jobs)"
	make install

	install -d /usr/local/lib64
	case $ID in
		clear-linux*)
			ln -sf /usr/lib64/libssl.so /usr/local/lib64/
			ln -sf /usr/lib64/libcrypto.so /usr/local/lib64/
			;;

		debian|ubuntu)
			mv /usr/lib/engines-1.1/qat.so /usr/lib/x86_64-linux-gnu/engines-1.1/
			ln -sf /usr/lib/x86_64-linux-gnu/libssl.so /usr/local/lib64/
			ln -sf /usr/lib/x86_64-linux-gnu/libcrypto.so /usr/local/lib64/
			;;
	esac

	ldconfig
	popd
}

build_envoy() {
	pushd "${ENVOY_DIR}"
	~/.bazel/bin/bazel build -j "$(jobs)" -c opt //source/exe:envoy-static
	popd
}

main() {
	if [ "$(id -u)" != "0" ]; then
		die "Run this script as root or with sudo"
	fi

	setup

	info "Build and install QAT library"
	build_install_qat_library

	info "Configure and install openssl"
	configure_install_openssl

	info "Build and install QAT engine"
	build_install_qat_engine

	info "Build Envoy"
	build_envoy
}

main
