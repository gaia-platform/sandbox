/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#pragma once

#include "gaia_coordinator.h"

namespace gaia
{
namespace coordinator
{
namespace metrics
{

// TODO this just contains a Postgres SQL connection PoC so far.
void publish_metrics(session_metrics_t metrics);

} // namespace metrics
} // namespace coordinator
} // namespace gaia
