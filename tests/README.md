# Testing iot

**WARNING**: the following may be somewhat of a 'mindfuck'

`iot(1)` is tested by essentially running `iot` on itself (how very meta). However, since `iot` does not read from `stdin` this isn't quite possible, but we can come close by making use of a trivial sample program. If we look in the Makefile we can see that the `test` task is defined:

    test:
        ./iot --ROOTDIR='./tests' iot-runner iot-suite

That is, we're running `iot` from within the `tests` directory on the special `iot-runner` with the `iot-suite`. The `iot-suite` is where the files for `iot`'s expected output reside. The input (inside `tests/iot-suite/in`, which is what `iot-runner` reads from stdin) is just a line which calls iot with various different arguments and/or options. `iot-runner` is actually just `eval`, and it runs the `iot` command inside of it, hence we are able to be running `iot` with itself and check it's output. The programs which the `tests/iot-suite/in` files are getting the nested `iot` to run on reside in the top level `tests` directory, and their in/out/err files results in suites inside this nested `tests` directory. The actually tests and output of these 'programs' are not important beyond the fact that they drive what output `iot` produces.

