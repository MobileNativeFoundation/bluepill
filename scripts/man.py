import re
import string
import textwrap


BPConfig = "Source/Shared/BPConfiguration.m"
BPExitStatus = "Bluepill-cli/Bluepill-cli/Bluepill/Reporters/BPExitStatus.h"
BPConstants = "Source/Shared/BPConstants.h"

# get the defaults
with open(BPConstants, 'r') as f:
    for line in f:
        if 'BP_DEFAULT_RUNTIME' in line:
            line = re.sub(r'.*BP_DEFAULT_RUNTIME *', '', line)
            line = line.strip('" \n')
            BP_DEFAULT_RUNTIME = line
            continue
        if 'BP_DEFAULT_DEVICE_TYPE' in line:
            line = re.sub(r'.*BP_DEFAULT_DEVICE_TYPE *', '', line)
            line = line.strip('" \n')
            BP_DEFAULT_DEVICE_TYPE = line
            continue

header = """
.\\" Bluepill help
.TH man 1 "Summer 2017" ".1" "Bluepill"

.SH NAME
bluepill \\- A tool to run iOS tests in parallel using multiple
simulators.

.SH SYNOPSIS
.B bluepill
\\fB\\-a\\fR \\fI<app>\\fR
\\fB\\-s\\fR \\fI<scheme>\\fR
\\fB\\-o\\fR \\fI<output_directory>\\fR
\\fR[other_options]\\fR

.B bluepill
\\fB\\-c\\fR \\fI<config_file>\\fR

.SH DESCRIPTION
Bluepill is a tool to run iOS tests in parallel using multiple
simulators. It requires the app to be compiled with the flags

\\fR -sdk iphonesimulator \\fR

.SH OPTIONS
"""

options = []
with open(BPConfig, 'r') as f:
    capture = False
    for line in f:
        line = line.strip()
        if not line:
            continue
        if line == "} BPOptions[] = {":
            capture = True
            continue
        if line == '{0, 0, 0, 0, 0, 0, 0}':
            break
        if capture and not line.startswith('//'):
            options.append(line.strip('{},'))

# Now parse them
opt_range = set(string.ascii_lowercase +
                string.ascii_uppercase +
                string.digits)
parsed_opts = []
i = 0
for i in range(0, len(options), 2):
    all_opts = options[i].split(',')
    desc = options[i+1].strip(' "')
    # now parse the options
    assert len(all_opts) == 9
    short_op = all_opts[0].strip(" '")
    if short_op not in opt_range:
        short_op = None
    long_op = all_opts[1].strip(' "')
    program = all_opts[2].strip()
    required = all_opts[3].strip()
    # skeep seen
    has_arg = all_opts[5].strip()
    default_val = all_opts[6].strip(' "')
    kind = all_opts[7].strip()
    # skip property
    op = {
        'short_op': short_op,
        'long_op': long_op,
        'program': program,
        'required': required,
        'has_arg': has_arg,
        'default_val': default_val,
        'kind': kind,
        'desc': desc,
        }
    parsed_opts.append(op)


def format_bi(op):
    """Format an op dictionary into a .BI line for troff"""
    line = '.BI '
    if op['short_op'] is not None:
        line += '-' + op['short_op'] + '/'
    line += '--' + op['long_op']
    if op['has_arg'] != 'NULL':
        if op['has_arg'] == 'no_argument':
            markers = ['', '']
        elif op['has_arg'] == 'required_argument':
            markers = ['<', '>']
        elif op['has_arg'] == 'optional_argument':
            markers = ['[', ']']
        else:
            markers = ['', '']

        line += ' " {}{}{}"'.format(
            markers[0],
            op['long_op'].replace('-', '_'),
            markers[1],
        )
    return line


# now print them
print(header)
for op in parsed_opts:
    print('.TP')
    print(format_bi(op))
    print('\n'.join(textwrap.wrap(op['desc'], 72)))
    if op['default_val'] != 'NULL':
        if op['default_val'] == 'BP_DEFAULT_DEVICE_TYPE':
            defval = '"' + BP_DEFAULT_DEVICE_TYPE + '"'
        elif op['default_val'] == 'BP_DEFAULT_RUNTIME':
            defval = '"' + BP_DEFAULT_RUNTIME + '"'
        else:
            defval = op['default_val']
        print('\\fR  Default Value: {} \\fR'.format(defval))
    print()

print("""

.SH RETURN VALUE

Bluepill will exit zero on success (all tests passed) and non-zero on
any kind of failure (either from the tests or because bluepill
couldn't run them).

.EXAMPLES

 $ mkdir output_directory
 $ xcodebuild -workspace MyApp.xcworkspace -scheme MyScheme -sdk iphonesimulator \\

       build-for-testing -derivedDataPath .
 $ bluepill -a ./Build/Debug-iphonesimulator/MyApp.app -s MyScheme.xcscheme -o output_directory

.SH SEE ALSO

xcrun(1), xcode-build(1), xcode-select(1)

.SH BUGS

No known bugs. Please see http://github.com/linkedin/bluepill/issues
for an up-to-date list.

.SH HISTORY

Bluepill was developed at LinkedIn during the fall of 2016 as a
replacement for our scripts for running iPhone simulators in
parallel. It was released as an Open Source project on GitHub at the
beginning of 2017.

.SH AUTHORS

Ashit Gandhi (agandhi@linkedin.com)
Jarek Rudzinski (jrudzinski@linkedin.com)
Keqiu Hu (khu@linkedin.com)
Oscar Bonilla (obonilla@linkedin.com)
Yu Li (yli4@linkedin.com)
""")
