# Docker Agent Readme

- AGENT_ID is the ID associate with the agent
- IMAGE_NAME is the name of the image.  The docker_build.sh script currently
  builds an image named `agent`
- INTERACTIVE_MODE can be set to `/bin/bash` to create a container and execute
  bash within it

```bash
AGENT_ID=fred
IMAGE_NAME=agent
INTERACTIVE_MODE=
docker run --rm -it -e AGENT_ID=$AGENT_ID $IMAGE_NAME $INTERACTIVE_MODE
```
