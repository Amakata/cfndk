#!/bin/bash

WORK_DIR=`pwd`

docker run \
  -v $WORK_DIR:/home/cfndk \
  -v $HOME/.aws:/root/.aws \
  -e AWS_PROFILE=$AWS_PROFILE \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
  -w /home/cfndk \
  -it amakata/cfndk:latest \
  "$@"