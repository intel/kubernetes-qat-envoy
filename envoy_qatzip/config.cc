#include "config.h"

#include "qatzip_filter.h"

namespace Envoy {
namespace Extensions {
namespace HttpFilters {
namespace Qatzip {

Http::FilterFactoryCb QatzipFilterFactory::createFilterFactoryFromProtoTyped(
    const qatzip::Qatzip& proto_config,
    const std::string& stats_prefix, Server::Configuration::FactoryContext& context) {
  Common::Compressors::CompressorFilterConfigSharedPtr config =
      std::make_shared<QatzipFilterConfig>(proto_config, stats_prefix, context.scope(),
                                           context.runtime());
  return [config](Http::FilterChainFactoryCallbacks& callbacks) -> void {
    callbacks.addStreamFilter(std::make_shared<Common::Compressors::CompressorFilter>(config));
  };
}

/**
 * Static registration for the qatzip filter. @see NamedHttpFilterConfigFactory.
 */
REGISTER_FACTORY(QatzipFilterFactory, Server::Configuration::NamedHttpFilterConfigFactory);

} // namespace Qatzip
} // namespace HttpFilters
} // namespace Extensions
} // namespace Envoy
