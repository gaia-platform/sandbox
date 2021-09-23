# Gaia Sandbox Coordinator
A Gaia application to coordinate launching of and interacting with containerized Gaia template applications launched through AWS ECS and communicating using MQTT.

# Sandbox Coordinator development setup
## Prerequisites
You'll need to

* Install Gaia
* Install aws-iot-device-sdk-cpp

### Installing Gaia
Follow instructions [here](https://gaia-platform.github.io/gaia-platform-docs.io/articles/getting-started-with-gaia.html) to install Gaia.

### Installing aws-iot-device-sdk-cpp
From inside the root sandbox directory clone the [aws-iot-device-sdk-cpp](https://github.com/aws/aws-iot-device-sdk-cpp-v2) and build using clang. May also work with gcc but so far only tested with clang.
```bash
export CC=/usr/bin/clang-10
export CPP=/usr/bin/clang-cpp-10
export CXX=/usr/bin/clang++-10
export LDFLAGS=-fuse-ld=lld-10
cd {coordinator_directory}
git clone --recursive https://github.com/aws/aws-iot-device-sdk-cpp-v2.git
cd aws-iot-device-sdk-cpp-v2
mkdir build
cd build
cmake ..
make
sudo make install
```

## Build Sandbox Coordinator
Create build directory within coordinator directory, run cmake and then make.
```bash
cd {coordinator_directory}
mkdir build
cd build
cmake ..
make
```

## Install AWS IoT certificates
* Go [here](https://us-west-2.console.aws.amazon.com/iot/home?region=us-west-2#/thing/sandbox_coordinator) to create a certificate for the sandbox_coordinator thing and attach the certificate to the [SandboxCoordinator Policy](arn:aws:iot:us-west-2:794670594658:policy/SandboxCoordinator).
* Download the new certificate, private key, and Amazon root CA1 certificate.
* Create a new folder named certs in your coordinator directory and copy the downloaded files there.
* Rename the certificate and private key respectively to: coordinator-certificate.pem.crt and coordinator-private.pem.key
* Leave the Amazon root certificate name unchanged, namely: AmazonRootCA1.pem
