#include "qatzip_filter.h"

namespace Envoy {
namespace Extensions {
namespace HttpFilters {
namespace Qatzip {

namespace {

// Default qatzip stream buffer size.
const unsigned int DefaultStreamBufferSize = 128 * 1024;

} // namespace

QatzipFilterConfig::QatzipFilterConfig(
    const qatzip::Qatzip& qatzip, const std::string& stats_prefix,
    Stats::Scope& scope, Runtime::Loader& runtime)
    : CompressorFilterConfig(
          qatzip.compressor(), stats_prefix + "qatzip.", scope, runtime, "gzip"),
      compression_level_(compressionLevelUint(qatzip.compression_level().value())),
      hardware_buffer_size_(hardwareBufferSizeEnum(qatzip.hardware_buffer_size())),
      input_size_threshold_(inputSizeThresholdUint(qatzip.input_size_threshold().value())),
      stream_buffer_size_(streamBufferSizeUint(qatzip.stream_buffer_size().value())) {}

unsigned int QatzipFilterConfig::hardwareBufferSizeEnum(
    qatzip::Qatzip_HardwareBufferSize hardware_buffer_size) {
  switch (hardware_buffer_size) {
  case qatzip::Qatzip_HardwareBufferSize::
      Qatzip_HardwareBufferSize_SZ_4K:
    return 4 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::
      Qatzip_HardwareBufferSize_SZ_8K:
    return 8 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::
      Qatzip_HardwareBufferSize_SZ_32K:
    return 32 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::
      Qatzip_HardwareBufferSize_SZ_64K:
    return 64 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::
      Qatzip_HardwareBufferSize_SZ_128K:
    return 128 * 1024;
  case qatzip::Qatzip_HardwareBufferSize::
      Qatzip_HardwareBufferSize_SZ_512K:
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
  auto compressor = std::make_unique<Compressor::QatzipCompressorImpl>();
  compressor->init(compressionLevel(), hardwareBufferSize(), streamBufferSize(),
                   inputSizeThreshold());
  return compressor;
}

} // namespace Qatzip
} // namespace HttpFilters
} // namespace Extensions
} // namespace Envoy
