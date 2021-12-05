#!/bin/bash

WORKDIR=$PWD
TEST_REPO=${2:-"loft-sh/action-repo-sync"}
SOURCE_REPO_DIR=$(mktemp -d)

export INPUT_GITHUB_TOKEN=${1}
export INPUT_TARGET_REPO=$TEST_REPO
export INPUT_PATH_MAPPING="test/*:test-target-folder/;current_time"
export INPUT_PR_SOURCE_BRANCH="test-pr"

git clone "https://${INPUT_GITHUB_TOKEN}@github.com/${TEST_REPO}.git" "$SOURCE_REPO_DIR"
cd "$SOURCE_REPO_DIR"

mkdir ./test
date +%s >./test/current_time
date +%s >./current_time

$WORKDIR/run.sh
