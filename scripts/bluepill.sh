# //  Copyright 2016 LinkedIn Corporation
# //  Licensed under the BSD 2-Clause License (the "License");
# //  you may not use this file except in compliance with the License.
# //  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
# //
# //  Unless required by applicable law or agreed to in writing, software
# //  distributed under the License is distributed on an "AS IS" BASIS,
# //  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#!/bin/bash

XCPRETTY=xcpretty
command -v $XCPRETTY >/dev/null 2>&1 || {
        XCPRETTY=cat
}

if [ "$1" == "-v" ]
then
    VERBOSE=1
    shift
fi

if [[ $# -ne 1 ]]; then
  echo "$0: usage: bluepill.sh <command>"
  exit 1
fi

rm -rf build/
#set -ex

NSUnbufferedIO=YES
export NSUnbufferedIO

# If BPBuildScript is set to YES, it will disable verbose output in `bp`
BPBuildScript=YES

# Set it to NO if we're on Travis
# Also turn off XCPRETTY
if [ "$TRAVIS" == "true" ] || [ "$VERBOSE" == "1" ]
then
    BPBuildScript=NO
    XCPRETTY=cat
fi

export BPBuildScript

mkdir -p build/

test_runtime()
{
  # Test that we have a valid runtime.

  default_runtime=`grep BP_DEFAULT_RUNTIME ./Source/Shared/BPConstants.h | sed 's/.*BP_DEFAULT_RUNTIME *//;s/"//g;s/ *$//g;'`
  xcrun simctl list runtimes | grep -q "$default_runtime" || {
    echo "Your system doesn't contain latest runtime: iOS $default_runtime"
    exit -1
  }
}

bluepill_build()
{
  set -o pipefail
  xcodebuild \
    -workspace Bluepill.xcworkspace \
    -scheme bluepill \
    -configuration Release \
    -derivedDataPath "build/" | tee result.txt | $XCPRETTY

  test $? == 0 || {
          echo Build failed
          cat result.txt
          exit 1
  }
  test -x build/Build/Products/Release/bluepill || {
          echo No bp built
          exit 1
  }
  set +o pipefail
}

bluepill_build_sample_app()
{
  set -o pipefail
  xcodebuild build-for-testing \
    -workspace Bluepill.xcworkspace \
    -scheme BPSampleApp \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.1' \
    -derivedDataPath "build/" 2>&1 | tee result.txt | $XCPRETTY

  test $? == 0 || {
          echo Build failed
          cat result.txt
          exit 1
  }
  set +o pipefail
}

bluepill_instance_tests()
{
  n=$1
  xcodebuild test \
    -workspace Bluepill.xcworkspace \
    -scheme BPInstanceTests$n \
    -derivedDataPath "build/" 2>&1 | tee result.txt | $XCPRETTY

  if ! grep '\*\* TEST SUCCEEDED \*\*' result.txt; then
    echo 'Test failed'
    echo Dumping result.txt for details
    cat result.txt
    exit 1
  fi
}

bluepill_runner_tests()
{
  xcodebuild test \
    -workspace Bluepill.xcworkspace \
    -scheme BluepillRunnerTests \
    -derivedDataPath "build/" 2>&1 | tee result.txt | $XCPRETTY

  if ! grep '\*\* TEST SUCCEEDED \*\*' result.txt; then
    echo 'Test failed'
    echo Dumping result.txt for details
    cat result.txt
    exit 1
  fi
}

bluepill_integration_tests()
{
  xcodebuild test \
    -workspace Bluepill.xcworkspace \
    -scheme BluepillIntegrationTests \
    -derivedDataPath "build/" 2>&1 | tee result.txt

  if ! grep '\*\* TEST SUCCEEDED \*\*' result.txt; then
    echo 'Test failed'
    echo See result.txt for details
    cat results.txt
    exit 1
  fi
}

bluepill_verbose_tests()
{
    BPBuildScript=NO
    export BPBuildScript
    bluepill_test
}

bluepill_test()
{
  bluepill_instance_tests 1
  bluepill_instance_tests 2
  bluepill_instance_tests 3
  bluepill_runner_tests
  bluepill_build
}

conf=$1

if [[ $conf == *test** ]]
then
    bluepill_build_sample_app
fi

if [[ $conf == *instance_tests* ]]
then
    n=`printf $conf | tail -c 1`
    conf=${conf%?}
    bluepill_$conf $n
else
    bluepill_$conf
fi


exit 0
