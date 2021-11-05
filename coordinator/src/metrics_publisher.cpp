/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include "metrics_publisher.hpp"

#include <iostream>

#include <pqxx/pqxx>

#include <gaia/logger.hpp>

namespace gaia
{
namespace coordinator
{
namespace metrics
{

void publish_metrics(session_metrics_t metrics)
{
    try
    {
        char* cluster_password = std::getenv("SANDBOX_METRICS_DB_PASS");

        // Connect to the database.
        pqxx::connection conn(
            gaia_fmt::format(
                "user=postgres "
                "host=sandbox-metrics-cluster.cluster-c0izgjn7ls3x.us-west-2.rds.amazonaws.com "
                "password={} "
                "dbname=sandbox_metrics",
                cluster_password));
        std::cout << "Connected to " << conn.dbname() << '\n';

        // Start a transaction.
        pqxx::work work{conn};

        work.exec0("CREATE TABLE IF NOT EXISTS employee ("
                   "    user_id serial PRIMARY KEY,"
                   "    name VARCHAR ( 50 ) NOT NULL,"
                   "    salary INTEGER"
                   ")");

        work.exec0("INSERT INTO employee (name, salary) VALUES ('suppini', 100)");

        // Perform a query and retrieve all results.
        pqxx::result result{work.exec("SELECT name FROM employee")};

        // Iterate over results.
        std::cout << "Found " << result.size() << " employees:\n";
        for (auto row : result)
            std::cout << row[0].c_str() << '\n';

        // Perform a query and check that it returns no result.
        std::cout << "Doubling all employees' salaries...\n";
        work.exec0("UPDATE employee SET salary = salary*2");

        // Commit the transaction.
        std::cout << "Making changes definite: ";
        work.commit();
        std::cout << "OK.\n";
    }
    catch (std::exception const& e)
    {
        std::cerr << e.what() << '\n';
    }
}

} // namespace metrics
} // namespace coordinator
} // namespace gaia
