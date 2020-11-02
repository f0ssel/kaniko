#!/bin/bash

# User Input
export GITHUB_REPO=f0ssel/kaniko
export GIT_BRANCH=master
export ENVIRONMENT_TEMPLATE=dev

echo "--- Creating environment with template '$ENVIRONMENT_TEMPLATE' from github.com/$GITHUB_REPO with branch $GIT_BRANCH"

# Script
YAML_FILES="$(find .coder/ -name "*.yaml" -not -path ".coder/tmp*")"
while read i; do
  if [ "$(yq r "$i" type)" == "environment" ] && [ "$(yq r "$i" name)" == "$ENVIRONMENT_TEMPLATE" ]; then
    TEMPLATE_FILE="$i"
    break
  fi
done <<< "$YAML_FILES"

echo "--- Found '$ENVIRONMENT_TEMPLATE' manifest at $TEMPLATE_FILE"

export IMAGE="$(yq r $TEMPLATE_FILE 'spec.[0].image')"
export TAG="$(yq r $TEMPLATE_FILE 'spec.[0].tag')"
PERSONALIZE="$(yq r $TEMPLATE_FILE 'spec.[0].personalize.*')"

echo -e $"FROM $IMAGE:$TAG\n$PERSONALIZE" > output/environment-image.Dockerfile
export DOCKERFILE_DATA="$(cat output/environment-image.Dockerfile)"

export TIMESTAMP="$(date +%s)"

envsubst < "templates/environment.yaml" > "output/environment.yaml"

echo "--- Creating environment pod"
kubectl apply -f "output/environment.yaml"

echo "--- Streaming logs from setup container"
until kubectl logs -f environment-$TIMESTAMP -c setup 2>/dev/null
do
  sleep 1 2>/dev/null
done
echo "--- Streaming logs from kaniko builder container"
until kubectl logs -f environment-$TIMESTAMP -c kaniko 2>/dev/null
do
  sleep 1 2>/dev/null
done
echo "--- Streaming logs from environment container"
until kubectl logs environment-$TIMESTAMP -c environment 2>/dev/null
do
  sleep 1 2>/dev/null
done

echo "--- Creating shell from environment container"
kubectl exec -it environment-$TIMESTAMP -c environment -- bash