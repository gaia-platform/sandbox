#!/bin/bash

# Push the gaia-sandobox-agent image into the AWS ECR (container repository).
# Before calling this script:
# - Build the latest version of the image using the docker_build.sh script
# - Have the gaia-sandbox credentials stored into your ~/.aws/credentials file.

export AWS_PROFILE="gaia-sandbox"
export AWS_DEFAULT_REGION="us-west-2"

GAIA_ECR_REPO="gaia-sandbox"
GAIA_DOCKER_IMAGE="gaia-sandobox-agent"

GAIA_SANDBOX_REPO_URI=`aws ecr describe-repositories --repository-names $GAIA_ECR_REPO \
                                                     --query "repositories[0].repositoryUri" \
                                                     --output text`

if [ $? == 0 ]; then
    echo "$GAIA_ECR_REPO ECR repository found: $GAIA_SANDBOX_REPO_URI"
else
    echo "$GAIA_ECR_REPO ECR repository not found! Creating..."
    aws ecr create-repository --repository-name $GAIA_ECR_REPO

    GAIA_SANDBOX_REPO_URI=`aws ecr describe-repositories --repository-names $GAIA_ECR_REPO \
                                                         --query "repositories[0].repositoryUri" \
                                                         --output text`
fi


GAIA_ECR_USER=${GAIA_SANDBOX_REPO_URI%/*}
aws ecr get-login-password | docker login --username AWS --password-stdin $GAIA_ECR_USER

docker tag "$GAIA_DOCKER_IMAGE:latest" "$GAIA_SANDBOX_REPO_URI:latest"
docker push "$GAIA_SANDBOX_REPO_URI:latest"
