# Base Image
FROM ubuntu:20.04

# Set any environment
ENV NODE_ENV=production
WORKDIR /usr/src/app

# APT Update to get current locations.
RUN apt update --assume-yes
RUN apt upgrade --assume-yes

# Clang is a pre-requisites for compiling with Gaia...
RUN apt install --assume-yes clang

# ... so is CMake, though a bit more involved.
RUN apt purge --auto-remove cmake
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install gpg wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null
RUN apt update
RUN apt install --assume-yes cmake

# NPM is a pre-requisite for the agent.
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN DEBIAN_FRONTEND="noninteractive" apt-get --assume-yes install tzdata
RUN apt --assume-yes install nodejs npm
RUN npm install --production --silent && mv node_modules ../

# Aws and Jq are pre-requisites for building the Gaia application.
RUN apt install --assume-yes awscli jq

RUN apt install --assume-yes nano

# Gaia Install
COPY gaia.deb /usr/src/app/gaia.deb
RUN apt --assume-yes install /usr/src/app/gaia.deb

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
