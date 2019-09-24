load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")


http_archive(
     name = "build_bazel_rules_apple",
     url = "http://artifactory.corp.linkedin.com:8081/artifactory/TOOLS/com/linkedin/bazel_rules_apple/bazel_rules_apple/0.18.0.0/bazel_rules_apple-0.18.0.0.tar.gz",
     sha256 = "a705a9e5a71192a49afcb85719d5774ee9bb734a0065fe1fd91161f51ecaa84b",
     strip_prefix = "rules_apple"
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()

# For packaging python scripts.
http_archive(
    name = "subpar",
    url = "https://github.com/google/subpar/archive/2.0.0.zip",
    sha256 = "8876244a984d75f28b1c64d711b6e5dfab5f992a3b741480e63cfc5e26acba93",
    strip_prefix = "subpar-2.0.0",
)
