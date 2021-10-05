/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include <unistd.h>

#include <cstring>
#include <ctime>

#include <algorithm>
#include <iostream>
#include <string>
#include <thread>

#include <aws/crt/Api.h>
#include <aws/crt/StlAllocator.h>
#include <aws/crt/auth/Credentials.h>
#include <aws/crt/io/TlsOptions.h>

#include <aws/iot/MqttClient.h>

#include <aws/crt/UUID.h>
#include <condition_variable>
#include <mutex>

#include "gaia/rules/rules.hpp"
#include "gaia/system.hpp"
#include "gaia/logger.hpp"

#include "gaia_coordinator.h"
#include "json.hpp"

using json = nlohmann::json;
using namespace Aws::Crt;
using namespace std;

using namespace gaia::common;
using namespace gaia::db;
using namespace gaia::db::triggers;
using namespace gaia::direct_access;
using namespace gaia::coordinator;
using namespace gaia::rules;

std::shared_ptr<Aws::Crt::Mqtt::MqttConnection> connection;

void send_message(const string& id, const string& topic, const string& payload);
void send_message(const string& id, const string& topic_level_1, const string& topic_level_2, const string& payload);
void send_message(const string& id, const string& topic_level_1, const string& topic_level_2, const string& topic_level_3, const string& payload);
void stop_gaia_container(const string& agent_id);

string get_uuid()
{
    return Aws::Crt::UUID().ToString().c_str();
}

auto onPublishComplete = [](Mqtt::MqttConnection &, uint16_t packetId, int errorCode)
{
    if (packetId)
    {
        gaia_log::app().info("Operation on packetId {} succeeded", packetId);
    }
    else
    {
        gaia_log::app().info("Operation failed with error {}", aws_error_debug_str(errorCode));
    }
};

void publish_message(const string& topic, const string& payload)
{
    if (connection)
    {
        gaia_log::app().info("Publishing on topic {}", topic);
        ByteBuf payload_buf = ByteBufFromArray((const uint8_t *)payload.data(), payload.length());
        connection->Publish(topic.c_str(), AWS_MQTT_QOS_AT_LEAST_ONCE, false, payload_buf, onPublishComplete);
    }
}

void dump_db()
{
    printf("\n");
    printf("--------------------------------------------------------\n");
    printf("Sessions:\n");
    for (const auto &s : session_t::list())
    {
        printf("--------------------------------------------------------\n");
        printf("session:              %s\n", s.id());
        printf("is_active:            %s\n", s.is_active() ? "YES" : "NO");
        printf("current_project_name: %s\n", s.current_project_name());
        printf("last_timestamp:       %lu\n", s.last_timestamp());
        printf("created_timestamp:    %lu\n", s.created_timestamp());
        if (s.agent())
        {
            printf("agent id:             %s\n", s.agent().id());
        }
        printf("    Projects:\n");
        for (const auto &p : s.projects())
        {
            printf("    ----------------------------------------------------\n");
            printf("    name:               %s\n", p.name());
            for (const auto &pf : p.project_files())
            {
                printf("        -------------------------------------------------\n");
                printf("        name:               %s\n", pf.name());
            }
        }
    }
    printf("--------------------------------------------------------\n");
    printf("Agents:\n");
    for (const auto &a : agent_t::list())
    {
        printf("--------------------------------------------------------\n");
        printf("agent:                %s\n", a.id());
        printf("in_use:               %s\n", a.in_use() ? "YES" : "NO");
        printf("last_timestamp:       %lu\n", a.last_timestamp());
        printf("created_timestamp:    %lu\n", a.created_timestamp());
        if (a.session())
        {
            printf("session id:           %s\n", a.session().id());
        }
    }
    printf("--------------------------------------------------------\n");
}

session_t get_session(const string& id)
{
    auto session_iter = session_t::list().where(session_t::expr::id == id).begin();
    if (session_iter == session_t::list().end())
    {
        gaia_log::app().info("Creating new session");
        session_writer w;
        w.id = id;
        w.is_active = false;
        w.last_timestamp = (uint64_t)time(nullptr);
        w.created_timestamp = (uint64_t)time(nullptr);
        w.current_project_name = "none";
        return session_t::get(w.insert_row());
    }
    gaia_log::app().info("Existing session found");
    return *session_iter;
}

