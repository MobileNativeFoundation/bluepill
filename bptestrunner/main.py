# Copyright 2019 LinkedIn Corporation
# Licensed under the BSD 2-Clause License (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.
from __future__ import print_function

import glob
import logging
import os
import pkg_resources
import shutil
import subprocess
import sys
import tempfile


"""Script used to run bp as a testrunner for rules_apple
"""


def main():
    """Parse the arguments in an xctestrunner-compatible way
    """
    args = sys.argv[1:]
    if '-v' in args:
        logging.basicConfig(level=logging.DEBUG,
                            format='%(asctime)s %(message)s')
    else:
        logging.basicConfig(format='%(asctime)s %(message)s')

    logging.debug("PWD: '%s'", os.getcwd())
    # Add xcode path to CLI
    args += ['--xcode-path', find_xcode_path()]
    output_dir = os.environ['TEST_UNDECLARED_OUTPUTS_DIR']
    args += ['--output-dir', output_dir]

    logging.debug("Running: bluepill %s", ' '.join(args))
    rc = run('bluepill', args)
    pattern = os.path.join(output_dir, '*.xml')
    xml_files = glob.glob(pattern)
    final_xml_output = None
    for xml_file in xml_files:
        if xml_file.find('FINAL'):
            final_xml_output = xml_file
            break
    if final_xml_output:
        xml_output_path = os.environ['XML_OUTPUT_FILE']
        shutil.copy(final_xml_output, xml_output_path)
    sys.exit(rc)


def find_xcode_path():
    """Return the path to Xcode's Developer directory.
    """
    simctl_path = subprocess.check_output(['xcrun', '--find', 'simctl'])
    xcode_path = simctl_path.replace('/usr/bin/simctl', '')
    return xcode_path.rstrip()


def run(tool, args=[]):
    """Unpack bp binary from the par bundle in a temporary directory
    and run it with the supplied arguments.
    """
    tmpdir = tempfile.mkdtemp()
    for t in ['bp', 'bluepill']:
        unpack_tool(t, tmpdir)
    tool_path = os.path.join(tmpdir, tool)
    cmd = [tool_path] + args
    logging.debug("run cmd = {}".format(cmd))
    p = subprocess.Popen(cmd,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT,
                         close_fds=True)
    for line in iter(p.stdout.readline, ''):
        print(line.rstrip())
    shutil.rmtree(tmpdir)
    p.wait()
    return p.returncode


def unpack_tool(name, dest_dir):
    data = pkg_resources.resource_string(name, name)
    tool_path = os.path.join(dest_dir, name)
    with open(tool_path, 'wb') as f:
        f.write(data)
    os.chmod(tool_path, 0o755)


if __name__ == '__main__':
    main()
