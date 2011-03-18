#!/bin/sh -x
# **iot** serves as a testing 'framework' for the times when you only care
# that given a certain input, a certain output is produced. `iot` tries to be
# a simple solution to creating and managing test suites in this limited
# environment. The basic idea behind `iot` is that it runs a given program and
# saves the output (and error) streams, comparing them to the expected output
# (and error). iot can handle running entire suites of such tests (i.e.
# directories on input files), or simply individual tests.
#
# Installing `iot` is simple - just clone the repository and copy (or link)
# the 'iot' file to a location on your `PATH` (like `~/bin`, for
# example). Alternatively, if you want to have it in /usr/local/bin and the
# man pages installed correctly:
#
#     $ git clone git://github.com/scheibo/iot.git
#     $ cd iot
#     $ make
#     $ [sudo] make install
#     $ iot program suite
#
# This web page was created by running [shocco][] against the `iot` [source][]
# file.More information regarding `iot` can be found in the [README][] or in
# the [iot(1)][man] manpage.
#
# [shocco]: https://github.com/rtomayko/shocco
# [source]: https://github.com/scheibo/iot
# [README]: https://github.com/scheibo/iot#readme
# [man]: http://scheibo.github.com/iot/iot.1.html

# Usage
# -----
#
# We're going to steal an idea from [rtomyako](https://github.com/rtomayko)'s
# [shocco][] program by including the 'Usage' message as a comment and then
# later doing some 'magic' to output as a help message. In order to get around
# `shocco` from parsing it as documentation, we need to include some character
# other than a space after the comment.
#
#/ Usage: iot <program> <test-suite>...
#/        iot <program> <test-file>...
#/        iot --command=<program_runner> <program> <test-suite>...
#/
#/ Simple test runner for input/output tests. Feeds a given program
#/ input files and compares the output to a set of expected output files.
#/
#/ Configuration options:
#/    -s, --sandboxdir=<dir>             change the default temp directory
#/    -t, --testdir=<dir>                change default test directory
#/    -r, --rootdir=<dir>                change default root directory
#/    -c, --command=<command>            use <command> to run the program
#/    -m, --matcher=<file>               use the custom matchers in <file>
#/
#/ Mode options:
#/    -i, --immediate                    immediately print diagnostic info
#/    -v, --verbose                      more verbose failure program msgs
#/    -x, --sudden-death                 stop after the first failed test
#/    -q, --quiet                        test and return exit code, no output
#/    -u, --unified                      use a unified diff for fail output
#/    --safe, --copy                     copy the source to allow for editing

# Our magic usage function, pretty much straight from [shocco][]. We parse our
# own file for our comment leader and then print the stripped message.
usage() {
  grep '^#/' <"$0" | cut -c4-
}

# For the error function we print whatever argument we're given and the usage
# block. One problem that could result from the use of `exit 1` is that
# another script might misinterpret this to mean a single test failed (since
# usually the fail count is the exit code). Changing status with something
# like 125 might help, but that's just delaying the issue.
error() {
  printf "$(basename $0): ${*}\n" >&2
  usage
  exit 1
}

# Pass and Failure Messages
# -------------------------
#
# The default pass and failure messages. We're taking after
# [RSpec](http://rspec.info) here and simply printing a very minimal
# indicator. Specifying `-v` will get the user more information if they want
# it. One thing to note is that the messages will get colored (red and green,
# respectively) later on down the line.
passmsg() { ppass "."; }
failmsg() { pfail "F"; }

# There is also the verbose options for the messages. Two things to note are
# how we manually include a newline and how we're normalizing the test file
# name to remove any leading path or .in cruft.
verbose_passmsg() {
  test_name="${1##/*/}"
  test_name="${test_name%%.in}"
  ppass "Passed test: '$(basename ${suite})/$(basename ${test_name})'\n"
}
verbose_failmsg() {
  test_name="${1##/*/}"
  test_name="${test_name%%.in}"
  pfail "Failed test: '$(basename ${suite})/$(basename ${test_name})'\n"
}

