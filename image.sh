#!/bin/bash

# User Input
export GITHUB_REPO="f0ssel/kaniko"
export GIT_BRANCH="master"
export CODER_IMAGE="dev"

# Image YAML
export IMAGE="$(yq r .coder/images/$CODER_IMAGE.yaml 'image')"
export DOCKERFILE="$(yq r .coder/images/$CODER_IMAGE.yaml 'dockerfile')"

export TIMESTAMP="$(date +%s)"

envsubst < "image.yaml" > "output/image.yaml"

kubectl apply -f "output/image.yaml"

until kubectl logs -f kaniko-$TIMESTAMP
do
  sleep 1
done