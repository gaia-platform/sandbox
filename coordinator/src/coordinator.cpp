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
// #include "enums.hpp"

using json = nlohmann::json;
using namespace Aws::Crt;
using namespace std;

using namespace gaia::common;
using namespace gaia::db;
using namespace gaia::db::triggers;
using namespace gaia::direct_access;
using namespace gaia::coordinator;
using namespace gaia::rules;

// using namespace enums;

std::shared_ptr<Aws::Crt::Mqtt::MqttConnection> connection;

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
        printf("session:            %s\n", s.session_id());
        printf("agent:              %s\n", s.agent_id());
        printf("is_active:          %s\n", s.is_active() ? "YES" : "NO");
        printf("current_project_name: %s\n", s.current_project_name());
        printf("last_session_timestamp: %lu\n", s.last_session_timestamp());
        printf("last_agent_timestamp: %lu\n", s.last_agent_timestamp());
        printf("created_timestamp: %lu\n", s.created_timestamp());
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
}

session_t get_session(const string& id)
{
    auto session_iter = session_t::list()
                            .where(session_t::expr::session_id == id || session_t::expr::agent_id == id)
                            .begin();
    if (session_iter == session_t::list().end())
    {
        gaia_log::app().info("Creating new session");
        session_writer w;
        w.session_id = id;
        w.agent_id = "NONE";
        w.is_active = false;
        w.last_session_timestamp = (uint64_t)time(nullptr);
        w.last_agent_timestamp = (uint64_t)time(nullptr);
        w.created_timestamp = (uint64_t)time(nullptr);
        return session_t::get(w.insert_row());
    }
    gaia_log::app().info("Existing session found");
    return *session_iter;
}

browser_activity_t browser_activity()
{
    browser_activity_writer w;
    w.timestamp = (uint64_t)time(nullptr);
    return browser_activity_t::get(w.insert_row());
}

agent_activity_t agent_activity(const string& agent_id)
{
    agent_activity_writer w;
    w.agent_id = agent_id;
    w.timestamp = (uint64_t)time(nullptr);
    return agent_activity_t::get(w.insert_row());
}

project_activity_t project_activity(const string& name)
{
    project_activity_writer w;
    w.name = name;
    w.timestamp = (uint64_t)time(nullptr);
    return project_activity_t::get(w.insert_row());
}

editor_file_request_t editor_file_request(const string& name)
{
    editor_file_request_writer w;
    w.name = name;
    w.timestamp = (uint64_t)time(nullptr);
    return editor_file_request_t::get(w.insert_row());
}

editor_file_content_t editor_file_content(const string& name, const string& content)
{
    editor_file_content_writer w;
    w.name = name;
    w.content = content;
    w.timestamp = (uint64_t)time(nullptr);
    return editor_file_content_t::get(w.insert_row());
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
    gaia_log::app().info("Message received on topic {}", topic.c_str());
    gaia_log::app().info("Message:");
    fwrite(payload.buffer, 1, payload.len, stdout);
    printf("\n");

    if (topic_vector.size() < 3)
    {
        gaia_log::app().error("Unexpected topic");
        return;
    }

    begin_transaction();

    session_t session = get_session(topic_vector[1]);

    if (topic_vector[2] == "browser")
    {
        auto activity = browser_activity();
        session.browser_activities().insert(activity);
    }
    else if (topic_vector[2] == "agent")
    {
        auto activity = agent_activity(topic_vector[1]);
        session.agent_activities().insert(activity);
    }
    else if (topic_vector[2] == "project")
    {
        auto activity = project_activity(topic_vector[3] == "exit"
                                        ? "exit" : (char *)payload.buffer);
        session.project_activities().insert(activity);
    }
    else if (topic_vector[2] == "editor")
    {
        auto activity = editor_file_request((char *)payload.buffer);
        session.editor_file_requests().insert(activity);
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
            [&](Mqtt::MqttConnection &, uint16_t packetId, const String &topic, Mqtt::QOS QoS, int errorCode)
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

        String input;
        fprintf(stdout, "Enter enter to exit this program.\n");
        std::getline(std::cin, input);

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
