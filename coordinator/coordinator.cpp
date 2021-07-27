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

gaia_id_t insert_gaia_client()
{
    gaia_client_writer w;
    w.id = Aws::Crt::UUID().ToString().c_str();
    w.is_active = false;
    w.activity_timestamp = (uint64_t)time(nullptr);
    return w.insert_row();
}

void dump_db()
{
    printf("\n");
    begin_transaction();
    for (auto i : gaia_client_t::list())
    {
        printf("---------------------------------------------------------------------\n");
        printf("client: %-37s|active: %-3s|last_active: %lu\n", i.id(), i.is_active() ? "YES" : "NO", i.activity_timestamp());

        for (const auto& s : i.session_list())
        {
            printf("    session: %-37s|project: %-25s\n", s.id(), s.current_project().name());
        }

        printf("\n");
        printf("\n");
    }
    commit_transaction();
}

void on_message(Mqtt::MqttConnection &, const String &topic, const ByteBuf &payload,
                bool /*dup*/, Mqtt::QOS /*qos*/, bool /*retain*/)
{
    fprintf(stdout, "Publish received on topic %s\n", topic.c_str());
    fprintf(stdout, "\n Message:\n");
    fwrite(payload.buffer, 1, payload.len, stdout);
    fprintf(stdout, "\n");
}

int main()
{
    gaia::system::initialize();

    /*
        begin_transaction();
        insert_gaia_client();
        commit_transaction();
    */

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
                connectionCompletedPromise.set_value(true);
            }
        }
    };

    auto onInterrupted = [&](Mqtt::MqttConnection &, int error) {
        fprintf(stdout, "Connection interrupted with error %s\n", ErrorDebugString(error));
    };

    auto onResumed = [&](Mqtt::MqttConnection &, Mqtt::ReturnCode, bool) { fprintf(stdout, "Connection resumed\n"); };

    auto onDisconnect = [&](Mqtt::MqttConnection &) {
        {
            fprintf(stdout, "Disconnect completed\n");
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
            [&](Mqtt::MqttConnection &, uint16_t packetId, const String &topic, Mqtt::QOS QoS, int errorCode) {
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

        connection->Subscribe("#", AWS_MQTT_QOS_AT_LEAST_ONCE, on_message, onSubAck);
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
