# iot

`iot` serves as a testing 'framework' for the times when you only care that given a certain input, a certain output is produced. `iot` tries to be a simple solution to creating and managing
 test suites in this limited environment.

The basic idea behind `iot` is that it runs a given program and saves the output (and error) streams, comparing them to the expected output (and error). `iot` can handle running entire suites of such tests (i.e. directories on input files), or simply individual tests. One powerful feature that `iot` has is the ability to accept custom matchers for dealing with the output of tests. See the 'Custom Test Matchers' section below for more information.

The source file for `iot` aims to be easy to edit, so feel free to fork and change the project so that it suits you better.

 * see the manpage [iot(1)](http://scheibo.github.com/iot/iot.1.html)
 * view the annotated [source](http://scheibo.github.com/iot)

## Installation

	$ git clone git://github.com/scheibo/iot.git
	$ cd iot
	$ make
	$ make install

## Features

 - tests suites or individual files
 - custom test matchers
 - colorized output
 - flexible test directory layout
 - [RSpec](http://rspec.info/) like output
 - easily hackable source code

## Usage

The most straightforward set up of `iot` involves creating a directory named 'tests' in the top level of your project. Inside this 'tests' directory are one or more 'test suites' (or 'suites' for short). Suites are the basic unit of testing -- they consist of one or more input and expected output files. There is then two options for created your expected input and output: either place them all in the top-level of this suite directory and simply suffix them with '.in'. '.out' and '.err' respectively, or create these directories within the suite directory (i.e. 'suite\_name/in', 'suite\_name/out', 'suite\_name/err'). Test input files can be named in any fashion (besides the .in suffix if they are in the top-level of a suite) with the exception of the prefix requirement that custom matchers impose. See the 'Custom Test Matchers' section below for more information regarding this special case. It is recommended that the input file names are descriptive of the tests nature, as they will appear in the failure message should the test not pass. The expected output messages need to been named the same as the input files (the only difference in names is that they're either in the 'out' directory or they are suffixed by '.out').

`iot` can handle expected messages for both _stdout_ and/or _stderr_, and either case can be excluded if you do not care about the output from a given stream on a give test. Unless you're using a custom matcher, at least one of these expect files needs to be present, as something needs to be passed to `diff`. One common trick is that if you require one of the streams to be empty, supply a blank file of that type (i.e. if you want to ensure there's no output on _stderr_ supply a blank 'err' file for the given test).

In order to run tests, simply issue the `iot` command from within the project. By default `iot` tries to run from the `git` or `hg` root, defaulting to the current working directory. `iot` expects the name of a program to test, followed to one or more test suites. This program name is *not* a path to the file, it is simply the name of the file located in the `ROOTDIR`. By default, `iot` runs the program as `./program`, in order to change this behavior pass in a `--command` when calling `iot`. `iot` runs all the tests in the suites it is given, exiting with the number of tests failed and printing to _stdout_ the failure when its is completed running.

As an alternative to running an entire suite `iot` can be called with a specific test. This is a _pseudo_ path which is of the form 'suite\_name/test\_name'. This will find an input file in the given suite (i.e. either a '.in' file or a 'in/*' file) which is named with 'test_name'.

There are several different modes from running `iot`: these include verbose mode (`--verbose`) which prints longer diagnostic messages while running the tests, immediate mode (`--immediate`) which immediately prints full error diffs after every failure and 'sudden death' mode (`--sudden-death`) which stops testing files in a suite directly following the first error. More options for modes are detailed in the [manpage](http://scheibo.github.com/iot/iot.1.html#OPTIONS).

## Examples

	$ iot program test

Runs the given program with all the input file for the given test and compares the output to the output for the test.

	$ iot --command='mzscheme' program.ss suite-1 suite-2

Runs 'program.ss' with a custom command (as opposed to just './program.ss') on two test suites. These test suites contain groups of input/output (and/or error) files which are testing fed to 'program.ss' in turn and checked for failure conditions.

Some sample output:

	Started
	...........
	Finished

	11 tests, 0 failures

Or for failing cases:

	Started
	....F......
	Finished

		1) list_suite/in/test_list.in
		Expected:
		apple, orange, banana

		Received:
		banana, banana, banana

	11 tests, 1 failures

## Custom Test Matchers

Sometimes `diff`-ing the expected and actual output streams to coarse -- perhaps you only care that part of the output matches. For example, say you only care that given a certain invalid input you're program produces the word 'ERROR' somewhere on `stderr`. `iot` supports the idea of custom test matchers -- programs that get run instead of diff to determine whether a given output is acceptable or not. Two things are import for dealing with custom test matchers: prefixes on the test input file and a custom matcher function.

### Prefixes

`iot` determines which files to use a custom test matcher on by checking out the prefix of the test input file it is evaluating. Let's say that for our case above (checking that 'ERROR' exists on the `stderr` stream) we're going to use a custom matcher named `error_check`. In that case, any test input file we wish to use this matcher on should should be prefixed with `error_check`. Prefixes can come in the form of '`prefix_`' or '`prefix.`' (that is, followed by a '_' or a '.'). The output and error files for this input file should also have the prefix on them as well. Prefixed test input files can coexist in a test suite with non-prefixed input files, and multiple different types of prefixed index files can exist in a given suite. The only thing different between an input file with a prefix and a non-prefixed file is that the prefixed file will be matched by a different matcher.

### Matchers

Matchers form the other half of the custom test matcher system. A matcher is the actual function which determines whether the result output (and/or error) should be considered as 'passing'. `iot` looks for an `test_matcher` or `iot_matcher` shell file at the root of the test directory.. i.e.

	tests
	├── test_matcher
	├── suite1
	│   ├── in
	│   ├── out
	│   └── err
	├── suite2
	└── suite3

This file get sourced in `iot` and is available to all of the test suites. Alternatively, each test matcher can belong in its own file named by '`prefix`'matcher, where prefix is described above. Hence we could put our `error_check` matcher in a file named `error_check_matcher` _or_ `error_check.matcher`. These individual matcher files should also be in the top level `test` directory. One final alternative is to specify the matcher file to use through the `--matcher` option on the command line.

Inside of a matcher file should be a function named `prefix`matcher (where only the `prefix_` form is a allowed, since it is a function) which takes in a couple of arguments: `$result_output`, `$result_err`, `$expected_output`, `$expected_err`; where all of the previous arguments are paths which name the specific (possibly non-existent) files. The `$expected_output` and `$expected_err` files would be non-existent if they were not provided in the suites -- some matchers don't require these files. The matcher function need simply return a non-zero exit code to signal that the test has failed. Coming back to our error example from above:

	# tests/test_matcher
	error_check_matcher() {
		shift; # ignore result_output
		grep "ERROR" "$1"
	}

Here we can see the matcher only cares about the `$result_err` (here `$1` since a `shift` was performed) and it returns a non-zero exit code if `grep` fails to find the required string in the message.

### Example

For a more advanced example, consider the case of outputting an unordered hash in the form 'key: val', where each entry in the hash gets its own line. Clearly, the majority of the time simply trying to match up this output to an expected output file is going to fail since the order of the hash is undefined. In order to get around this we can build a custom matcher. We'll name our input file `in/unordered.test_hash.in` and our expected output file `out/unordered.test_hash.out`. We don't care about errors in this simple example. We then need to create a `test/test_matcher` file with the following function:

	# tests/test_matcher
	unordered_matcher(){
		actual_output="$1"
		expected_output="$3"

		for line in "$expected_output"; do
			if [ $(grep -c "^${line}$" "$actual_output") -ne 1 ]; then
				exit 1;
			fi
		done
	}

## Future

 - [autotest][] behavior
 - timing performance
 - [progressbar][] style
 - [parallel][] processing of tests

[autotest]: https://github.com/grosser/autotest
[progressbar]: http://ekenosen.net/nick/devblog/2008/12/better-progress-bar-for-rspec/
[parallel]: http://www.gnu.org/software/parallel

## Copyright

`iot` is Copyright (c) 2011 [Kirk Scheibelhut](http://scheibo.com/about) and distributed under the MIT license.<br />
See the `LICENSE` file for further details regarding licensing and distribution.
