////////////////////////////////////////////////////
// Copyright (c) Gaia Platform Authors
//
// Use of this source code is governed by the MIT
// license that can be found in the LICENSE.txt file
// or at https://opensource.org/licenses/MIT.
////////////////////////////////////////////////////

#include <cstring>

#include <algorithm>
#include <iostream>
#include <string>
#include <thread>

#include <aws/crt/Api.h>
#include <aws/crt/StlAllocator.h>
#include <aws/crt/auth/Credentials.h>
#include <aws/iot/MqttClient.h>

#include "gaia/logger.hpp"
#include "gaia/rules/rules.hpp"
#include "gaia/system.hpp"

#include "gaia_coordinator.h"
#include "json.hpp"
#include "utils.hpp"

using json = nlohmann::json;
using namespace Aws::Crt;
using namespace std;

using namespace gaia::common;
using namespace gaia::db;
using namespace gaia::db::triggers;
using namespace gaia::direct_access;
using namespace gaia::coordinator;
using namespace gaia::rules;

using namespace gaia::coordinator::utils;

string g_env_coordinator_name;

std::shared_ptr<Aws::Crt::Mqtt::MqttConnection> g_connection;

void send_message(const string& id, const string& topic, const string& payload);
void send_message(const string& id, const string& topic_level_1, const string& topic_level_2, const string& payload);
void send_message(const string& id, const string& topic_level_1, const string& topic_level_2, const string& topic_level_3, const string& payload);
void stop_gaia_container(const string& agent_id);

auto g_on_publish_complete = [](Mqtt::MqttConnection&, uint16_t packet_id, int error_code)
{
    if (packet_id)
    {
        gaia_log::app().debug("Operation on packetId {} succeeded", packet_id);
    }
    else
    {
        gaia_log::app().error("Operation failed with error {}", aws_error_debug_str(error_code));
    }
};

void publish_message(const string& topic, const string& payload)
{
    if (g_connection)
    {
        gaia_log::app().info("Publishing: topic: {} payload: {}", topic, trim_to_size(payload));
        ByteBuf payload_buf = ByteBufFromArray(reinterpret_cast<const uint8_t*>(payload.data()), payload.length());
        g_connection->Publish(topic.c_str(), AWS_MQTT_QOS_AT_LEAST_ONCE, false, payload_buf, g_on_publish_complete);
    }
}

void dump_db(const string& filter = "")
{
    printf("\n");
    printf("--------------------------------------------------------\n");
    printf("Sessions:\n");
    for (const auto& s : session_t::list())
    {
        if (strncmp(filter.c_str(), s.id(), filter.length()) != 0)
        {
            continue;
        }
        printf("--------------------------------------------------------\n");
        printf("session:              %s\n", s.id());
        printf("is_active:            %s\n", s.is_active() ? "YES" : "NO");
        printf("current_project_name: %s\n", s.current_project_name());
        printf("send_project_files:   %s\n", s.send_project_files() ? "TRUE" : "FALSE");
        printf("last_timestamp:       %lu\n", s.last_timestamp());
        printf("created_timestamp:    %lu\n", s.created_timestamp());
        if (s.agent())
        {
            printf("agent id:             %s\n", s.agent().id());
        }
        printf("    Projects:\n");
        for (const auto& p : s.projects())
        {
            printf("    ----------------------------------------------------\n");
            printf("    name:               %s\n", p.name());
            for (const auto& pf : p.project_files())
            {
                printf("        -------------------------------------------------\n");
                printf("        name:               %s\n", pf.name());
            }
        }
    }
    printf("--------------------------------------------------------\n");
    printf("Agents:\n");
    for (const auto& a : agent_t::list())
    {
        if (strncmp(filter.c_str(), a.id(), filter.length()) != 0)
        {
            continue;
        }
        printf("--------------------------------------------------------\n");
        printf("agent:                %s\n", a.id());
        printf("in_use:               %s\n", a.in_use() ? "YES" : "NO");
        printf("last_timestamp:       %lu\n", a.last_timestamp());
        printf("created_timestamp:    %lu\n", a.created_timestamp());
        if (a.session())
        {
            printf("session id:           %s\n", a.session().id());
            printf("session timestamp:    %lu\n", a.session().last_timestamp());
        }
    }
    printf("--------------------------------------------------------\n");
}