editor_file_request_t editor_file_request(const string& name)
{
    editor_file_request_writer w;
    w.name = name;
    w.timestamp = (uint64_t)time(nullptr);
    return editor_file_request_t::get(w.insert_row());
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
    auto pf = project_file(name, content);

    editor_content_writer w;
    w.timestamp = (uint64_t)time(nullptr);
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

void on_message(Mqtt::MqttConnection &, const String& topic, const ByteBuf& payload,
                bool /*dup*/, Mqtt::QOS /*qos*/, bool /*retain*/)
{
    vector<string> topic_vector = split_topic(topic.c_str());
    string payload_str((char *)payload.buffer, payload.len);
    payload_str += '\0';
    gaia_log::app().info("Message received on topic {}", topic.c_str());
    gaia_log::app().info("Message: {}", payload_str.c_str());

    if (topic_vector.size() < 3)
    {
        gaia_log::app().error("Unexpected topic");
        return;
    }

    begin_transaction();

    if (topic_vector[2] == "agent")
    {
        if (topic_vector.size() < 4)
        {
            gaia_log::app().error("Unexpected topic {}", topic.c_str());
        }
        else
        {
            auto agent_iter = agent_t::list().where(agent_t::expr::id == topic_vector[1]).begin();
            if (agent_iter != agent_t::list().end())
            {
                auto w = agent_iter->writer();
                w.last_timestamp = (uint64_t)time(nullptr);
                w.update_row();
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
        session_writer w = session.writer();
        w.last_timestamp = (uint64_t)time(nullptr);

        if (topic_vector[2] == "project")
        {
            if (topic_vector.size() < 4)
            {
                gaia_log::app().error("Unexpected topic {}", topic.c_str());
            }
            else
            {
                if (topic_vector[3] == "exit")
                {
                    w.current_project_name = "none";
                }
                else if (topic_vector[3] == "select")
                {
                    w.current_project_name = payload_str.c_str();
                    send_message(session.agent().id(), "project", "select", payload_str.c_str());
                }
            }
        }
        else if (topic_vector[2] == "editor")
        {
            if (topic_vector.size() < 4)
            {
                gaia_log::app().error("Unexpected topic");
            }
            else if (topic_vector[3] == "req")
            {
                auto activity = editor_file_request(payload_str.c_str());
                session.editor_file_requests().insert(activity);
            }
            else if (topic_vector.size() == 5 && topic_vector[3] == "file")
            {
                auto activity = editor_content(topic_vector[4], payload_str.c_str());
                session.editor_contents().insert(activity);
            }
        }
        w.update_row();
    }

    commit_transaction();
}

int main()
{
    gaia::system::initialize();

    begin_transaction();
    dump_db();
    commit_transaction();

    ApiHandle apiHandle;

    String endpoint("a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com");
    String certificatePath("../certs/coordinator-certificate.pem.crt");
    String keyPath("../certs/coordinator-private.pem.key");
    String caFile("../certs/AmazonRootCA1.pem");
    String clientId = Aws::Crt::UUID().ToString();
    String topic("client-xx/topic_1");

    Io::EventLoopGroup eventLoopGroup(1);
    if (!eventLoopGroup)
    {
        fprintf(
            stderr, "Event Loop Group Creation failed with error %s\n", ErrorDebugString(eventLoopGroup.LastError()));
        exit(-1);
    }

    Aws::Crt::Io::DefaultHostResolver defaultHostResolver(eventLoopGroup, 1, 5);
    Io::ClientBootstrap bootstrap(eventLoopGroup, defaultHostResolver);

    if (!bootstrap)
    {
        fprintf(stderr, "ClientBootstrap failed with error %s\n", ErrorDebugString(bootstrap.LastError()));
        exit(-1);
    }

    Aws::Iot::MqttClientConnectionConfigBuilder builder;

    builder = Aws::Iot::MqttClientConnectionConfigBuilder(certificatePath.c_str(), keyPath.c_str());
    builder.WithCertificateAuthority(caFile.c_str());
    builder.WithEndpoint(endpoint);

    auto clientConfig = builder.Build();

    if (!clientConfig)
    {
        fprintf(
            stderr,
            "Client Configuration initialization failed with error %s\n",
            ErrorDebugString(clientConfig.LastError()));
        exit(-1);
    }

    Aws::Iot::MqttClient mqttClient(bootstrap);

    if (!mqttClient)
    {
        fprintf(stderr, "MQTT Client Creation failed with error %s\n", ErrorDebugString(mqttClient.LastError()));
        exit(-1);
    }

    connection = mqttClient.NewConnection(clientConfig);

    if (!connection)
    {
        fprintf(stderr, "MQTT Connection Creation failed with error %s\n", ErrorDebugString(mqttClient.LastError()));
        exit(-1);
    }

    std::promise<bool> connectionCompletedPromise;
    std::promise<void> connectionClosedPromise;

    auto onConnectionCompleted = [&](Mqtt::MqttConnection &, int errorCode, Mqtt::ReturnCode returnCode, bool)
    {
        if (errorCode)
        {
            fprintf(stdout, "Connection failed with error %s\n", ErrorDebugString(errorCode));
            connectionCompletedPromise.set_value(false);
        }
        else
        {
            if (returnCode != AWS_MQTT_CONNECT_ACCEPTED)
            {
                fprintf(stdout, "Connection failed with mqtt return code %d\n", (int)returnCode);
                connectionCompletedPromise.set_value(false);
            }
            else
            {
                fprintf(stdout, "Connection completed successfully.");
                gaia::system::initialize();
                connectionCompletedPromise.set_value(true);
            }
        }
    };

    auto onInterrupted = [&](Mqtt::MqttConnection &, int error)
    {
        fprintf(stdout, "Connection interrupted with error %s\n", ErrorDebugString(error));
    };

    auto onResumed = [&](Mqtt::MqttConnection &, Mqtt::ReturnCode, bool)
    { fprintf(stdout, "Connection resumed\n"); };

    auto onDisconnect = [&](Mqtt::MqttConnection &)
    {
        {
            fprintf(stdout, "Disconnect completed\n");
            gaia::system::shutdown();
            connectionClosedPromise.set_value();
        }
    };

    connection->OnConnectionCompleted = std::move(onConnectionCompleted);
    connection->OnDisconnect = std::move(onDisconnect);
    connection->OnConnectionInterrupted = std::move(onInterrupted);
    connection->OnConnectionResumed = std::move(onResumed);

    fprintf(stdout, "Connecting...\n");
    if (!connection->Connect(clientId.c_str(), false, 1000))
    {
        fprintf(stderr, "MQTT Connection failed with error %s\n", ErrorDebugString(connection->LastError()));
        exit(-1);
    }

    if (connectionCompletedPromise.get_future().get())
    {
        std::promise<void> subscribeFinishedPromise;
        auto onSubAck =
            [&](Mqtt::MqttConnection &, uint16_t packetId, const String& topic, Mqtt::QOS QoS, int errorCode)
        {
            if (errorCode)
            {
                fprintf(stderr, "Subscribe failed with error %s\n", aws_error_debug_str(errorCode));
                exit(-1);
            }
            else
            {
                if (!packetId || QoS == AWS_MQTT_QOS_FAILURE)
                {
                    fprintf(stderr, "Subscribe rejected by the broker.");
                    exit(-1);
                }
                else
                {
                    fprintf(stdout, "Subscribe on topic %s on packetId %d Succeeded\n", topic.c_str(), packetId);
                }
            }
            subscribeFinishedPromise.set_value();
        };

        connection->Subscribe("sandbox_coordinator/#", AWS_MQTT_QOS_AT_LEAST_ONCE, on_message, onSubAck);
        subscribeFinishedPromise.get_future().wait();

        String input = "";
        while (input != "x")
        {
            fprintf(stdout, "Enter 'd' to see database. Enter 'x' to exit this program.\n");
            std::getline(std::cin, input);
            if (input == "d")
            {
                begin_transaction();
                dump_db();
                commit_transaction();
            }            
        }

        std::promise<void> unsubscribeFinishedPromise;
        connection->Unsubscribe(
            "#", [&](Mqtt::MqttConnection &, uint16_t, int)
            { unsubscribeFinishedPromise.set_value(); });
        unsubscribeFinishedPromise.get_future().wait();
    }

    if (connection->Disconnect())
    {
        connectionClosedPromise.get_future().wait();
    }

    gaia::system::shutdown();

    return 0;
}
