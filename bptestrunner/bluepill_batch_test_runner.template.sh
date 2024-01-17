#!/bin/bash

set -euo pipefail

basename_without_extension() {
  local full_path="$1"
  local filename
  filename=$(basename "$full_path")
  echo "${filename%.*}"
}

# Constants
TEST_BUNDLE_PATHS=(test_bundle_paths)
TEST_HOST_PATHS=(test_host_paths)
BP_WORKING_FOLDER="$TEST_TMPDIR/bp_exec_root"
BP_CONFIG_FILE="bp_config_file"
BP_TEST_ESTIMATE_JSON="bp_test_time_estimates_json"
BP_TEST_PLAN="bp_test_plan"
BP_PATH="bp_path"
BLUEPILL_PATH="bluepill_path"

# Remove existing working folder for a clean state
rm -rf $BP_WORKING_FOLDER
mkdir $BP_WORKING_FOLDER

# Extract test bundles
for test_bundle in ${TEST_BUNDLE_PATHS[@]}; do
    if [[ $test_bundle == *.zip ]]; then
        tar -C $BP_WORKING_FOLDER -xzf $test_bundle
    elif [[ $test_bundle == *.xctest ]]; then
        cp -cr $test_bundle $BP_WORKING_FOLDER
        chmod -R ug+w "$BP_WORKING_FOLDER/$(basename "$test_bundle")"
    else
        echo "$test_bundle is not a zip file or xctest bundle."
        exit 1
    fi
done

# Clone and extract test hosts
for test_host in ${TEST_HOST_PATHS[@]}; do
    if [[ "$test_host" == *.ipa ]]; then
        TEST_HOST_NAME=$(basename_without_extension "${test_host}")
        unzip -qq -d "$BP_WORKING_FOLDER" "$test_host"
        cp -cr "${BP_WORKING_FOLDER}/Payload/${TEST_HOST_NAME}.app" ${BP_WORKING_FOLDER}
    elif [[ $test_host == *.app ]]; then
        cp -cr $test_host $BP_WORKING_FOLDER
        chmod -R ug+w "$BP_WORKING_FOLDER/$(basename "$test_host")"
    else
        echo "$test_host is not an ipa file or app bundle."
        exit 1
    fi
done

# Copy config file to bp working folder
if [ -f "$BP_CONFIG_FILE" ]; then
    cp "$BP_CONFIG_FILE" $BP_WORKING_FOLDER
    CONFIG_ARG="-c $(basename "$BP_CONFIG_FILE")"
fi

# Copy time estimate file to bp working folder
TIME_ESTIMATE_ARG=""
if [ -f "$BP_TEST_ESTIMATE_JSON" ]; then
    cp "$BP_TEST_ESTIMATE_JSON" $BP_WORKING_FOLDER
    TIME_ESTIMATE_ARG="--test-time-estimates-json $(basename "$BP_TEST_ESTIMATE_JSON")"
fi

# Expand $TEST_UNDECLARED_OUTPUTS_DIR in rule-generated test plan file
# And copy it to working folder
sed 's/$TEST_UNDECLARED_OUTPUTS_DIR/'"${TEST_UNDECLARED_OUTPUTS_DIR//\//\\/}"'/g' $BP_TEST_PLAN > $BP_WORKING_FOLDER/$BP_TEST_PLAN
BP_TEST_PLAN_ARG="$(basename "$BP_TEST_PLAN")"

# Copy bluepill and bp executables to working folder
cp "$BP_PATH" $BP_WORKING_FOLDER
cp "$BLUEPILL_PATH" $BP_WORKING_FOLDER

# Run bluepill
# NOTE: we override output folder here and disregard the one in the config file.
# So we know where to grab the output files for the next step.
echo "Running ./bluepill --test-plan-path "${BP_TEST_PLAN_ARG}" -o "outputs" ${CONFIG_ARG} ${TIME_ESTIMATE_ARG}"

cd $BP_WORKING_FOLDER
RC=0

echo "Working directory: $(pwd)"
echo "Hostname: $(hostname)"

(./bluepill --test-plan-path "${BP_TEST_PLAN_ARG}" -o "outputs" ${CONFIG_ARG} ${TIME_ESTIMATE_ARG}) || RC=$?
# Move Bluepill output to bazel-testlogs
ditto "outputs" "$TEST_UNDECLARED_OUTPUTS_DIR"
rm -rf "outputs"

echo "Exit code: $RC"
exit $RC