session_t get_session(const string& id)
{
    auto session_iter = session_t::list().where(session_t::expr::id == id).begin();
    if (session_iter == session_t::list().end())
    {
        gaia_log::app().info("Creating new session with id {}", id);
        session_writer w;
        w.id = id;
        w.is_active = false;
        w.last_timestamp = current_time_seconds();
        w.created_timestamp = current_time_seconds();
        w.current_project_name = "none";
        session_t session = session_t::get(w.insert_row());

        return session;
    }
    gaia_log::app().debug("Session with id {} already exists", id);
    return *session_iter;
}

project_file_t project_file(const string& name, const string& content)
{
    project_file_writer w;
    w.name = name;
    w.content = content;
    return project_file_t::get(w.insert_row());
}

editor_content_t editor_content(const string& name, const string& content)
{
    project_file_t pf = project_file(name, content);

    editor_content_writer w;
    w.timestamp = current_time_seconds();
    auto ec = editor_content_t::get(w.insert_row());

    pf.editor_contents().insert(ec);
    return ec;
}

vector<string> split_topic(const string& topic)
{
    vector<string> result;
    size_t left = 0;
    size_t right = topic.find('/');
    while (right != string::npos)
    {
        result.push_back(topic.substr(left, right - left));
        left = right + 1;
        right = topic.find('/', left);
    }
    result.push_back(topic.substr(left));
    return result;
}

void on_message(Mqtt::MqttConnection&, const String& topic, const ByteBuf& payload, bool /*dup*/, Mqtt::QOS /*qos*/, bool /*retain*/)
{
    vector<string> topic_vector = split_topic(topic.c_str());
    string payload_str(reinterpret_cast<char*>(payload.buffer), payload.len);
    payload_str += '\0';
    gaia_log::app().info("Received topic: {} payload: {}", topic.c_str(), trim_to_size(payload_str));

    if (topic_vector.size() < 3)
    {
        gaia_log::app().error("Unexpected topic:{}", topic.c_str(), trim_to_size(payload_str));
        return;
    }

    begin_transaction();

    if (topic_vector[2] == "agent")
    {
        if (topic_vector.size() < 4)
        {
            gaia_log::app().error("Unexpected: topic: {} payload: {}", topic.c_str(), trim_to_size(payload_str));
        }
        else
        {
            auto agent_iter = agent_t::list().where(agent_t::expr::id == topic_vector[1]).begin();
            if (agent_iter != agent_t::list().end())
            {
                auto agent_w = agent_iter->writer();
                agent_w.last_timestamp = current_time_seconds();
                agent_w.update_row();
            }
            else
            {
                stop_gaia_container(topic_vector[1]);
            }
        }
    }
    else
    {
        session_t session = get_session(topic_vector[1]);
        session_writer session_w = session.writer();
        session_w.last_timestamp = current_time_seconds();

        if (topic_vector[2] == "project")
        {
            if (topic_vector.size() < 4)
            {
                gaia_log::app().error("Unexpected topic: {} payload: {}", topic.c_str(), trim_to_size(payload_str));
            }
            else
            {
                if (session.agent())
                {
                    send_message(session.agent().id(), payload_str, topic_vector[3]);
                }

                if (topic_vector[3] == "exit")
                {
                    session_w.current_project_name = "none";
                }
                else if (topic_vector[3] == "select")
                {
                    if (strcmp(payload_str.c_str(), session.current_project_name()) == 0)
                    {
                        session_w.send_project_files = true;
                    }
                    else
                    {
                        session_w.current_project_name = payload_str.c_str();
                    }
                }
            }
        }
        else if (topic_vector[2] == "editor")
        {
            if (topic_vector.size() < 4)
            {
                gaia_log::app().error("Unexpected topic: {} payload: {}", topic.c_str(), trim_to_size(payload_str));
            }
            else if (topic_vector.size() == 5 && topic_vector[3] == "file")
            {
                editor_content_t activity = editor_content(topic_vector[4], payload_str);
                session.editor_contents().insert(activity);

                for (auto& ec : session.editor_contents())
                {
                    gaia_log::app().info("editor_content_t Session: {}, file: {}", session.id(), ec.project_file().name());
                }

                for (auto& project : session.projects())
                {
                    for (auto& pf : project.project_files())
                    {
                        gaia_log::app().info("project_file Session: {}, file: {}", session.id(), pf.name());
                    }
                }
            }
            else if (topic_vector[3] == "terminal_input")
            {
                session_w.terminal_input = payload_str;
            }
        }
        session_w.update_row();
    }

    commit_transaction();
}