# Colors
# ------
#
# In order to change the terminal colors we're going to use tput as opposed to
# escape codes (for fun!). We need to be sure to finish with a `RESET` every
# time we change the color or else the color will continue to be used for the
# rest of the output (or at least until it is changed again).
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# There are helper functions for printing passing, warning and failing
# messages. They simply wrap their input in colors. Notice the conspicious use
# of `printf(1)` in all of this code without a `\n`.
ppass() { printf "${GREEN}${*}${RESET}"; }
pwarn() { printf "${YELLOW}${*}${RESET}"; }
pfail() { printf "${RED}${*}${RESET}"; }

# Option Processing and Setup
# ---------------------------
#
# The code for option processing is pretty self explanatory, just a loop
# through the command line arguments, assigning variables and shifting as we
# go. The constants determining the path begin undefined - we adjust them
# later on if they haven't been set by the user. All of our booleans denote
# exceptional cases, so they all start out as false unless changed by the
# user.
immediate=false
verbose=false
sudden_death=false
quiet=false
unified=false
safe=false

# It's sometimes difficult to remember all the proper option names, so `iot`
# tries to 'do the Right Thing' if the arguments don't exactly match. Notice,
# for example, that 'immeadiate' is provided as an option, as I commonly typo
# this.
#
# There's really two types of different parsing techniques going on here, to
# deal with the `--option` and `--option=` arguments. The straightforward
# options just have their argument following them, so we shift twice - once to
# eliminate the option and the second time to get rid of the argument. The
# `--option=` type require only one shift since the argument is included in
# the name, the only difficulty here is using the special syntax for shell
# variables which strips away everything that matches a regex.
#
# This is kind of an ugly looking dense block, and I'm generally not a huge
# fan of the arbitrary aligning of various lines, but since option parsing is
# so repetitive and the code's job is so self explanatory we can save some
# screen real estate here.
while test $# -gt 0
do
  case $1 in
    -s|--sandboxdir|--tempdir)  SANDBOXDIR="$2";       shift 2 ;;
    --tempdir=*|--sandboxdir=*) SANDBOXDIR="${1##*=}"; shift   ;;

    -t|--testdir) TESTDIR="$2";                        shift 2 ;;
    --testdir=*)  TESTDIR="${1##*=}";                  shift   ;;

    -r|--root|--rootdir)  ROOTDIR="$2";                shift 2 ;;
    --root=*|--rootdir=*) ROOTDIR="${1##*=}";          shift   ;;

    -c|--run|--command) COMMAND="$2";                  shift 2 ;;
    --run=*|--command=*) COMMAND="${1##*=}";           shift   ;;

    -m|--matcher) MATCHER="$2";                        shift 2 ;;
    --matcher=*) MATCHER="${1##*=}";                   shift   ;;

    -i|--immediate|--imeadiate) immediate=true;        shift   ;;
    -v|-vv|--verbose)           verbose=true;          shift   ;;
    -q|--quiet|--silent)        quiet=true;            shift   ;;
    -u|--unified)               unified=true;          shift   ;;
    --copy|--safe)              safe=true;             shift   ;;
    -x|--sudden-death|--sudden_death|--suddendeath)
                                sudden_death=true;     shift   ;;

    -h|--help|'-?'|'--?') usage && exit 0                      ;;
    -*) error "unrecognized option: ${1}"                      ;;
    *) break                                                   ;;
  esac
done

