# Copyright 2019 LinkedIn Corporation
# Licensed under the BSD 2-Clause License (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.
from __future__ import print_function

import argparse
import os
import subprocess
import sys

try:
    import importlib.resources as ir
except ImportError:
    import importlib_resources as ir


"""Script used to run bp as a testrunner for rules_apple
"""


def main():
    parser = argparse.ArgumentParser()
    args = parser.parse_args()
    print("These are my args:")
    print(sys.argv)
    print("This is my env:")
    print(os.environ)
    print("I am bluepill")
    run_bp(None)


def run_bp(config_file):
    # total hack
    with ir.path('__main__/bp', 'bp') as bp_path:
        os.chmod(bp_path, 0o755)
        cmd = [bp_path]
        if config_file:
            cmd += ['-c', config_file]
        subprocess.check_call(cmd)


if __name__ == '__main__':
    main()
