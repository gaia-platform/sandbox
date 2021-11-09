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
// TODO this could be better into a class, saving the database connection as member.

/**
 * Creates the database schema for the metrics.
 */
void create_schema();

/**
 * Creates or update a session record in the database.
 */
void upsert_session(session_t session);

/**
 * Creates or update all the metrics records for the given session.
 */
void publish_metrics(session_t session);

/**
 * Creates some fake data in the database to test visualization etc..
 */
void create_fake_metrics();

} // namespace metrics
} // namespace coordinator
} // namespace gaia
