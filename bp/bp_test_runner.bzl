load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "AppleTestRunnerInfo",
)

bp_test_runner = rule(
    _bp_test_runner_impl,
    attrs = {
        "device_type": attr.string(
            default = "",
            doc = """
The device type of the iOS simulator to run test. The supported types correspond
to the output of `xcrun simctl list devicetypes`. E.g., iPhone 6, iPad Air.
By default, it is the latest supported iPhone type.'
""",
        ),
        "os_version": attr.string(
            default = "",
            doc = """
The os version of the iOS simulator to run test. The supported os versions
correspond to the output of `xcrun simctl list runtimes`. ' 'E.g., 11.2, 9.3.
By default, it is the latest supported version of the device type.'
""",
        ),
    }
)