# Base Image
FROM ubuntu:20.04

# Set any environment
ENV NODE_ENV=production
WORKDIR /usr/src/app

# APT Update to get current locations.
RUN apt update -y
RUN apt upgrade -y

# Clang and Cmake Install.
RUN apt install -y cmake clang nano openssl

# NPM Install
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN DEBIAN_FRONTEND="noninteractive" apt-get --assume-yes install tzdata
RUN apt --assume-yes install nodejs npm
RUN npm install --production --silent && mv node_modules ../

# Gaia Install
COPY gaia.deb /usr/src/app/gaia.deb
RUN apt --assume-yes install /usr/src/app/gaia.deb

# Make sure we are not running as root.
RUN groupadd -g 999 appuser && \
    useradd -r -u 999 -g appuser appuser
USER appuser

# Copy all directory files into the image.
COPY --chown=appuser:appuser . .

# Expost port 3000 for communication.
EXPOSE 3000

# Unless overridden, this is the command line that will be executed
# when the container is run.
CMD ["node", "agent.js"]