# Sandbox and Cleanup
# -------------------
#
# We need a place to send all the output from the program we're testing before
# we can see if it matches the expected output. We'll need a temporary sandbox
# directory to do this. We use the `:=` paramter expansion to make sure
# `TMPDIR` is set. We then try to use `mktmp(1)` to create the temp directory
# if we're lucky enough to have it, otherwise we create our directory far more
# insecurely using the programs basename and pid. One thing to note: some
# implementations of `mktmp(1)` require the string of X's and others don't, I
# had trouble installing `shocco(1)` on my machines because of this issue.
: ${TMPDIR:=/tmp}
: ${SANDBOXDIR:=$(
  if command -v mktemp 1>/dev/null 2>&1; then
    mktemp -dt "$(basename $0).XXXXXXXXXXXXX"
  else
    dir="$TMPDIR/$(basename $0).$$"
    mkdir "$dir"
    echo "$dir"
  fi
)}

# Here we perform a bit of a sanity check to make sure we're not using a
# stupid location for our temp directory which would result in lots of
# potentially nasty things happening.
if [ -z "$SANDBOXDIR" -o "$SANDBOXDIR" = "/" ]; then
  error "could not create a temporary sandbox directory"
fi

# Most importantly we're going to register an `EXIT` trap to clean up our temp # directory unless we're killed witbh `SIGKILL.`
#
# All of the code dealing with creating and cleaning up our temporary sandbox # directory comes at you straight out of [shocco][].
trap "rm -rf $SANDBOXDIR" 0

# Directory Setup
# ----------------
#
# Here we try to determine where the root directory of the project we're
# testing is. We first need to check if if `ROOTDIR` was already set by the
# user through the `--rootdir` command line option. This leverages the
# `${var:+val}` variable subsititution form which returns its value if
# `ROOTDIR` is defined and not null. We start by defaulting to the current
# directory - in the most basic case `iot` will be run from the top level
# directory. However, in order to provide more of a convenience for people
# using source control, we'll also check if we're in a `hg` or `git`
# repository, using the root of that repository as the root directory for the
# script. This allows us to call the script anywhere in the project and it
# will still be able to find the correct files.
if [ -z "${ROOTDIR:+1}" ]; then
  ROOTDIR=`pwd`
  hg root 1>/dev/null 2>&1 && ROOTDIR=`hg root`
  git rev-parse --show-toplevel 1>/dev/null 2>&1 && ROOTDIR=`git rev-parse --show-toplevel`
fi


# The default location we're going to be look for tests when resolving
# 'pseudo' paths and suite names. The `:=` form is used here again, it's
# similar to the `||=` in Ruby.
default="${ROOTDIR}/tests"
: ${TESTDIR:=$default}


# We want to bring in the file that holds our custom matchers. If `MATCHER` is
# set then we know `--matcher` was passed on the command line and we just source
# the file provided if it exists. Otherwise, we default to trying to source the
# `test_matcher` or `iot_matcher` files, which we can actually skip since we
# next try to source any file in the `$TESTDIR` which either ends in '.matcher'
# or '_matcher'.
if [ -n "${MATCHER:+1}" ]; then
  if [ -f "$MATCHER" ]; then
    source $MATCHER
  else
    error "invalid option file '$MATCHER'"
  fi
fi

