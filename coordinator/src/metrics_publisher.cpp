/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include "metrics_publisher.hpp"

#include <iostream>
#include <random>
#include <thread>

#include <pqxx/pqxx>

#include <gaia/logger.hpp>

#include "gaia_coordinator.h"
#include "metrics.hpp"
#include "utils.hpp"

namespace gaia
{
namespace coordinator
{
namespace metrics
{

constexpr char c_sandbox_metrics_db_ddl[]
    = ""
      "CREATE TABLE IF NOT EXISTS session (\n"
      "    id UUID PRIMARY KEY NOT NULL,\n"
      "    is_active BOOL,\n"
      "    is_test BOOL,\n"
      "    last_timestamp timestamptz NOT NULL\n,"
      "    created_timestamp timestamptz NOT NULL\n,"
      "    current_project_name VARCHAR(50)\n"
      ");\n"
      "\n"
      "CREATE TABLE IF NOT EXISTS metric (\n"
      "    id BIGSERIAL PRIMARY KEY,\n"
      "    name VARCHAR(50) NOT NULL,\n"
      "    value DOUBLE PRECISION NOT NULL,\n"
      "    session_id UUID,\n"
      "    CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES session (id) ON DELETE CASCADE,\n"
      "    CONSTRAINT unique_metric_session UNIQUE (name, session_id)\n"
      ");";

std::string upsert_session_record_query(const session_t& session)
{
    return gaia_fmt::format(
        "INSERT INTO session (id, is_active, is_test, last_timestamp, created_timestamp, current_project_name)\n"
        "    VALUES ('{}', {}, {}, to_timestamp({}), to_timestamp({}), '{}')\n"
        "    ON CONFLICT (id) DO UPDATE\n"
        "        SET is_active = EXCLUDED.is_active,\n"
        "            is_test = EXCLUDED.is_test,\n"
        "            last_timestamp = EXCLUDED.last_timestamp,\n"
        "            created_timestamp = EXCLUDED.created_timestamp,\n"
        "            current_project_name = EXCLUDED.current_project_name;",
        session.id(), session.is_active(), session.is_test(), session.last_timestamp(),
        session.created_timestamp(), session.current_project_name());
}

std::string upsert_metric_record_query(const session_t& session)
{
    std::stringstream query;
    query << "INSERT INTO metric (name, value, session_id) VALUES\n";

    auto metrics_list = session.metrics();
    auto metrics_iter = session.metrics().begin();

    while (metrics_iter != metrics_list.end())
    {
        query << "('"
              << metrics_iter->name() << "',"
              << metrics_iter->value() << ",'"
              << metrics_iter->session().id() << "')";

        metrics_iter++;

        if (metrics_iter != metrics_list.end())
        {
            query << ",\n";
        }
        else
        {
            query << "\n";
        }
    }

    query << " ON CONFLICT ON CONSTRAINT unique_metric_session DO UPDATE\n"
             " SET value = EXCLUDED.value;";

    return query.str();
}

pqxx::connection create_connection()
{
    const char* cluster_password = std::getenv("SANDBOX_METRICS_DB_PASS");

    return pqxx::connection(
        gaia_fmt::format(
            "user=postgres "
            "host=sandbox-metrics-cluster.cluster-c0izgjn7ls3x.us-west-2.rds.amazonaws.com "
            "password={} "
            "dbname=sandbox_metrics",
            cluster_password));
}

void create_schema()
{
    gaia_log::app().info("Creating metrics DB schema...");

    pqxx::connection connection = create_connection();

    // Start a transaction.
    pqxx::work work{connection};
    gaia_log::app().debug("Create schema query: {}", c_sandbox_metrics_db_ddl);
    work.exec0(c_sandbox_metrics_db_ddl);

    work.commit();
}

void upsert_session(session_t session)
{
    try
    {
        gaia_log::app().info("Creating/updating session record: {}", session.id());

        pqxx::connection connection = create_connection();
        pqxx::work work{connection};

        std::string create_session_record = upsert_session_record_query(session);
        gaia_log::app().debug("Upsert session query: {}", create_session_record);
        work.exec0(create_session_record);

        work.commit();
    }
    catch (const std::exception& e)
    {
        gaia_log::app().error("Failed create session record: {}", e.what());
    }
}

void publish_metrics(session_t session)
{
    try
    {
        gaia_log::app().info("Publishing metrics for session: {}", session.id());

        pqxx::connection connection = create_connection();
        pqxx::work work{connection};

        std::string update_metrics = upsert_metric_record_query(session);
        gaia_log::app().info("Update metrics query: {}", update_metrics);
        work.exec0(update_metrics);

        work.commit();
    }
    catch (const std::exception& e)
    {
        gaia_log::app().error("Failed to publish metrics: {}", e.what());
    }
}

void create_fake_metrics()
{
    std::vector<std::thread> threads;

    for (auto session_it = session_t::list().begin();
         session_it != session_t::list().end();)
    {
        auto next_session_it = session_it++;
        next_session_it->metrics().clear();
        next_session_it->projects().clear();
        next_session_it->agent().disconnect();
        next_session_it->delete_row();
    }

    for (auto metric_it = session_metrics_t::list().begin();
         metric_it != session_metrics_t::list().end();)
    {
        auto next_metric_it = metric_it++;
        next_metric_it->delete_row();
    }

    std::random_device rdev;
    std::mt19937 rgen(rdev());
    std::uniform_int_distribution<int> dist1(3600, 86400);
    std::uniform_int_distribution<int> dist2(0, 100);

    uint64_t curr_time = utils::current_time_seconds();

    for (int i = 0; i < 100; i++)
    {
        threads.emplace_back(
            [&]()
            {
                auto session_id = utils::get_uuid();
                try
                {
                    gaia_log::app().info("Begin creating test session {}", session_id);
                    gaia::db::begin_session();
                    gaia::db::begin_transaction();
                    curr_time += +dist1(rgen);
                    session_writer session_w;
                    session_w.id = session_id;
                    session_w.current_project_name = "amr_swarm";
                    session_w.created_timestamp = curr_time;
                    session_w.last_timestamp = curr_time + 3600;
                    session_w.is_active = true;
                    session_w.is_test = true;
                    auto session = session_t::get(session_w.insert_row());

                    for (size_t j = 0; j < c_num_metrics; j++)
                    {
                        const char* name = c_all_metrics[j];
                        double value = dist2(rgen);

                        session_metrics_writer metrics_w;
                        metrics_w.name = name;
                        metrics_w.value = value;
                        metrics_w.session_id = session.id();
                        metrics_w.insert_row();
                    }

                    upsert_session(session);
                    publish_metrics(session);
                    gaia::db::commit_transaction();
                    gaia::db::end_session();
                    gaia_log::app().info("Successfully created test session {}", session_id);
                }
                catch (const std::exception& e)
                {
                    gaia_log::app().error(
                        "An error occurred while creating session {}: {} ",
                        session_id, e.what());
                }
            });
    }

    for (std::thread& thread : threads)
    {
        thread.join();
    }

    gaia_log::app().info("Test workload sucessfully created");
}

} // namespace metrics
} // namespace coordinator
} // namespace gaia
