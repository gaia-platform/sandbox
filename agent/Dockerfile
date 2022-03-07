# Base Image
FROM ubuntu:20.04
ARG GAIA_SDK_FILE

# Set any environment
ENV NODE_ENV=production
ENV CC=/usr/bin/clang-10
ENV CXX=/usr/bin/clang++-10
ENV CPP=/usr/bin/clang-cpp-10

WORKDIR /usr/src/app

# APT Update to get current locations.
RUN apt-get update --assume-yes
RUN apt-get upgrade --assume-yes

RUN DEBIAN_FRONTEND="noninteractive" apt-get install --assume-yes \
  clang-10 \
  gpg \
  wget \
  nodejs \
  npm \
  awscli \
  jq \
  nano \
  tzdata \
  git \
  debconf

# The default Ubuntu's Cmake version is not compatible with Gaia.
# We need to install a specific version.
RUN apt-get purge --auto-remove cmake
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null
RUN apt-get update
RUN apt-get install --assume-yes cmake

# NPM is a pre-requisite for the agent.
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN npm install --production --silent && mv node_modules ../

RUN echo "debconf debconf/frontend select noninteractive" | debconf-set-selections

# Gaia Install
COPY ${GAIA_SDK_FILE} /usr/src/app/gaia.deb
RUN apt-get --assume-yes install /usr/src/app/gaia.deb

# AWS IoT SDK Install
# disable temporarily while only supporting frequent flyer
#RUN git clone --recursive --branch v1.14.2 https://github.com/aws/aws-iot-device-sdk-cpp-v2.git \
#    && cd aws-iot-device-sdk-cpp-v2 \
#    && mkdir aws-iot-device-sdk-cpp-v2-build \
#    && cd aws-iot-device-sdk-cpp-v2-build \
#    && cmake -DCMAKE_BUILD_TYPE="Release" .. \
#    && cmake --build . --target install -- -j$(nproc)

# Make sure we are not running as root.
#RUN groupadd -g 999 appuser && \
#    useradd -r -u 999 -g appuser appuser
#USER appuser

# Copy all directory files into the image.
#COPY --chown=appuser:appuser . .
COPY . .

# Expost port 3000 for communication.
EXPOSE 3000

# Unless overridden, this is the command line that will be executed
# when the container is run.
CMD ["node", "agent.js"]
