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
import glob
import json
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
    parser = argparse.ArgumentParser()
    # attr_config_file is a config.json that comes from the rule's attributes (e.g. num_sims)
    parser.add_argument('--attr_config_file')
    # rule_config_file is the config.json that comes from the 'config_file' rule attribute
    parser.add_argument('--rule_config_file')
    parser.add_argument('--Xbp', nargs=1, action='append')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG,
                            format='%(asctime)s %(message)s')
    else:
        logging.basicConfig(format='%(asctime)s %(message)s')

    logging.debug("PWD: '%s'", os.getcwd())
    # flatten Xbp args
    bpargs = [a for sl in args.Xbp for a in sl]
    # Add xcode path to CLI
    bpargs += ['--xcode-path', find_xcode_path()]
    output_dir = os.environ['TEST_UNDECLARED_OUTPUTS_DIR']
    bpargs += ['--output-dir', output_dir]
    config_file = merge_config_files(args.rule_config_file,
                                     args.attr_config_file)
    bpargs += ['-c', config_file]

    logging.debug("Running: bluepill %s", ' '.join(bpargs))
    rc = run('bluepill', bpargs)
    if not args.verbose:
        os.remove(config_file)
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


def merge_config_files(config1, config2):
    """Merge two config files. Keys in config2 trump keys in config1,
    returns the path of the new merged file.
    """
    logging.debug("Merging '{}' '{}'".format(config1, config2))
    cfg1 = {}
    if config1:
        with open(config1, 'r') as f:
            cfg1 = json.load(f)
    cfg2 = {}
    if config2:
        with open(config2, 'r') as f:
            cfg2 = json.load(f)
    merged_cfg = {}
    for key, value in cfg2.items():
        merged_cfg[key] = value
    for key, value in cfg1.items():
        merged_cfg[key] = value
    f = tempfile.NamedTemporaryFile(mode='w+', delete=False)
    json.dump(merged_cfg, f)
    f.close()
    logging.debug("merged cfg file: {}".format(f.name))
    logging.debug("{}".format(merged_cfg))
    return f.name


def find_xcode_path():
    """Return the path to Xcode's Developer directory.
    """
    simctl_path = subprocess.check_output(
        ['xcrun', '--find', 'simctl']).decode('utf-8')
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
