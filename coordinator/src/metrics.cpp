/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include "metrics.hpp"

#include <sstream>
#include <string>

#include <gaia/logger.hpp>

#include "utils.hpp"

namespace gaia
{
namespace coordinator
{
namespace metrics
{

inline bool ends_with(std::string const& value, std::string const& ending)
{
    if (ending.size() > value.size())
    {
        return false;
    }
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

void emit_file_changed(session_t session, gaia::coordinator::editor_content_t file, const char* old_content)
{
    bool metric_updated = true;

    size_t char_changes = 0;

    if (old_content != nullptr)
    {
        // TODO with this logic we are going to miss the characters modified the first time
        //   because we have nothing to compare against to.
        char_changes = levenshtein_distance(old_content, file.project_file().content());
    }

    if (ends_with(file.project_file().name(), c_ruleset_extension))
    {
        upsert_increment_metric_value(session, c_ruleset_edits);
        upsert_increment_metric_value(session, c_ruleset_changed_chars, char_changes);
    }
    else if (ends_with(file.project_file().name(), c_ddl_extension))
    {
        upsert_increment_metric_value(session, c_ddl_edits);
        upsert_increment_metric_value(session, c_ddl_changed_chars, char_changes);
    }
    else
    {
        metric_updated = false;
    }

    if (metric_updated)
    {
        session_writer session_w = session.writer();
        session_w.last_metric_update_timestamp = utils::current_time_seconds();
        session_w.update_row();
    }
}

void emit_project_metrics(session_t session, const std::string& project_action)
{
    bool metric_updated = true;

    if (project_action == c_build_project_action)
    {
        upsert_increment_metric_value(session, c_builds);
    }
    else if (project_action == c_run_project_action)
    {
        upsert_increment_metric_value(session, c_runs);
    }
    else if (project_action == c_stop_project_action)
    {
        upsert_increment_metric_value(session, c_stops);
    }
    else
    {
        metric_updated = false;
    }

    if (metric_updated)
    {
        session_writer session_w = session.writer();
        session_w.last_metric_update_timestamp = utils::current_time_seconds();
        session_w.update_row();
    }
}

void log_metrics(session_t session)
{
    stringstream metrics_stream("session_metrics_t:\n");

    for (size_t i = 0; i < c_num_metrics; i++)
    {
        const char* name = c_all_metrics[i];
        double value = lookup_metric_value(session, name);
        metrics_stream << " " << name << ": " << value << '\n';
    }

    gaia_log::app().info(metrics_stream.str().c_str());
}

session_metrics_t lookup_metric(session_t session, const char* name)
{
    //    using metrics_expr = session_metrics_expr;
    auto metrics_iter = session.metrics()
                            .where(session_metrics_expr::name == name);

    if (metrics_iter.begin() != metrics_iter.end())
    {
        return *(metrics_iter.begin());
    }

    return session_metrics_t();
}

session_metrics_t upsert_increment_metric_value(session_t session, const char* name, double value)
{
    session_metrics_t metrics = lookup_metric(session, name);

    if (!metrics)
    {
        session_metrics_writer metrics_w;
        metrics_w.name = name;
        metrics_w.session_id = session.id();
        metrics_w.value = 1.0;
        metrics_w.insert_row();
    }
    else
    {
        session_metrics_writer metrics_w = metrics.writer();
        metrics_w.value = metrics.value() + value;
        metrics_w.update_row();
    }

    return metrics;
}

double lookup_metric_value(session_t session, const char* name)
{
    session_metrics_t metrics = lookup_metric(session, name);

    if (!metrics)
    {
        return 0.0;
    }

    return metrics.value();
}

} // namespace metrics
} // namespace coordinator
} // namespace gaia
