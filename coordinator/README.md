# Gaia Sandbox Coordinator
A Gaia application to coordinate launching of and interacting with containerized Gaia template applications launched through AWS ECS and communicating using MQTT.
# Sandbox Coordinator development setup
## Prerequisites
You'll need to

* Install March release of Gaia (UNDONE: Port to Preview release)
* Install aws-iot-device-sdk-cpp

### Installing Gaia
Follow instructions [here](https://gaia-platform.github.io/gaia-platform-docs.io/articles/getting-started-with-gaia.html) to install Gaia March release.

### Installing aws-iot-device-sdk-cpp
From inside the root sandbox directory clone the [aws-iot-device-sdk-cpp](https://github.com/aws/aws-iot-device-sdk-cpp-v2) and build using clang. May also work with gcc but so far only tested with clang.
```bash
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
cd {where_you_cloned_the_sandbox_repo}
git clone --recursive https://github.com/aws/aws-iot-device-sdk-cpp-v2.git
mkdir aws-iot-device-sdk-cpp-v2-build
cd aws-iot-device-sdk-cpp-v2-build
cmake -DCMAKE_CXX_FLAGS="-stdlib=libc++" -DCMAKE_INSTALL_PREFIX="<absolute path to where_you_cloned_the_sandbox_repo>" ../aws-iot-device-sdk-cpp-v2
cmake --build . --target install
```

## Build Sandbox Coordinator
Create build directory within coordinator directory, run cmake and then make.
```bash
cd {where_you_cloned_the_sandbox_repo}/coordinator
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX="<absolute path to where_you_cloned_the_sandbox_repo>" ..
make
```

## Install AWS IoT certificates
* Go [here](https://us-west-2.console.aws.amazon.com/iot/home?region=us-west-2#/thing/sandbox_coordinator) to create a certificate for the sandbox_coordinator thing and attach the certificate to the [SandboxCoordinator Policy](arn:aws:iot:us-west-2:794670594658:policy/SandboxCoordinator).
* Download the new certificate, private key, and Amazon root CA1 certificate.
* Create a new folder named certs in your sandbox repo directory and copy the downloaded files there.
* Rename the certificate and private key respectively to: coordinator-certificate.pem.crt and coordinator-private.pem.key
* Leave the Amazon root certificate name unchanged, namely: AmazonRootCA1.pem

