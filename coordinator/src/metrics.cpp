/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include "metrics.hpp"

#include <string>

#include <gaia/logger.hpp>

namespace gaia
{
namespace coordinator
{
namespace metrics
{

inline bool ends_with(std::string const& value, std::string const& ending)
{
    if (ending.size() > value.size())
        return false;
    return std::equal(ending.rbegin(), ending.rend(), value.rbegin());
}

// Copied from https://rosettacode.org/wiki/Levenshtein_distance#C.2B.2B
size_t levenshtein_distance(const string& s1, const string& s2)
{
    const size_t m(s1.size()), n(s2.size());

    if (m == 0)
    {
        return n;
    }

    if (n == 0)
    {
        return m;
    }

    // allocation below is not ISO-compliant,
    // it won't work with -pedantic-errors.
    size_t costs[n + 1];

    for (size_t k = 0; k <= n; k++)
    {
        costs[k] = k;
    }

    size_t i{0};
    for (char const& c1 : s1)
    {
        costs[0] = i + 1;
        size_t corner{i}, j{0};
        for (char const& c2 : s2)
        {
            size_t upper{costs[j + 1]};
            if (c1 == c2)
            {
                costs[j + 1] = corner;
            }
            else
            {
                size_t t(upper < corner ? upper : corner);
                costs[j + 1] = (costs[j] < t ? costs[j] : t) + 1;
            }

            corner = upper;
            j++;
        }
        i++;
    }

    return costs[n];
}

void emit_file_changed(gaia::coordinator::session_metrics_t metrics, gaia::coordinator::editor_content_t file, const char* old_content)
{
    session_metrics_writer session_metrics_w = metrics.writer();
    size_t char_changes = 0;

    if (old_content != nullptr)
    {
        // TODO with this logic we are going to miss the characters modified the first time
        //   because we have nothing to compare against to.
        char_changes = levenshtein_distance(old_content, file.project_file().content());
    }

    if (ends_with(file.project_file().name(), c_ruleset_extension))
    {
        session_metrics_w.num_ruleset_edits = metrics.num_ruleset_edits() + 1;
        session_metrics_w.num_ruleset_changed_chars = metrics.num_ruleset_changed_chars() + char_changes;
    }
    else if (ends_with(file.project_file().name(), c_ddl_extension))
    {
        session_metrics_w.num_ddl_edits = metrics.num_ddl_edits() + 1;
        session_metrics_w.num_ddl_changed_chars = metrics.num_ddl_changed_chars() + char_changes;
    }
    session_metrics_w.update_row();
}

void emit_project_metrics(session_metrics_t metrics, const std::string& project_action)
{
    session_metrics_writer session_metrics_w = metrics.writer();

    if (project_action == c_build_project_action)
    {
        session_metrics_w.num_builds = metrics.num_builds() + 1;
    }
    else if (project_action == c_run_project_action)
    {
        session_metrics_w.num_runs = metrics.num_runs() + 1;
    }
    else if (project_action == c_stop_project_action)
    {
        session_metrics_w.num_stops = metrics.num_stops() + 1;
    }

    session_metrics_w.update_row();
}

void dump_metrics(session_metrics_t metrics)
{
    gaia_log::app().info(
        "session_metrics_t: \n"
        " num_ruleset_edits: {}\n"
        " num_ddl_edits: {}\n"
        " num_ruleset_changed_chars: {}\n"
        " num_ddl_changed_chars: {}\n"
        " num_builds: {}\n"
        " num_runs: {}\n"
        " num_stops: {}\n"
        " num_errors: {}",
        metrics.num_ruleset_edits(),
        metrics.num_ddl_edits(),
        metrics.num_ruleset_changed_chars(),
        metrics.num_ddl_changed_chars(),
        metrics.num_builds(),
        metrics.num_runs(),
        metrics.num_stops(),
        metrics.num_errors());
}

} // namespace metrics
} // namespace coordinator
} // namespace gaia
