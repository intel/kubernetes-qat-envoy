#pragma once

#include "envoy_qatzip/qatzip.pb.h"
#include "envoy_qatzip/qatzip.pb.validate.h"

#include "extensions/filters/http/common/factory_base.h"
#include "extensions/filters/http/well_known_names.h"

namespace Envoy {
namespace Extensions {
namespace HttpFilters {
namespace Qatzip {

/**
 * Config registration for the brotli filter. @see NamedHttpFilterConfigFactory.
 */
class QatzipFilterFactory
    : public Common::FactoryBase<qatzip::Qatzip> {
public:
  QatzipFilterFactory() : FactoryBase("envoy.qatzip") {}

private:
  Http::FilterFactoryCb
  createFilterFactoryFromProtoTyped(const qatzip::Qatzip& config,
                                    const std::string& stats_prefix,
                                    Server::Configuration::FactoryContext& context) override;
};

} // namespace Qatzip
} // namespace HttpFilters
} // namespace Extensions
} // namespace Envoy
