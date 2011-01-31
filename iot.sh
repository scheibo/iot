#!/bin/bash
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
#     $ make install
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
# We include this line as a safety precaution -  it's important to exit
# immediately if we run into any problems rather than potentially screwing
# anything up.
set -e

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
#/    -s, --sandboxdir=<dir>  change the default temp directory
#/    -t, --testdir=<dir>                change default test directory
#/    -r, --rootdir=<dir>                change default root directory
#/    -c, --command=<command>            use <command> to run the program
#/    -m, --matcher=<file>               use the custom matchers in <file>
#/
#/ Mode options:
#/    -i, --immediate                    immediately print diagnositc info
#/    -v, --verbose                      more verbose failure program msgs
#/    -x, --sudden-death                 stop after the first failed test
#/    -q, --quiet                        test and return exit code, no output
#/    -u, --unified                      use a unified diff for fail output
#/    --safe, --copy                     copy the source to allow for editting

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
  printf "$(basename $0): ${*}\n\n"
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
passmsg() { printf "."; }
failmsg() { printf "F"; }

# There is also the verbose options for the messages. Two things to note are
# how we manually include a newline and how we're normalizing the test file
# name to remove any leading path or .in cruft.
verbose_passmsg() {
  test_name="${1##/*/}"
  test_name="${test_name%%.in}"
  printf "Passed test: $test_name\n"
}
verbose_failmsg() {
  test_name="${1##/*/}"
  test_name="${test_name%%.in}"
  printf "Failed test: $test_name\n"
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
ppass() { printf "${GREEN}${1}${RESET}"; }
pwarn() { printf "${YELLOW}${1}${RESET}"; }
pfail() { printf "${RED}${1}${RESET}"; }

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
    -s|--sandboxdir|--tempdir)  SANDBOXDIR="$1";       shift 2 ;;
    --tempdir=*|--sandboxdir=*) SANDBOXDIR="${1##*=}"; shift   ;;

    -t|--testdir) TESTDIR="$1";                        shift 2 ;;
    --testdir=*)  TESTDIR="${1##*=}";                  shift   ;;

    -r|--root|--rootdir)  ROOTDIR="$1";                shift 2 ;;
    --root=*|--rootdir=*) ROOTDIR="${1##*=}";          shift   ;;

    -c|--run|--command|) COMMAND="$1";                 shift 2 ;;
    --run=*|--command=*) COMMAND="${1##*=}";           shift   ;;

    -i|--immediate|--imeadiate) immediate=true;        shift   ;;
    -v|-vv|--verbose)           verbose=true;          shift   ;;
    -q|--quiet|--silent)        quiet=true;            shift   ;;
    -u|--unified)               unified=true;          shift   ;;
    --copy|--safe|--concurrent) safe=true;             shift   ;;
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
# implementations of `mktmp(1)` require the string of X's and other don't, I
# had trouble installing `shocco(1)` on my machines because of this issue.
: ${TMPDIR:=/tmp}
: ${SANDBOXDIR:=$(
      if command -v mktemp 1>/dev/null 2>&1
      then
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
if [ -z "$SANDBOX" -o "$WORK" = "/" ]; then
  error "could not create a temporary sandbox directory"
fi

# Most importantly we're going to register an `EXIT` trap to clean up our temp # directory unless we're killed witbh `SIGKILL.`
#
# All of the code dealing with creating and cleaning up our temporary sandbox # directory comes at you straight out of [shocco][].
trap "rm -rf $SANDBOXDIR" 0

# 'Root' Directory
# ----------------
#
# Here we try to determine where the root directory of the project we're
# testing is. We first need to check if if `ROOTDIR` was already set by the
# user through the `--rootdir` command line option. This leverages the
# `${var:+val}` variable subsititution form which returns its value if
# `ROOTDIR` is defined and not null.We start by defaulting to the current
# directory - in the most basic case `iot` will be run from the top level
# directory. However, in order to provide more of a convenience for people
# using source control, we'll also check if we're in a `hg` or `git`
# repository, using the root of that repository as the root directory for the
# script. This allows us to call the script anywhere in the project and it
# will still be able to find the correct files.
if [ ${ROOTDIR:+1} -eq 1 ]; then
  ROOTDIR=`pwd`
  hg root 1>/dev/null 2>&1 && ROOTDIR=`hg root`
  git rev-parse --show-toplevel 1>/dev/null 2>&1 && ROOTDIR=`git rev-parse --show-toplevel`
fi

# Final Preparations
# ------------------
#
# Last tiny bit of argument parsing. The first argument to iot is the test
# file and the rest of the options denote suites or tests to run to run.
#
# The safe option copies the entire source code of the program and is thus
# likely to be slow, but its the only way to safely be able to concurrently
# edit the program while we're testing it. Using `rsync(1)` here might be a
# better idea if we're trying to do some autotesting-like behavior.
[[ -f "${ROOTDIR}/${1}" ]] || error "expects program to test as argument"

if $safe; then
  cp "${ROOTDIR}/${1}" "${SANDBOXDIR}/program"
  PROGNAME="${SANDBOXDIR}/program"
else
  PROGNAME="${ROOTDIR}/${1}"
fi

# We a place to concatenate our error messages that build up, so we create a
# `results` file to append to. In order to avoid collisions with test names
# we'll stick on our pid as well. We're also going to create an `immediate`
# results file as well, which will kind of act like a buffer to `results`.
results="${SANDBOXDIR}/iot-results-$$"
immediate_results="${SANDBOXDIR}/iot-immediate-$$"

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

  if "$location" = "top"; then
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
# necessary.
run_test() {
  actual_out="${SANDBOXDIR}/${testname}.out"
  actual_err="${SANDBOXDIR}/${testname}.err"

  if [ ${COMMAND:+1} -eq 1 ]; then
    eval ${COMMAND} $PROGNAME < $testfile > $actual_out 2> $actual_err
  elif [ -x $PROGNAME ]; then
    "./$PROGNAME"  < $testfile > $actual_out 2> $actual_err
  else
    error "$PROGNAME is not executable, cannot run tests"
  fi
}

# Now we need to actually perform the `diff`. Since we need to possibly
# compare both out and error streams we need to make a 'combined' file that
# holds both of these appended to each other, provided the expect files exist.
# `dotest` will check the exit status of this which in turn will be the exit
# value of the `diff`.
perform_diff() {
  combined_expect="${SANDBOXDIR}/${testname}.combined.expect"
  combined_result="${SANDBOXDIR}/${testname}.combined.result"

  [[ -f "$expect_out" ]] && cat "$expect_out" >> combined_expect
  [[ -f "$expect_err" ]] && cat "$expect_err" >> combined_expect
  cat "$actual_out" "$actual_err" >> combined_result

  diff $combined_expect $combined_result >/dev/null 2>&1
}

# Very straightforward chunk of code for the passing and failing message s- we
# simply print a different message depending on whether or not we've been
# passed the option `--verbose` or not.
passing_message() {
  if $verbose; then
    ppass `verbose_passmsg $testfile $count`
  else
    ppass `passmsg $testfile $count`
  fi
}

failing_message() {
  if $verbose; then
     ppass `verbose_failmsg $testfile $count`
   else
     ppass `failmsg $testfile $count`
   fi
}

# The code to build up the result and possibly display it.
failing_case() {
  failing_message

  printf "\n${failcount}) ${RED}${suite}/${testname}${RESET}\n" >>"$immediate"

  #BUILD THE MESSAGE: TODO

  sed 's/^/    /g' $immediate >> $results

  if $immediate then;
    sed 's/^/    /g' $immediate
  elif $suddendeath; then
    cat $results && exit 1
  fi
}

# Here's the function that is composed of all the above subroutines. We're
# passed `testfile`, `suite` and `location` and then we call the respective
# subs to do all the work. We make sure we check the `quiet` flag so that we
# don't output anything if the flag is set.
dotest() {
  testfile=$1; suite=$2; location=$3

  get_locations
  run_test
  perform_diff

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
# The default location we're going to be look for tests when resolving
# 'pseudo' paths and suite names. The `:=` form is used here again, it's
# similar to the `||=` in Ruby.
default="${ROOTDIR}/tests"
: ${TESTDIR:=default}

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
      dotest file "${TESTDIR}/$arg" "top"
    done

    for file in $(find ${TESTDIR} -type f -path "${TESTDIR}/$arg/in/*"); do
      dotest file "${TESTDIR}/$arg" "in"
    done

  elif [ -d "${TESTDIR}/$(dirname $arg)" ] &&
       [ -f "${TESTDIR}/$(dirname $arg)/$(basename $arg).in" ] ||
       [ -f "${TESTDIR}/$(dirname $arg)/in/$(basename $arg)" ]; then

       suite="${TESTDIR}/$(dirname $arg)"
       if [ -f "$suite/$(basename $arg).in" ]; then
         dotest "$suite/$(basename $arg).in" suite "top"
       else
         dotest "$suite/in/$(basename $arg)" suite "in"
       fi

  else

    error "can't figure out what to do with $arg"

  fi

done

# Wrapping Up
# -----------
#
# Standard case finishing action (i.e. we didn't terminate early thanks to
# `--immediate` or `--sudden-death`) - we simply display the results and the
# statistics (passes vs. failures). We don't display the results when
# immediate is set since they've already all been shown. The results are
# already conveniently indented from when they were created.
if ! $quiet; then
  echo "Finished"

  if ! $immediate; then
    cat $results
  fi

  if [ $failcount -eq 0 ]; then
      ppass "\n\n${testcount} tests, ${failcount} failures\n"
  else
      pfail "\n\n${testcount} tests, ${failcount} failures\n"
  fi
fi

exit $failcount

# Copyright
# ---------
#
# Copyright (C) [Kirk Scheibelhut](http://scheibo.com/about)<br />
# This is Free Software distributed under the MIT license.
: