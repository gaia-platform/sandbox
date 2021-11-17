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

template <size_t n>
constexpr size_t length(char const* const (&)[n])
{
    return n;
}

constexpr const char c_ddl_extension[] = ".ddl";
constexpr const char c_ruleset_extension[] = ".ruleset";

constexpr const char c_build_project_action[] = "build";
constexpr const char c_run_project_action[] = "run";
constexpr const char c_stop_project_action[] = "stop";

constexpr const char c_ruleset_edits[] = "count_ruleset_edits";
constexpr const char c_ddl_edits[] = "count_ddl_edits";
constexpr const char c_ruleset_changed_chars[] = "count_ruleset_changed_chars";
constexpr const char c_ddl_changed_chars[] = "count_ddl_changed_chars";
constexpr const char c_builds[] = "count_builds";
constexpr const char c_runs[] = "count_runs";
constexpr const char c_stops[] = "count_stops";
constexpr const char c_errors[] = "count_errors";

constexpr const char* c_all_metrics[] = {
    c_ruleset_edits,
    c_ddl_edits,
    c_ruleset_changed_chars,
    c_ddl_changed_chars,
    c_builds,
    c_runs,
    c_errors};

constexpr size_t c_num_metrics = length(c_all_metrics);

/**
 * Find a specific session_metrics_t within a session.
 */
session_metrics_t lookup_metric(session_t session, const char* name);

/**
 * Find up the value for a given metric in the given session.
 * Return 0.0 if the metric is not found.
 */
double lookup_metric_value(session_t session, const char* name);

/**
 * Creates a metric for a session with value 1.0.
 */
session_metrics_t upsert_increment_metric_value(session_t session, const char* name, double value = 1.0);

/**
 * Emit metrics for when a file changes. Uses old_content to count how many characters have changed.
 * If old_content is nullptr, then it assumes no characters have changed.
 */
void emit_file_changed(session_t session, editor_content_t file, const char* old_content);

/**
 * Emit project metrics for things like: num_build, num_run, num_stops.
 */
void emit_project_metrics(session_t session, const std::string& project_action);

/**
 * Log the metrics.
 */
void log_metrics(session_t session);

} // namespace metrics
} // namespace coordinator
} // namespace gaia
