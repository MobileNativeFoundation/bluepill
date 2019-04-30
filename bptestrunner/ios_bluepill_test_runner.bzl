""" Bluepill test runner rule. """

load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "AppleTestRunnerInfo",
)

def _get_template_substitutions(ctx):
    """Returns the template substitutions for this runner."""
    subs = {
        "device": ctx.attr.device,
        "runtime": ctx.attr.runtime,
        "headless": str(ctx.attr.headless).lower(),
        "clone_simulator": str(ctx.attr.clone_simulator).lower(),
        "num_sims": str(ctx.attr.num_sims),
        "testrunner_binary": ctx.executable._testrunner.short_path,
    }
    return {"%(" + k + ")s": subs[k] for k in subs}

def _get_execution_environment(ctx):
    """Returns environment variables the test runner requires"""
    execution_environment = {}
    xcode_version = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig].xcode_version())
    if xcode_version:
        execution_environment["XCODE_VERSION"] = xcode_version

    return execution_environment

def _ios_bluepill_test_runner_impl(ctx):
    """Implementation for the ios_bluepill_test_runner rule."""
    ctx.actions.expand_template(
        template = ctx.file._test_template,
        output = ctx.outputs.test_runner_template,
        substitutions = _get_template_substitutions(ctx),
    )
    return [
        AppleTestRunnerInfo(
            test_runner_template = ctx.outputs.test_runner_template,
            execution_requirements = ctx.attr.execution_requirements,
            execution_environment = _get_execution_environment(ctx),
        ),
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [ctx.file._testrunner],
            ),
        ),
    ]

ios_bluepill_test_runner = rule(
    _ios_bluepill_test_runner_impl,
    attrs = {
        "device": attr.string(
            default = "iPhone 6s",
            doc = """
On which device to run the app.
""",
        ),
        "runtime": attr.string(
            default = "iOS 12.1",
            doc = """
What runtime to use.
""",
        ),
        "headless": attr.bool(
            default = True,
            doc = """
Run in headless mode (no GUI).
""",
        ),
        "clone_simulator": attr.bool(
            default = False,
            doc = """
Spawn simulator by clone from simulator template.
""",
        ),
        "num_sims": attr.int(
            default = 1,
            doc = """
Number of simulators to run in parallel.
""",
        ),
        "execution_requirements": attr.string_dict(
            allow_empty = False,
            default = {"requires-darwin": ""},
            doc = """
Dictionary of strings to strings which specifies the execution requirements for
the runner. In most common cases, this should not be used.
""",
        ),
        "_test_template": attr.label(
            default = Label(
                "@bptestrunner//bptestrunner:bluepill_test_runner.template.sh",
            ),
            allow_single_file = True,
        ),
        "_testrunner": attr.label(
            default = Label(
                "@bptestrunner//bptestrunner:bptestrunner.par",
            ),
            allow_single_file = True,
            executable = True,
            cfg = "host",
            doc = """
It is the rule that needs to provide the AppleTestRunnerInfo provider. This
dependency is the test runner binary.
""",
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                fragment = "apple",
                name = "xcode_config_label",
            ),
        ),
    },
    outputs = {
        "test_runner_template": "%{name}.sh",
    },
    fragments = ["apple", "objc"],
    doc = """
Rule to identify an iOS runner that runs tests for iOS.

The runner will create a new simulator according to the given arguments to run
tests.

Outputs:
  AppleTestRunnerInfo:
    test_runner_template: Template file that contains the specific mechanism
        with which the tests will be performed.
    execution_requirements: Dictionary that represents the specific hardware
        requirements for this test.
  Runfiles:
    files: The files needed during runtime for the test to be performed.
    """,
)
