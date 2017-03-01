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

configurations="build test instance_tests runner_tests integration_tests verbose_tests"

if [ "$1" == "-v" ]
then
    VERBOSE=1
    shift
fi

if [[ $# -ne 1 ]]; then
  echo "$0: usage: bluepill.sh <command>"
  echo "Where <command> is one of: " $configurations
  exit 1
fi

found=0

for conf in $configurations
do
        if [ "$1" = "$conf" ];
        then
            found=1
            break
        fi
done

if [ "$found" -ne 1 ];
then
    echo "Invalid configuration"
    echo "Must be one of: " $configurations
    exit 1
fi


rm -rf build/
#set -ex

NSUnbufferedIO=YES
export NSUnbufferedIO

# If BPBuildScript is set to YES, it will disable verbose output in `bp`
BPBuildScript=YES

# Set it to YES if we're on Travis
if [ "$TRAVIS" == "true" ] || [ "$VERBOSE" == "1" ]
then
    BPBuildScript=NO
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
    -derivedDataPath "build/" | tee results.txt | $XCPRETTY

  test $? == 0 || {
          echo Build failed
          cat results.txt
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
    -derivedDataPath "build/" | tee result.txt | $XCPRETTY
  
  test $? == 0 || {
          echo Build failed
          cat results.txt
          exit 1
  }
  set +o pipefail
}

bluepill_instance_tests()
{
  xcodebuild test \
    -workspace Bluepill.xcworkspace \
    -scheme BPInstanceTests \
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
    echo See results.txt for details
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
  bluepill_instance_tests
  bluepill_runner_tests
  bluepill_build
}


if [[ $conf == *test** ]]
then
    bluepill_build_sample_app
fi

bluepill_$conf

exit 0
