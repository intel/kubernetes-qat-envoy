#pragma once

#include "envoy_qatzip/qatzip.pb.h"

#include "envoy_qatzip/compressor/qatzip_compressor_impl.h"

#include "extensions/filters/http/common/compressor/compressor.h"

namespace Envoy {
namespace Extensions {
namespace HttpFilters {
namespace Qatzip {

/**
 * Configuration for the qatzip filter.
 */
class QatzipFilterConfig : public Common::Compressors::CompressorFilterConfig {
public:
  QatzipFilterConfig(const qatzip::Qatzip& qatzip,
                     const std::string& stats_prefix, Stats::Scope& scope,
                     Runtime::Loader& runtime);

  unsigned int compressionLevel() const { return compression_level_; };
  unsigned int hardwareBufferSize() const { return hardware_buffer_size_; };
  unsigned int inputSizeThreshold() const { return input_size_threshold_; };
  unsigned int streamBufferSize() const { return stream_buffer_size_; };

  std::unique_ptr<Compressor::Compressor> makeCompressor() override;

private:
  static unsigned int compressionLevelUint(Protobuf::uint32 compression_level);
  static unsigned int hardwareBufferSizeEnum(
      qatzip::Qatzip_HardwareBufferSize hardware_buffer_size);
  static unsigned int inputSizeThresholdUint(Protobuf::uint32 input_size_threshold);
  static unsigned int streamBufferSizeUint(Protobuf::uint32 stream_buffer_size);

  unsigned int compression_level_;
  unsigned int hardware_buffer_size_;
  unsigned int input_size_threshold_;
  unsigned int stream_buffer_size_;
};

} // namespace Qatzip
} // namespace HttpFilters
} // namespace Extensions
} // namespace Envoy
