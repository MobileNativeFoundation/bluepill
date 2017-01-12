
![BluepillIcon](doc/img/bluepill_text.png) Bluepill is a tool to run iOS tests in parallel using multiple simulators.

[![Build Status](https://travis-ci.org/linkedin/bluepill.svg?branch=master)](https://travis-ci.org/linkedin/bluepill)

## Motivation

LinkedIn created Bluepill to run iOS tests in parallel using multiple simulators.

## Features

-  Running tests in parallel by using multiple simulators.
-  Automatically packing tests into groups with similar running time.
-  Running tests in headless mode to reduce memory consumption.
-  Generating a junit report after each test run.
-  Reporting test running stats, including test running speed and environment robustness.
-  Retrying when the Simulator hangs or crashes.

## Usages

It is quick and easy to start using Bluepill! In a simplified scenario, you just need to run the following command and Bluepill will kick off 4 simulators to run your tests in parallel. By the end of the test run, it will generate a report in ./output.

```
./bluepill -a ./Sample.app -s ./SampleAppTestScheme.xcscheme -o ./output/
```

Alternatively, you can have a configuration file like the one below:

```
{
   "app": "./Sample.app", # Relative path or abs path
   "scheme-path": "./SampleAppTestScheme.xcscheme", # Relative path or abs path
   "output-dir": "./build/" # Relative path or abs path
}
```

And run

```
./bluepill -c config.json
```

A full list supported options are listed here.


| Config Arguments   | Command Line Arguments | Explanation                                                                    | Required | Default value |
|:------------------:|:----------------------:|--------------------------------------------------------------------------------|:--------:|:-------------:|
|        `app`       |           -a           | The path to the host application to execute (your .app)                        |     Y    | n/a           |
|    `output-dir`    |           -o           | Directory where to put output log files (bluepill only)                        |     Y    | n/a           |
|    `scheme-path`   |           -s           | The scheme to run tests                                                        |     N    | n/a           |
|       config       |           -c           | Read options from the specified configuration file instead of the command line |     N    | n/a           |
|       device       |           -d           | On which device to run the app.                                                |     N    | iPhone 6      |
|       exclude      |           -x           | Exclude a testcase in the set of tests to run                                  |     N    | empty         |
|      headless      |           -H           | Run in headless mode (no GUI).                                                 |     N    | off           |
|       include      |           -i           | Include a testcase in the set of tests to run.                                 |     N    | all tests     |
|     json-output    |           -J           | Print test timing information in JSON format.                                  |     N    | off           |
|    junit-output    |           -j           | Print results in JUnit format.                                                 |     N    | true          |
|     list-tests     |           -l           | Only list tests in bundle                                                      |     N    | false         |
|      num-sims      |           -n           | Number of simulators to run in parallel. (bluepill only)                       |     N    | 4             |
|    plain-output    |           -p           | Print results in plain text.                                                   |     N    | true          |
|    printf-config   |           -P           | Print a configuration file suitable for passing back using the `-c` option.    |     N    | n/a           |
|    error-retries   |           -R           | Number of times we'll recover from app crashing/hanging and continue running   |     N    | 5             |
|  failure-tolerance |           -f           | The number of retries on any failures (app crash/test failure)                 |     N    | 0             |
|       runtime      |           -r           | What runtime to use.                                                           |     N    | 10.1          |
|    stuck-timeout   |           -S           | Timeout in seconds for a test that seems stuck (no output).                    |     N    | 300s          |

## Demo

![BluepillDemo](doc/img/demo.gif)
