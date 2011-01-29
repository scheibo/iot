# iot

`iot` serves as a testing 'suite' for the times when you only care that given a certain input, a certain output is produced. `iot` tries to be a simple solution to creating and managing
 test suites in this limited environment.

The basic idea behind `iot` is that it runs a given program and saves the output (and error) streams, comparing them to the expected output (and error). `iot` can handle running entire suites of such tests (i.e. directories on input files), or simply individual tests. One powerful feature that `iot` has is the ability to accept custom matchers for dealing with the output of tests. See the 'Custom Test Matchers' section below for more information.

The source file for `iot` aims to be easy to edit, so feel free to fork and change the project so that it suits you better.

 * see the manpage [iot.1](http://scheibo.github.com/iot/iot.1.html)
 * view the annotated [source](http://scheibo.github.com/iot)

## Installation

	$ git clone git://github.com/scheibo/iot.git
	$ cd iot
	$ [sudo] cp iot /bin/somewhere/on/your/path

## Features

 - tests suites or individual files
 - custom test matchers
 - colorized output
 - flexible test directory layout
 - [RSpec](http://rspec.info/) like output
 - easily hackable source code

## Usage

Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

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

[autotest]: https://github.com/grosser/autotest
[progressbar]: http://ekenosen.net/nick/devblog/2008/12/better-progress-bar-for-rspec/

## Copyright

`iot` is Copyright (c) 2011 [Kirk Scheibelhut](http://scheibo.com/about) and distributed under the MIT license.<br />
See the `LICENSE` file for further details regarding licensing and distribution.
