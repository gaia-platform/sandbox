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

#include "gaia_coordinator.h"

using namespace Aws::Crt;
using namespace std;

using namespace gaia::common;
using namespace gaia::db;
using namespace gaia::db::triggers;
using namespace gaia::direct_access;
using namespace gaia::coordinator;
using namespace gaia::rules;

session_t get_session(std::string id)
{
    auto session_iter = session_t::list().where(session_t::expr::id == id).begin();
    if (session_iter == session_t::list().end())
    {
        printf("Creating new session\n");
        session_writer w;
        w.id = id;
        w.agent_id = Aws::Crt::UUID().ToString().c_str();
        w.current_project_id = "none";
        w.is_active = false;
        w.is_launching = false;
        w.keep_alive_received = false;
        w.last_active_timestamp = (uint64_t)time(nullptr);
        w.created_timestamp = (uint64_t)time(nullptr);
        return session_t::get(w.insert_row());
    }
    printf("Existing session found\n");
    return *session_iter;
}

void dump_db()
{
    printf("\n");
    begin_transaction();
    for (const auto& s : session_t::list())
    {
        printf("-----------------------------------------------------------\n");
        printf("session:         %-37s\n", s.id());
        printf("agent:           %-37s\n", s.agent_id());
        printf("current_project: %-37s\n", s.current_project_id());
    }
    printf("-----------------------------------------------------------\n");
    commit_transaction();
}

void handle_session(std::string id)
{
    begin_transaction();

    session_t session = get_session(id);

    commit_transaction();
}

void on_message(Mqtt::MqttConnection &, const String &topic, const ByteBuf &payload,
                bool /*dup*/, Mqtt::QOS /*qos*/, bool /*retain*/)
{
    std::string sub_topic = topic.substr(strlen("sandbox_coordinator/")).c_str();
    fprintf(stdout, "Message received on topic %s\n", topic.c_str());
    fprintf(stdout, "sub_topic %s\n", sub_topic.c_str());
    fprintf(stdout, "Message: ");
    fwrite(payload.buffer, 1, payload.len, stdout);
    fprintf(stdout, "\n");

    if (sub_topic == "session")
    {
        handle_session((char *)payload.buffer);
    }
}

int main()
{
    gaia::system::initialize();

    dump_db();

    ApiHandle apiHandle;

    String endpoint("a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com");
    String certificatePath("../../certs/coordinator-certificate.pem.crt");
    String keyPath("../../certs/coordinator-private.pem.key");
    String caFile("../../certs/AmazonRootCA1.pem");
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

    auto connection = mqttClient.NewConnection(clientConfig);

    if (!connection)
    {
        fprintf(stderr, "MQTT Connection Creation failed with error %s\n", ErrorDebugString(mqttClient.LastError()));
        exit(-1);
    }

    std::promise<bool> connectionCompletedPromise;
    std::promise<void> connectionClosedPromise;

    auto onConnectionCompleted = [&](Mqtt::MqttConnection &, int errorCode, Mqtt::ReturnCode returnCode, bool) {
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

    auto onResumed = [&](Mqtt::MqttConnection &, Mqtt::ReturnCode, bool) { fprintf(stdout, "Connection resumed\n"); };

    auto onDisconnect = [&](Mqtt::MqttConnection &) {
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

        connection->Subscribe("sandbox_coordinator/+", AWS_MQTT_QOS_AT_LEAST_ONCE, on_message, onSubAck);
        subscribeFinishedPromise.get_future().wait();

        while (true)
        {
            String input;
            fprintf(
                stdout,
                "Enter the message you want to publish to topic %s and press enter. Enter 'exit' to exit this "
                "program.\n",
                topic.c_str());
            std::getline(std::cin, input);

            if (input == "exit")
            {
                break;
            }

            ByteBuf payload = ByteBufFromArray((const uint8_t *)input.data(), input.length());

            auto onPublishComplete = [](Mqtt::MqttConnection &, uint16_t packetId, int errorCode) {
                if (packetId)
                {
                    fprintf(stdout, "Operation on packetId %d Succeeded\n", packetId);
                }
                else
                {
                    fprintf(stdout, "Operation failed with error %s\n", aws_error_debug_str(errorCode));
                }
            };
            connection->Publish(topic.c_str(), AWS_MQTT_QOS_AT_LEAST_ONCE, false, payload, onPublishComplete);
        }

        std::promise<void> unsubscribeFinishedPromise;
        connection->Unsubscribe(
            "#", [&](Mqtt::MqttConnection &, uint16_t, int) { unsubscribeFinishedPromise.set_value(); });
        unsubscribeFinishedPromise.get_future().wait();
    }

    if (connection->Disconnect())
    {
        connectionClosedPromise.get_future().wait();
    }

    gaia::system::shutdown();

    return 0;
}
