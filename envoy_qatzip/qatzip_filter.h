#pragma once

#include "envoy/thread_local/thread_local.h"

#include "extensions/filters/http/common/compressor/compressor.h"

#include "envoy_qatzip/compressor/qatzip_compressor_impl.h"
#include "envoy_qatzip/qatzip.pb.h"

namespace Envoy {
namespace Extensions {
namespace HttpFilters {
namespace Qatzip {

/**
 * Configuration for the qatzip filter.
 */
class QatzipFilterConfig : public Common::Compressors::CompressorFilterConfig {
public:
  QatzipFilterConfig(const qatzip::Qatzip& qatzip, const std::string& stats_prefix,
                     Stats::Scope& scope, Runtime::Loader& runtime,
                     ThreadLocal::SlotAllocator& tls);

  std::unique_ptr<Compressor::Compressor> makeCompressor() override;

private:
  static unsigned int compressionLevelUint(Protobuf::uint32 compression_level);
  static unsigned int
  hardwareBufferSizeEnum(qatzip::Qatzip_HardwareBufferSize hardware_buffer_size);
  static unsigned int inputSizeThresholdUint(Protobuf::uint32 input_size_threshold);
  static unsigned int streamBufferSizeUint(Protobuf::uint32 stream_buffer_size);

  struct QatzipThreadLocal : public ThreadLocal::ThreadLocalObject {
    QatzipThreadLocal(QzSessionParams_T params);
    virtual ~QatzipThreadLocal();
    QzSession_T* getSession();

    QzSessionParams_T params_;
    QzSession_T session_;
    bool initialized_;
  };

  ThreadLocal::SlotPtr tls_slot_;
};

} // namespace Qatzip
} // namespace HttpFilters
} // namespace Extensions
} // namespace Envoy
