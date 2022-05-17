#!/usr/bin/env bash

set -eo pipefail

# Set AWS and TF CLI to latest supported versions if not specified
[[ -n $1 ]] && AWS_VERSION=$1 || AWS_VERSION=$(jq -r '.awscli_version | sort | .[-1]' supported_versions.json)
[[ -n $2 ]] && TF_VERSION=$2 || TF_VERSION=$(jq -r '.tf_version | sort | .[-1]' supported_versions.json)

IMAGE_NAME="terraform-aws-cli"
IMAGE_TAG="dev"

# Build image
echo "Building images with AWS_CLI_VERSION=${AWS_VERSION} and TERRAFORM_VERSION=${TF_VERSION}..."
docker image build --build-arg AWS_CLI_VERSION="$AWS_VERSION" --build-arg TERRAFORM_VERSION="${TF_VERSION}" -t ${IMAGE_NAME}:${IMAGE_TAG} .
echo "Image successfully builded!"

# cleanup
unset AWS_VERSION
unset TF_VERSION
