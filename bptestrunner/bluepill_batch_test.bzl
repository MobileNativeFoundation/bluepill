load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleTestInfo",
)

def _bluepill_batch_test_impl(ctx):
    runfiles = [ctx.file._bp_exec, ctx.file._bluepill_exec]
    test_bundle_paths = []
    test_host_paths = []

    # test environments
    test_env = ctx.configuration.test_env

    # gather files
    test_plans = {}
    for test_target in ctx.attr.test_targets:
        test_info = test_target[AppleTestInfo]
        bundle_info = test_target[AppleBundleInfo]
        test_host = test_info.test_host
        test_bundle = test_info.test_bundle
        if test_bundle:
            test_bundle_paths.append("\"{}\"".format(test_bundle.short_path))
            runfiles.append(test_bundle)

        if test_host and test_host not in runfiles:
            test_host_paths.append("\"{}\"".format(test_host.short_path))
            runfiles.append(test_host)

        #test_plan
        test_plan = struct(
            test_host = test_host.basename.rstrip(
                "." + test_host.extension,
            ) + ".app",
            environment = test_env,
            arguments = test_env,
            test_bundle_path = bundle_info.bundle_name + bundle_info.bundle_extension,
        )
        test_plans[test_target.label.name] = test_plan

    # Write test plan json.
    test_plan_file = ctx.actions.declare_file(ctx.attr.name + "_test_plan.json")
    ctx.actions.write(
        output = test_plan_file,
        content = struct(tests = test_plans).to_json(),
    )
    runfiles.append(test_plan_file)

    # Write the shell script.
    substitutions = {
        "test_bundle_paths": " ".join(test_bundle_paths),
        "test_host_paths": " ".join(test_host_paths),
        "bp_test_plan": test_plan_file.basename,
        "bp_path": ctx.executable._bp_exec.short_path,
        "bluepill_path": ctx.executable._bluepill_exec.short_path,
        "target_name": ctx.attr.name,
    }
    if ctx.attr.config_file:
        runfiles += [ctx.file.config_file]
        substitutions["bp_config_file"] = ctx.file.config_file.path
    if ctx.attr.time_estimates:
        runfiles += [ctx.file.time_estimates]
        substitutions["bp_test_time_estimates_json"] = ctx.file.time_estimates.path
    ctx.actions.expand_template(
        template = ctx.file._test_runner_template,
        output = ctx.outputs.test_runner,
        substitutions = substitutions,
    )
    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = runfiles,
            ),
            executable = ctx.outputs.test_runner,
        ),
    ]

bluepill_batch_test = rule(
    implementation = _bluepill_batch_test_impl,
    attrs = {
        "test_targets": attr.label_list(
            doc = """
A list of test targets to be bundled and run by bluepill.
""",
        ),
        "config_file": attr.label(
            doc = """
A configuration file that will be passed to bluepill. Rule attributes
take precedence over conflicting values in the config file.
""",
            allow_single_file = True,
        ),
        "time_estimates": attr.label(
            doc = """
A json file that includes time took of each test from previous test
executions. It is used by Bluepill to distribute the tests as evenly
as possible between simulators.
""",
            allow_single_file = True,
        ),
        "_bp_exec": attr.label(
            default = Label(
                "//:bp",
            ),
            allow_single_file = True,
            executable = True,
            cfg = "host",
        ),
        "_bluepill_exec": attr.label(
            default = Label(
                "//:bluepill",
            ),
            allow_single_file = True,
            executable = True,
            cfg = "host",
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                fragment = "apple",
                name = "xcode_config_label",
            ),
        ),
        "_test_runner_template": attr.label(
            default = Label(
                "//:bluepill_batch_test_runner.template.sh",
            ),
            allow_single_file = True,
        ),
    },
    test = True,
    fragments = ["apple", "objc"],
    outputs = {
        "test_runner": "%{name}.sh",
    },
    doc = """
Test rule to aggregate a list of test rules and pass them for bluepill for execution

Outputs:
Runfiles:
files: The files needed during runtime for the test to be performed. It contains the
test plan json file, bluepill config file if specified, xctest bundles, test hosts.

This rule WILL disregard the bluepill output folder configuration if it's set in the
config json file. Instead it will copy all the outputs to ./bazel-testlogs/$TARGET_NAME/test.outputs/
""",
)