int main()
{
    char* s = std::getenv("COORDINATOR_NAME");
    if (s)
    {
        g_env_coordinator_name = s;
    }
    else
    {
        fprintf(stderr, "Environment variable COORDINATOR_NAME must be set. In production (and only in production) the COORDINATOR_NAME must be set to sandbox_coordinator\n");
        exit(-1);
    }

    if (g_env_coordinator_name == "sandbox_coordinator")
    {
        fprintf(stdout, "Environment variable COORDINATOR_NAME must only be set to sandbox_coordinator when deployed in production.\n");
        fprintf(stdout, "Are you deploying in production and sure you want to continue?\n");
        fprintf(stdout, "(Enter y to continue, n to exit)\n");
        String input;
        std::getline(std::cin, input);
        if (input != "y" && input != "Y")
        {
            exit(-1);
        }
    }

    gaia::system::initialize();

    begin_transaction();
    dump_db();
    commit_transaction();

    ApiHandle api_handle;

    String endpoint("a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com");
    String certificate_path("../certs/coordinator-certificate.pem.crt");
    String key_path("../certs/coordinator-private.pem.key");
    String ca_file("../certs/AmazonRootCA1.pem");
    String client_id = get_uuid().c_str();

    Io::EventLoopGroup event_loop_group(1);
    if (!event_loop_group)
    {
        fprintf(
            stderr, "Event Loop Group Creation failed with error %s\n", ErrorDebugString(event_loop_group.LastError()));
        exit(-1);
    }

    Aws::Crt::Io::DefaultHostResolver default_host_resolver(event_loop_group, 1, 5);
    Io::ClientBootstrap bootstrap(event_loop_group, default_host_resolver);

    if (!bootstrap)
    {
        fprintf(stderr, "ClientBootstrap failed with error %s\n", ErrorDebugString(bootstrap.LastError()));
        exit(-1);
    }

    Aws::Iot::MqttClientConnectionConfigBuilder builder;

    builder = Aws::Iot::MqttClientConnectionConfigBuilder(certificate_path.c_str(), key_path.c_str());
    builder.WithCertificateAuthority(ca_file.c_str());
    builder.WithEndpoint(endpoint);

    auto client_config = builder.Build();

    if (!client_config)
    {
        fprintf(
            stderr,
            "Client Configuration initialization failed with error %s\n",
            ErrorDebugString(client_config.LastError()));
        exit(-1);
    }

    Aws::Iot::MqttClient mqtt_client(bootstrap);

    if (!mqtt_client)
    {
        fprintf(stderr, "MQTT Client Creation failed with error %s\n", ErrorDebugString(mqtt_client.LastError()));
        exit(-1);
    }

    g_connection = mqtt_client.NewConnection(client_config);

    if (!g_connection)
    {
        fprintf(stderr, "MQTT Connection Creation failed with error %s\n", ErrorDebugString(mqtt_client.LastError()));
        exit(-1);
    }

    std::promise<bool> connection_completed_promise;
    std::promise<void> connection_closed_promise;

    auto on_connection_completed = [&connection_completed_promise](Mqtt::MqttConnection&, int error_code, Mqtt::ReturnCode returnCode, bool)
    {
        if (error_code)
        {
            fprintf(stdout, "Connection failed with error %s\n", ErrorDebugString(error_code));
            connection_completed_promise.set_value(false);
        }
        else
        {
            if (returnCode != AWS_MQTT_CONNECT_ACCEPTED)
            {
                fprintf(stdout, "Connection failed with mqtt return code %d\n", static_cast<int>(returnCode));
                connection_completed_promise.set_value(false);
            }
            else
            {
                fprintf(stdout, "Connection completed successfully.\n");
                gaia::system::initialize();
                connection_completed_promise.set_value(true);
            }
        }
    };

    auto on_interrupted = [&](Mqtt::MqttConnection&, int error)
    {
        fprintf(stdout, "Connection interrupted with error %s\n", ErrorDebugString(error));
    };

    auto on_resumed = [&](Mqtt::MqttConnection&, Mqtt::ReturnCode, bool)
    { fprintf(stdout, "Connection resumed\n"); };

    auto on_disconnect = [&connection_closed_promise](Mqtt::MqttConnection&)
    {
        {
            fprintf(stdout, "Disconnect completed\n");
            gaia::system::shutdown();
            connection_closed_promise.set_value();
        }
    };

    g_connection->OnConnectionCompleted = std::move(on_connection_completed);
    g_connection->OnDisconnect = std::move(on_disconnect);
    g_connection->OnConnectionInterrupted = std::move(on_interrupted);
    g_connection->OnConnectionResumed = std::move(on_resumed);

    fprintf(stdout, "Connecting...\n");
    if (!g_connection->Connect(client_id.c_str(), false, 1000))
    {
        fprintf(stderr, "MQTT Connection failed with error %s\n", ErrorDebugString(g_connection->LastError()));
        exit(-1);
    }

    if (connection_completed_promise.get_future().get())
    {
        std::promise<void> subscribe_finished_promise;
        auto on_sub_ack =
            [&subscribe_finished_promise](Mqtt::MqttConnection&, uint16_t packet_id, const String& topic, Mqtt::QOS QoS, int errorCode)
        {
            if (errorCode)
            {
                fprintf(stderr, "Subscribe failed with error %s\n", aws_error_debug_str(errorCode));
                exit(-1);
            }
            else
            {
                if (!packet_id || QoS == AWS_MQTT_QOS_FAILURE)
                {
                    fprintf(stderr, "Subscribe rejected by the broker.");
                    exit(-1);
                }
                else
                {
                    fprintf(stdout, "Subscribe on topic %s on packetId %d Succeeded\n", topic.c_str(), packet_id);
                }
            }
            subscribe_finished_promise.set_value();
        };

        string topic = g_env_coordinator_name;
        topic += "/#";
        g_connection->Subscribe(topic.c_str(), AWS_MQTT_QOS_AT_LEAST_ONCE, on_message, on_sub_ack);
        subscribe_finished_promise.get_future().wait();

        String input = "";
        while (input != "x")
        {
            fprintf(stdout, "Enter to see database. Enter string to search id prefixes. Enter 'x' to exit this program.\n");
            std::getline(std::cin, input);
            if (input != "x")
            {
                begin_transaction();
                dump_db(input.c_str());
                commit_transaction();
            }
        }

        std::promise<void> unsubscribe_finished_promise;
        g_connection->Unsubscribe(
            "#",
            [&unsubscribe_finished_promise](Mqtt::MqttConnection&, uint16_t, int)
            { unsubscribe_finished_promise.set_value(); });
        unsubscribe_finished_promise.get_future().wait();
    }

    if (g_connection->Disconnect())
    {
        connection_closed_promise.get_future().wait();
    }

    gaia::system::shutdown();

    return 0;
}
