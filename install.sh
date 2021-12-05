#!/bin/sh

apk update \
 && apk upgrade \
 && apk add git github-cli
