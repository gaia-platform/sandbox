#!/usr/bin/env bash
# TODO: remove after testing

docker run -it --mount type=bind,source="$(pwd)"/agent.js,target=/usr/src/app/agent.js gaia-sandbox-agent node agent.js
