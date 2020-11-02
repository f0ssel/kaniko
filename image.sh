#!/bin/bash

# User Input
export GITHUB_REPO="f0ssel/kaniko"
export GIT_BRANCH="master"
export IMAGE_NAME="f0ssel/kaniko"

echo "--- Creating $IMAGE_NAME from github.com/$GITHUB_REPO with branch $GIT_BRANCH"

# Script
YAML_FILES="$(find .coder/ -name "*.yaml" -not -path ".coder/tmp*")"
while read i; do
  if [ "$(yq r "$i" type)" == "image" ] && [ "$(yq r "$i" name)" == "$IMAGE_NAME" ]; then
    TEMPLATE_FILE="$i"
    break
  fi
done <<< "$YAML_FILES"

echo "--- Found $IMAGE_NAME manifest at $TEMPLATE_FILE"

## Image YAML
export DOCKERFILE="$(yq r "$TEMPLATE_FILE" 'dockerfile')"
export TIMESTAMP="$(date +%s)"
export IMAGE="$(yq r "$TEMPLATE_FILE" 'name')"
envsubst < "templates/image.yaml" > "output/image.yaml"

echo "--- Creating kaniko builder pod"
kubectl apply -f "output/image.yaml"

echo "--- Streaming logs from kaniko builder"
until kubectl logs -f kaniko-$TIMESTAMP 2>/dev/null
do
  sleep 1 2>/dev/null
done

echo "--- Pushed image $IMAGE:$GIT_BRANCH"