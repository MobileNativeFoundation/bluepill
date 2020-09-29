#!/bin/bash
# Copyright 2016 LinkedIn Corporation
# Licensed under the BSD 2-Clause License (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

XCPRETTY='xcpretty --report junit'
command -v "$XCPRETTY" >/dev/null 2>&1 || {
        XCPRETTY="cat"
}

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
export BPBuildScript

mkdir -p build/

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
          xcodebuild -list -workspace Bluepill.xcworkspace
          cat result.txt
          exit 1
  }
  test -x build/Build/Products/Release/bluepill || {
          echo No bp built
          exit 1
  }
  set +o pipefail
  # package bluepill
  TAG=$(git describe --always --tags)
  DST="Bluepill-$TAG"
  mkdir -p "build/$DST/bin"
  cp build/Build/Products/Release/{bp,bluepill} "build/$DST/bin"
  ## build the man page
  mkdir -p "build/$DST/man/man1"
  /usr/bin/python scripts/man.py "build/$DST/man/man1/bluepill.1"
  # License
  cp LICENSE "build/$DST"
  # bptestrunner
  cp bptestrunner/* "build/$DST"

  (cd build && zip -qr "$DST.zip" "$DST")
  echo Release in "build/$DST.zip"
}

bluepill_build_sample_app()
{
  set -o pipefail
  xcodebuild build-for-testing \
    -workspace Bluepill.xcworkspace \
    -scheme BPSampleApp \
    -sdk iphonesimulator \
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
  mkdir -p build/reports/
  xcodebuild test \
    -workspace Bluepill.xcworkspace \
    -scheme bp-tests \
    -derivedDataPath "build/" 2>&1 | tee result.txt | $XCPRETTY | tee build/reports/instance.xml

  if ! grep '\*\* TEST SUCCEEDED \*\*' result.txt; then
    echo 'Test failed'
    cat result.txt
    exit 1
  fi
}

bluepill_runner_tests()
{
  mkdir -p build/reports/
  xcodebuild test \
    -workspace Bluepill.xcworkspace \
    -scheme bluepill-tests \
    -derivedDataPath "build/" 2>&1 | tee result.txt | $XCPRETTY | tee build/reports/runner.xml

  if ! grep '\*\* TEST SUCCEEDED \*\*' result.txt; then
    echo 'Test failed'
    cat result.txt
    exit 1
  fi
}

bluepill_verbose_tests()
{
    BPBuildScript=NO
    export BPBuildScript
    bluepill_test
}

# The simulator clean up is to workaound a Xcode10 beta5 bug(CircleCI is still using beta5)
bluepill_test()
{
  bluepill_instance_tests
  bluepill_runner_tests
}

conf=$1

if [[ $conf == *test** ]]
then
    bluepill_build_sample_app
fi

"bluepill_$conf"

exit 0
