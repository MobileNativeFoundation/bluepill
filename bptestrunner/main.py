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

# Default bp config file
bp_config_file = {
    'app': None,
    'test-bundle-path': None,
    'output-dir': None,
    'device': 'iPhone 6',
    'runtime': 'iOS 12.1',
    'xcode-path': '/Applications/Xcode.app/Contents/Developer',
    'num-sims': 1,
    'commandLineArguments': [],
    'environmentVariables': {},
    'headless': True,
}


def main():
    """Parse the arguments in an xctestrunner-compatible way
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose', help='Increase output verbosity.',
                        action='store_true')
    basic_arguments = parser.add_argument_group(
        'Basic arguments', description="")
    basic_arguments.add_argument(
        '--app_under_test_path',
        help='The path of the application to be tested.')
    basic_arguments.add_argument(
        '--test_bundle_path',
        help='The path of the test bundle that contains the tests.')
    basic_arguments.add_argument('--xctestrun', help='')
    optional_arguments = parser.add_argument_group('Optional arguments')
    optional_arguments.add_argument('--launch_options_json_path', help='')
    optional_arguments.add_argument('--signing_options_json_path', help='')
    optional_arguments.add_argument('--test_type', help='')
    optional_arguments.add_argument('--work_dir', help='')
    optional_arguments.add_argument('--output_dir', help='')
    subparsers = parser.add_subparsers(help='Sub-commands help')
    test_parser = subparsers.add_parser('simulator_test', help='only command')
    test_parser.add_argument('--device_type', help='iPhone')
    test_parser.add_argument('--os_version', help='iOS version')
    test_parser.add_argument('--new_simulator_name', help='ignored')
    test_parser.add_argument('--num-sims', help='num sims')
    test_parser.set_defaults(func=run_bp)
    args = parser.parse_args()
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG,
                            format='%(asctime)s %(message)s')
    else:
        logging.basicConfig(format='%(asctime)s %(message)s')
    logging.debug("args:\n{}".format(sys.argv))
    logging.debug("env:\n{}".format(os.environ))
    exit_code = args.func(args)
    logging.info('Done.')
    return exit_code


def run_bp(args):
    """Take the xctestrunner-compatible arguments, transform them
    into a config file that bp can use, and run `bp`.
    """
    # Set options  from command line arguments
    bp_config_file['app'] = args.app_under_test_path
    bp_config_file['test-bundle-path'] = args.test_bundle_path
    bp_config_file['output-dir'] = args.work_dir
    bp_config_file['device'] = args.device_type
    bp_config_file['xcode-path'] = find_xcode_path()
    bp_config_file['num-sims'] = args.num_sims

    # set launch options from given file
    with open(args.launch_options_json_path, 'r') as f:
        data = json.load(f)
        bp_config_file['environmentVariables'] = data.get('env_vars', {})
        if data.get('tests_to_run', None):
            bp_config_file['include'] = data['tests_to_run']

    # save the config file
    cfg_file = tempfile.NamedTemporaryFile(delete=False)
    cfg_file.write(json.dumps(bp_config_file))
    cfg_file.close()

    # Run bluepill
    rc = run('bluepill', ['-c', cfg_file.name])
    os.remove(cfg_file.name)

    # copy outputs to where they should be
    find_and_copy_outputs(args.work_dir, args.output_dir)
    return rc


def find_and_copy_outputs(src_dir, dst_dir):
    # Find the XML and json outputs
    pattern = os.path.join(src_dir, '*.xml')
    xml_files = glob.glob(pattern)
    assert(len(xml_files) >= 1)
    final_xml_output = xml_files[0]
    for xml_file in xml_files:
        if xml_file.find('FINAL'):
            final_xml_output = xml_file
            break
    xml_output_path = os.environ['XML_OUTPUT_FILE']
    shutil.copy(final_xml_output, xml_output_path)
    shutil.copy(final_xml_output, dst_dir)
    trace_profile = os.path.join(src_dir, 'trace-profile.json')
    if not os.path.exists(trace_profile):
        trace_profile = None
        pattern = os.path.join(src_dir, '*-stats.json')
        json_files = glob.glob(pattern)
        if len(json_files) > 0:
            trace_profile = json_files[0]
    if trace_profile:
        shutil.copy(trace_profile, os.path.join(dst_dir, 'trace-profile.json'))


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
