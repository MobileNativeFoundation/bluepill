#!/bin/bash

set -eo pipefail

basename_without_extension() {
  local full_path="$1"
  local filename
  filename=$(basename "$full_path")
  echo "${filename%.*}"
}

# Constants
TEST_BUNDLE_PATHS=(test_bundle_paths)
TEST_HOST_PATHS=(test_host_paths)
BP_WORKING_FOLDER="bp_exec_root"
BP_CONFIG_FILE="bp_config_file"
BP_TEST_ESTIMATE_JSON="bp_test_time_estimates_json"
BP_TEST_PLAN="bp_test_plan"
BP_PATH="bp_path"
BLUEPILL_PATH="bluepill_path"
TARGET_NAME="target_name"

# Setup working folder
if [ -d $BP_WORKING_FOLDER ]; then
    rm -rf $BP_WORKING_FOLDER || true
fi
mkdir $BP_WORKING_FOLDER

# Extract test bundles
for test_bundle in ${TEST_BUNDLE_PATHS[@]}; do
    if [[ $test_bundle == *.zip ]]; then
        tar -C $BP_WORKING_FOLDER -xzf $test_bundle
    else
        echo "$test_bundle is not a zip file."
        exit 1
    fi
done

# Clone and extract test hosts
for test_host in ${TEST_HOST_PATHS[@]}; do
    if [[ "$test_host" == *.ipa ]]; then
        TEST_HOST_NAME=$(basename_without_extension "${test_host}")
        unzip -qq -d "$BP_WORKING_FOLDER" "$test_host"
        cp -cr "${BP_WORKING_FOLDER}/Payload/${TEST_HOST_NAME}.app" ${BP_WORKING_FOLDER}
    else
        echo "$test_host is not an ipa file"
    fi
done

# Copy config file to bp working folder
if [ -f "$BP_CONFIG_FILE" ]; then
    cp -L "$BP_CONFIG_FILE" $BP_WORKING_FOLDER
    CONFIG_ARG="-c $(basename "$BP_CONFIG_FILE")"
fi
# Copy time estimate file to bp working folder
if [ -f "$BP_TEST_ESTIMATE_JSON" ]; then
    cp -L "$BP_TEST_ESTIMATE_JSON" $BP_WORKING_FOLDER
    TIME_ESTIMATE_ARG="--test-time-estimates-json $(basename "$BP_TEST_ESTIMATE_JSON")"
fi

#  Copy bluepill, bp executable and the rule generated test plan file to working folder
cp -L "$BP_TEST_PLAN" $BP_WORKING_FOLDER
cp -L "$BP_PATH" $BP_WORKING_FOLDER
cp -L "$BLUEPILL_PATH" $BP_WORKING_FOLDER

# Run bluepill
# NOTE: we override output folder here and disregard the one in the config file.
# So we know where to grab the output files for the next step.
echo "Running ./bluepill --test-plan-path "${BP_TEST_PLAN}" -o "outputs" ${CONFIG_ARG} ${TIME_ESTIMATE_ARG}"
(cd $BP_WORKING_FOLDER; ./bluepill --test-plan-path "${BP_TEST_PLAN}" -o "outputs" ${CONFIG_ARG} ${TIME_ESTIMATE_ARG})

# Copy Bluepill output to bazel-testlogs
cp -cr "$BP_WORKING_FOLDER/outputs" "../../../testlogs/$TARGET_NAME/test.outputs/"

status=$?
exit ${status}
