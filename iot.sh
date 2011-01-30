#!/bin/bash
# **iot** serves as a testing 'framework' for the times when you only care
# that given a certain input, a certain output is produced. `iot` tries to be
# a simple solution to creating and managing test suites in this limited
# environment. The basic idea behind `iot` is that it runs a given program and
# saves the output (and error) streams, comparing them to the expected output
# (and error). iot can handle running entire suites of such tests (i.e.
# directories on input files), or simply individual tests.
#
# Installing `iot` is simple, simply clone the repository and copy (or link)
# the 'iot' file to a location on your `PATH` (like `/usr/local`, for
# example).
#
#     $ git clone git://github.com/scheibo/iot.git
#     $ cd iot
#     $ [sudo] cp iot /bin/somewhere/on/your/path
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

# Usage and Prerequisites
# -----------------------
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

# Here's our magic usage function, pretty much straight from shocco. We parse
# our own file for our comment leader and then print the stripped message.
usage() {
  grep '^#/' <"$0" | cut -c4-
}

# For the error function we print whatever argument we're given and the usage
# block. One problem that could result from the use of `exit 1` is that
# another script might misinterpret this to mean a single test failed (since
# usually the fail count is the exit code). Changing status with something
# like 125 might help, but that's just delaying the issue.
error() {
  printf "${*}\n\n"
  usage
  exit 1
}

# Option Processing
# -----------------
#
# The code for option processing is pretty self explanatory, just a loop
# through the command line arguments, assigning variables and shifting as we
# go. The constants determining the path begin undefined - we adjust them
# later on if they haven't been set by the user. All of our booleans denote
# exceptional cases, so they all start out as false unless changed by the
# user.
SANDBOXDIR=
TESTDIR=
ROOTDIR=
COMMAND=
immediate=false
verbose=false
sudden_death=false
quiet=false
unified=false

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
# fan of arbitrary aligning of various lines, but since option parsing is so
# repetitive and the code's job is so self explanatory we can save some screen
# real estate here.
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
    -x|--sudden-death|--sudden_death|--suddendeath)
                                sudden_death=true;     shift   ;;

    -h|--help|'-?'|'--?') usage && exit 0                      ;;
    -*) error "Unrecognized option: ${1}"                      ;;
    *) break                                                   ;;
  esac
done




