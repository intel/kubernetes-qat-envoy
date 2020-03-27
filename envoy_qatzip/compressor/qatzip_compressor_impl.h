#pragma once

#include "envoy/compressor/compressor.h"

#include "qatzip.h"

namespace Envoy {
namespace Compressor {

/**
 * Implementation of compressor's interface.
 */
class QatzipCompressorImpl : public Compressor {
public:
  QatzipCompressorImpl();

  /**
   * Constructor that allows setting the size of compressor's output buffer. It
   * should be called whenever a buffer size different than the 4096 bytes, normally set by the
   * default constructor, is desired.
   * @param chunk_size amount of memory reserved for the compressor output.
   */
  QatzipCompressorImpl(size_t chunk_size);
  virtual ~QatzipCompressorImpl();

  /**
   * Init must be called in order to initialize the compressor. Once compressor is initialized, it
   * cannot be initialized again. Init should run before compressing any data.
   */
  void init(unsigned int compression_level, unsigned int hardware_buffer_size,
            unsigned int stream_buffer_size, unsigned int input_size_threshold);

  // Compressor
  void compress(Buffer::Instance& buffer, State state) override;

private:
  void process(Buffer::Instance& output_buffer, unsigned int last);

  bool initialized_;
  const size_t chunk_size_;
  size_t avail_in_;
  size_t avail_out_;

  std::unique_ptr<unsigned char[]> chunk_char_ptr_;
  QzSession_T session_;
  QzStream_T stream_;
};

} // namespace Compressor
} // namespace Envoy
