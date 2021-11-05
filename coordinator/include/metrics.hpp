/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#pragma once

#include "gaia_coordinator.h"

using namespace std;

namespace gaia
{
namespace coordinator
{
namespace metrics
{

constexpr char c_ddl_extension[] = ".ddl";
constexpr char c_ruleset_extension[] = ".ruleset";

constexpr char c_build_project_action[] = "build";
constexpr char c_run_project_action[] = "run";
constexpr char c_stop_project_action[] = "stop";

/**
 * Emit metrics for when a file changes. Uses old_content to count how many characters have changed.
 * If old_content is nullptr, then it assumes no characters have changed.
 */
void emit_file_changed(session_metrics_t metrics, editor_content_t file, const char* old_content);

/**
 * Emit project metrics for things like: num_build, num_run, num_stops.
 */
void emit_project_metrics(session_metrics_t metrics, const std::string& project_action);

/**
 * Log the metrics.
 */
void dump_metrics(session_metrics_t metrics);

} // namespace metrics
} // namespace coordinator
} // namespace gaia