for mfile in $(ls ${TESTDIR}/*_matcher ${TESTDIR}/*.matcher 2>/dev/null); do
  source $mfile
done

# Final Preparations
# ------------------
#
# Last tiny bit of argument parsing. The first argument to iot is the test
# file and the rest of the options denote suites or tests to run to run.
#
# The safe option copies the entire source code of the program and is thus
# likely to be slow, but its the only way to safely be able to concurrently
# edit the program while we're testing it.
[[ -f "${ROOTDIR}/${1}" ]] || error "expects program to test as argument"

if $safe; then
  cp "${ROOTDIR}/${1}" "${SANDBOXDIR}/program"
  PROGNAME="${SANDBOXDIR}/program"
else
  PROGNAME="${ROOTDIR}/${1}"
fi
shift

# We a place to concatenate our error messages that build up, so we create a
# `results` file to append to. In order to avoid collisions with test names
# we'll stick on our pid as well. We're also going to create an `immediate`
# results file as well, which will kind of act like a buffer to `results`. We
# `touch $results` so that when we try to cat it in the end of a passing test
# run we don't get an error.
results="${SANDBOXDIR}/iot-results-$$"
immediate_results="${SANDBOXDIR}/iot-immediate-$$"

touch $results

# Testing Function
# ----------------
#
# Here lies the heart of the code. The control flow is broken up into several
# subroutines that all share the same variables (I guess that's one benefit of
# the shell's unscoped variables?). This seperation of the code into logical
# units is purely for convenience and presentation.

# The first step in testing a given program is to determine where it's
# expected out and error files would be located. `testfile`, `suite` and
# `location` are all passed to `dotest` (the main testing function) and
# `get_locations` utilizes these arguments to figure out where the expect
# files are. If the `location` passed to `dotest` is "top" then we just check
# in the top level of the suite, otherwise we delve into the subdirectories.
# *Note:* these expect files may not exist - we're just trying to find out
# where they would be _if_ they did exist.
get_locations() {
  testname="$(basename $testfile)"
  testname="${testname%%.in}"

  if [ "$location" = "top" ]; then
    expect_out="${suite}/${testname}.out"
    expect_err="${suite}/${testname}.err"
  else # "in"
    expect_out="${suite}/out/${testname}"
    expect_err="${suite}/err/${testname}"
  fi
}

# The next step is to actually run the program with the test as input, saving
# the output streams in our `SANDBOXDIR`. `eval` shows it's ugly face here,
# but if the `COMMAND` that was passed in contains addition options (like
# `valgrind --leak-check=yes`, or something of that sort) then `eval` is
# necessary. If we're using `--safe` we're given a full path so we need to
# change the way we call the file.
run_test() {
  actual_out="${SANDBOXDIR}/${testname}.out"
  actual_err="${SANDBOXDIR}/${testname}.err"

  if [ -n "${COMMAND:+1}" ]; then
    eval "${COMMAND} $PROGNAME < $testfile > $actual_out 2> $actual_err"
  elif [ -x $PROGNAME ]; then
    if ! $safe; then
      eval "./${PROGNAME}  < $testfile > $actual_out 2> $actual_err"
    else
      eval "${PROGNAME}  < $testfile > $actual_out 2> $actual_err"
    fi
  else
    error "'$PROGNAME' is not executable, cannot run tests"
  fi
}

# `get_match_prefix` checks the testname and returns the name of the matcher to
# match it against, or an empty string if the test name actually has no matcher.
# If the matcher they specified doesn't happen to exit (`type` checks if the
# function is available) we simply set prefix to null so that `dotest` will do a
# normal diff. We can't immediately error out here on a bad matcher name since
# we don't specify any restrictions on the way a user names their files. They
# could name it 'my.super.cool.name' and we will be looking for a function
# called 'my_matcher' which may or may not exist, but thats not our problem
get_match_prefix() {
  prefix=$(expr "$testname" : "\([^.]*\)\..*")
  type -t "${prefix}_matcher" 1>/dev/null 2>&1 || {
    prefix=""
  }
}

# Now we need to actually perform the `diff`. Since we need to possibly
# compare both out and error streams we need to make a 'combined' file that
# holds both of these appended to each other, provided the expect files exist.
# If neither a test or output file is provided we're going to throw an error
# since it is likely a mistake by the user and not intentional (if the user
# expects no output or errors he should provide empty err and out files to
# make his intentions clear). `dotest` will check the exit status of this
# which in turn will be the exit value of the `diff`.
perform_diff() {
  out=false; err=false;
  combined_expect="${SANDBOXDIR}/${testname}.combined.expect"
  combined_result="${SANDBOXDIR}/${testname}.combined.result"

  if [ -f "$expect_out" ]; then
    cat $expect_out >> $combined_expect
    cat $actual_out >> $combined_result
    out=true
  fi

  if [ -f "$expect_err" ]; then
    cat $expect_err >> $combined_expect
    cat $actual_err >> $combined_result
    err=true
  fi

  if ! $out && ! $err; then
    error "no expected output or error files for $(basename ${suite})/${testname}"
  fi

  diff $combined_expect $combined_result >/dev/null 2>&1
}

# `perform_match` is a lot simpler than `perform_diff` since we pass all the
# work off to the matcher function. We set the out and err variables to true so
# the failing output gets printed - we don't really customize what the output is
# at this point in time. Potentially the matcher function could be responsible
# for an error message as well? By default whatever expected files we have are
# going to get printed.
perform_match(){
  out=false; err=false;
  [[ -f "$expect_out" ]] && out=true;
  [[ -f "$expect_err" ]] && err=true;
  eval "${prefix}_matcher $actual_out $actual_err $expect_out $expect_err 1>/dev/null 2>&1"
}

# Very straightforward chunk of code for the passing and failing message s- we
# simply print a different message depending on whether or not we've been
# passed the option `--verbose` or not.
passing_message() {
  if $verbose; then
    verbose_passmsg $testfile $count
  else
    passmsg $testfile $count
  fi
}

failing_message() {
  if $verbose; then
    verbose_failmsg $testfile $count
  else
    failmsg $testfile $count
  fi
}

# Abstracted from the next function, `failing_case`, this function expects an
# `out_file` and a `err_file` and decides what format to print them in. It
# relies on `out` and `err` which were set in `perform_diff` and simply save
# having to test `[ -f <file> ]` multiple times. If we get just an `out_file`,
# we dont print the 'stdout:' line since it is implied. However, one we get an
# error stream in the mix we need to distinguish between the 2.
failing_output() {
  out_file=$1; err_file=$2
  if $out && ! $err; then
    cat $out_file >> $immediate_results
  elif ! $out && $err; then
    pwarn "stderr:\n" >> $immediate_results
    cat $err_file >> $immediate_results
  else
    pwarn "stdout:\n" >> $immediate_results
    cat $out_file >> $immediate_results
    pwarn "stderr:\n" >> $immediate_results
    cat $err_file >> $immediate_results
  fi
}

# Not much different from above, however, this is called with a different
# format as the 'Expected' and 'Received' headers are not required since it is
# explicit with a diff.
failing_unified() {
  if $out && ! $err; then
    diff -u $expect_out $actual_out >> $immediate_results
  elif ! $out && $err; then
    pwarn "stderr:\n" >> $immediate_results
    diff -u $expect_err $actual_err >> $immediate_results
  else
    pwarn "stdout:\n" >> $immediate_results
    diff -u $expect_out $actual_out >> $immediate_results
    pwarn "stderr:\n" >> $immediate_results
    diff -u $expect_err $actual_err >> $immediate_results
  fi
}

# Most of the interesting stuff this function does was extracted to
# `failing_output`, but it's worth noting we are outputing everything to
# `immediate` until the end, where we then append it to the real `results`
# file. Also note we're adding in some spaces to indent our output. The most
# important line is the truncation of the `immediate_results` at the very end
# - without this our output would get incrementally bigger each time.
failing_case() {
  failing_message

  pfail "\n${failcount}) $(basename ${suite})/${testname}\n" >> $immediate_results

  if $out || $err; then
    if $unified; then
      failing_unified
    else
      pwarn "${BOLD}Expected:\n" >> $immediate_results
      failing_output $expect_out $expect_err

      pwarn "${BOLD}Received:\n" >> $immediate_results
      failing_output $actual_out $actual_err
    fi
  fi

  cat $immediate_results >> $results

  if $immediate; then
    echo >> $immediate_results
    sed 's/^/  /g' $immediate_results
  elif $sudden_death; then
    cat $results && exit 1
  fi

  cat /dev/null > $immediate_results
}

# Here's the function that is composed of all the above subroutines. We're
# passed `testfile`, `suite` and `location` and then we call the respective
# subs to do all the work. We make sure we check the `quiet` flag so that we
# don't output anything if the flag is set.
dotest() {
  testfile=$1; suite=$2; location=$3

  get_locations
  run_test

  get_match_prefix
  if [ -n "$prefix" ]; then
    perform_match
  else
    perform_diff
  fi

  if [ $? -eq 0 ]; then
    if ! $quiet; then
      passing_message
    fi
  else
    failcount=`expr $failcount + 1`
    if ! $quiet; then
      failing_case
    fi
  fi

  testcount=`expr $testcount + 1`
}

# Main Testing Loop
# -----------------
#
# We keep track of two counter variables in our test loop - `testcount` and
# `failcount`. `testcount` keeps track of the number of tests run and
# `failcount` keeps track of the number of tests which have failed. These are
# mainly useful for the summary message at the end, but we also use failcount
# as our exit code.
testcount=0
failcount=0

# If we're in quiet mode we just care about the exit code and don't need the
# chatty 'Started' message
if ! $quiet; then echo "Started"; fi

# We're going to loop through everything left standing on the command line and
# try to figure out what type of argument we have (pseudo path or entire test
# suite), ultimately passing each test file to `dotest` with either a 'top' or
# an 'in' argument signalling to `dotest` where it should look for expected
# output files.
#
# The first case (in order of increasing complication) is the case where we
# we're given a suite - in that case we're given a directory name and we just
# run the `dotest` function on each test file in that directory.
#
# The final case is the pseudo path - something of the form 'suite/path'. This
# kind of gets ugly. First we test of the suite directory even exists - we can
# leverage (abuse?) `dirname` to strip the suite name. We then check both
# styles for how test files can be defined, this time making use of `basename`
# to strip the other half of the pseudopath. We then have to impose an
# ordering on the potential test files found (ick! - TODO: better way?) before
# passing it off to `dotest`
for arg in $@; do

  if [ -d "${TESTDIR}/$arg" ]; then

    for file in $(find ${TESTDIR} -type f -path "${TESTDIR}/$arg/*.in"); do
      dotest $file "${TESTDIR}/$arg" "top"
    done

    for file in $(find ${TESTDIR} -type f -path "${TESTDIR}/$arg/in/*"); do
      dotest $file "${TESTDIR}/$arg" "in"
    done

  elif [ -d "${TESTDIR}/$(dirname $arg)" ] &&
       [ -f "${TESTDIR}/$(dirname $arg)/$(basename $arg).in" ] ||
       [ -f "${TESTDIR}/$(dirname $arg)/in/$(basename $arg)" ]; then

       suite="${TESTDIR}/$(dirname $arg)"
       if [ -f "$suite/$(basename $arg).in" ]; then
         dotest "$suite/$(basename $arg).in" $suite "top"
       else
         dotest "$suite/in/$(basename $arg)" $suite "in"
       fi

  else

    error "can't figure out what to do with '$arg'"

  fi

done

# Wrapping Up
# -----------
#
# Standard case finishing action (i.e. we didn't terminate early thanks to
# `--immediate` or `--sudden-death`) - we simply display the results and the
# statistics (passes vs. failures). We don't display the results when
# immediate is set since they've already all been shown.
if ! $quiet; then
  if ! $verbose; then echo; fi
  printf "Finished\n"

  if ! $immediate; then
    sed 's/^/  /g' $results
  fi

  if [ $failcount -eq 0 ]; then
      ppass "\n${testcount} test(s), ${failcount} failure(s)\n"
  else
      pfail "\n${testcount} test(s), ${failcount} failure(s)\n"
  fi
fi

exit $failcount

# Copyright
# ---------
#
# Copyright (C) [Kirk Scheibelhut](http://scheibo.com/about)<br />
# This is Free Software distributed under the MIT license.
:
