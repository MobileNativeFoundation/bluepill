#!/bin/bash

set -eo pipefail

## set -x

basename_without_extension() {
  local full_path="$1"
  local filename
  filename=$(basename "$full_path")
  echo "${filename%.*}"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test_runner_work_dir.XXXXXX")"

TEST_BUNDLE_PATH="%(test_bundle_path)s"

if [[ "$TEST_BUNDLE_PATH" == *.xctest ]]; then
  runner_flags+=("--test_bundle_path=${TEST_BUNDLE_PATH}")
else
  TEST_BUNDLE_NAME=$(basename_without_extension "${TEST_BUNDLE_PATH}")
  TEST_BUNDLE_TMP_DIR="${TMP_DIR}/${TEST_BUNDLE_NAME}"
  unzip -qq -d "${TEST_BUNDLE_TMP_DIR}" "${TEST_BUNDLE_PATH}"
  runner_flags+=("--test-bundle-path=${TEST_BUNDLE_TMP_DIR}/${TEST_BUNDLE_NAME}.xctest")
fi

TEST_HOST_PATH="%(test_host_path)s"

if [[ -n "$TEST_HOST_PATH" ]]; then
  if [[ "$TEST_HOST_PATH" == *.app ]]; then
    runner_flags+=("--app_under_test_path=$TEST_HOST_PATH")
  else
    TEST_HOST_NAME=$(basename_without_extension "${TEST_HOST_PATH}")
    TEST_HOST_TMP_DIR="${TMP_DIR}/${TEST_HOST_NAME}"
    unzip -qq -d "${TEST_HOST_TMP_DIR}" "${TEST_HOST_PATH}"
    runner_flags+=("--app=${TEST_HOST_TMP_DIR}/Payload/${TEST_HOST_NAME}.app")
  fi
fi

# Constructs the json string to configure the test env and tests to run.
# It will be written into a temp json file which is passed to the test runner
# flags --config.
CONFIG_FILE_JSON_STR=""

CONFIG_FILE_JSON_STR+="\"device\":\"%(device)s\","
CONFIG_FILE_JSON_STR+="\"runtime\":\"%(runtime)s\","
CONFIG_FILE_JSON_STR+="\"headless\":%(headless)s,"
CONFIG_FILE_JSON_STR+="\"num-sims\":%(num_sims)s,"
CONFIG_FILE_JSON_STR+="\"clone-simulator\":%(clone_simulator)s"


TEST_ENV="%(test_env)s"
if [[ -n "${TEST_ENV}" ]]; then
  # Converts the test env string to json format and adds it into launch
  # options string.
  TEST_ENV=${TEST_ENV//=/\":\"}
  TEST_ENV=${TEST_ENV//,/\",\"}
  TEST_ENV="{\"${TEST_ENV}\"}"
  CONFIG_FILE_JSON_STR+=","
  CONFIG_FILE_JSON_STR+="\"environmentVariables\":${TEST_ENV}"
fi

# Use the TESTBRIDGE_TEST_ONLY environment variable set by Bazel's --test_filter
# flag to set tests_to_run value in ios_test_runner's launch_options.
if [[ -n "$TESTBRIDGE_TEST_ONLY" ]]; then
  CONFIG_FILE_JSON_STR+=","
  CONFIG_FILE_JSON_STR+="\"include\":[\"$TESTBRIDGE_TEST_ONLY\"]"
fi

if [[ -n "${CONFIG_FILE_JSON_STR}" ]]; then
  CONFIG_FILE_JSON_STR="{${CONFIG_FILE_JSON_STR}}"
  CONFIG_FILE_JSON_PATH="${TMP_DIR}/config.json"
  echo "${CONFIG_FILE_JSON_STR}" > "${CONFIG_FILE_JSON_PATH}"
  runner_flags+=("-c" "${CONFIG_FILE_JSON_PATH}")
fi

cmd=("%(testrunner_binary)s"
  "${runner_flags[@]}"
  "$@")

"${cmd[@]}" 2>&1
status=$?
exit ${status}
