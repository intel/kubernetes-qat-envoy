#include "qatzip_filter.h"

namespace Envoy {
namespace Extensions {
namespace HttpFilters {
namespace Qatzip {

namespace {

// Default qatzip stream buffer size.
const unsigned int DefaultStreamBufferSize = 128 * 1024;

} // namespace

QatzipFilterConfig::QatzipFilterConfig(const qatzip::Qatzip& qatzip,
                                       const std::string& stats_prefix, Stats::Scope& scope,
                                       Runtime::Loader& runtime, ThreadLocal::SlotAllocator& tls)
    : CompressorFilterConfig(qatzip.compressor(), stats_prefix + "qatzip.", scope, runtime, "gzip"),
      tls_slot_(tls.allocateSlot()) {
  QzSessionParams_T params;

  int status = qzGetDefaults(&params);
  RELEASE_ASSERT(status == QZ_OK, "failed to initialize hardware");
  params.comp_lvl = compressionLevelUint(qatzip.compression_level().value());
  params.hw_buff_sz = hardwareBufferSizeEnum(qatzip.hardware_buffer_size());
  params.strm_buff_sz = streamBufferSizeUint(qatzip.stream_buffer_size().value());
  params.input_sz_thrshold = inputSizeThresholdUint(qatzip.input_size_threshold().value());
  params.data_fmt = QZ_DEFLATE_RAW;

  tls_slot_->set([params](Event::Dispatcher&) -> ThreadLocal::ThreadLocalObjectSharedPtr {
    return std::make_shared<QatzipThreadLocal>(params);
  });
}

unsigned int
QatzipFilterConfig::hardwareBufferSizeEnum(qatzip::Qatzip_HardwareBufferSize hardware_buffer_size) {
  switch (hardware_buffer_size) {
  case qatzip::Qatzip_HardwareBufferSize::Qatzip_HardwareBufferSize_SZ_4K:
    return 4 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::Qatzip_HardwareBufferSize_SZ_8K:
    return 8 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::Qatzip_HardwareBufferSize_SZ_32K:
    return 32 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::Qatzip_HardwareBufferSize_SZ_64K:
    return 64 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::Qatzip_HardwareBufferSize_SZ_128K:
    return 128 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::Qatzip_HardwareBufferSize_SZ_512K:
    return 512 * 1024;
  default:
    return 64 * 1024;
  }
}

unsigned int QatzipFilterConfig::compressionLevelUint(Protobuf::uint32 compression_level) {
  return compression_level > 0 ? compression_level : QZ_COMP_LEVEL_DEFAULT;
}

unsigned int QatzipFilterConfig::inputSizeThresholdUint(Protobuf::uint32 input_size_threshold) {
  return input_size_threshold > 0 ? input_size_threshold : QZ_COMP_THRESHOLD_DEFAULT;
}

unsigned int QatzipFilterConfig::streamBufferSizeUint(Protobuf::uint32 stream_buffer_size) {
  return stream_buffer_size > 0 ? stream_buffer_size : DefaultStreamBufferSize;
}

std::unique_ptr<Compressor::Compressor> QatzipFilterConfig::makeCompressor() {
  return std::make_unique<Compressor::QatzipCompressorImpl>(
      tls_slot_->getTyped<QatzipThreadLocal>().getSession());
}

QatzipFilterConfig::QatzipThreadLocal::QatzipThreadLocal(QzSessionParams_T params)
    : params_(params), session_{}, initialized_(false) {}

QatzipFilterConfig::QatzipThreadLocal::~QatzipThreadLocal() {
  if (initialized_) {
    qzTeardownSession(&session_);
    qzClose(&session_);
  }
}

QzSession_T* QatzipFilterConfig::QatzipThreadLocal::getSession() {
  // The session must be initialized only once in every worker thread.
  if (!initialized_) {

    int status = qzInit(&session_, params_.sw_backup);
    RELEASE_ASSERT(status == QZ_OK || status == QZ_DUPLICATE, "failed to initialize hardware");
    status = qzSetupSession(&session_, &params_);
    RELEASE_ASSERT(status == QZ_OK || status == QZ_DUPLICATE, "failed to setup session");
    initialized_ = true;
  }

  return &session_;
}

} // namespace Qatzip
} // namespace HttpFilters
} // namespace Extensions
} // namespace Envoy
