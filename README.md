# C++ Test Generator Framework

## Description

This script produces a file called `Makefile.matrix`.
This is the Makefile that you'd use to build unit tests from C++ source code.

Each suite of tests is built from a single .cpp file that contains a number
  of directives.
Some of these directives are specified as alternates, so that for each alternate,
  a different test binary is compiled from a single original .cpp test source file.
When you specify a range of alternates in this way, you define a new dimension
  of the resulting test matrix, also known as an axis.
If you specify several axes, the script will compose these dimensions into a
  multidimensional matrix of test executables to build and run.

As an added feature, the script will generate a short uid descriptor that indexes
  and identifies a given test executable within the matrix.
This descriptor is appended to the filename of the test executable.

## Example

Say you have a file named `test1.cpp`:
```c++
/**
 * @cxxparams "-I.. -g"
 * @cxxparams [ -DDEBUG=0 -DDEBUG=0 ]
 **

#include <stdio.h>
...
```
The block comment delimited by `/** ..  **/` is combed out by the script and parsed.

On the second line, some @cxxparams are given in quotes.
These parameters are applied to *all* targets of this module.

On the third line, the script finds that there are two alternatives to the @cxxparams for this test module.
So, it will generate Makefile rules to build targets `test1-a.obj` and `test1-b.obj`, and
  subsequently executables named `test1-a` and `test1-b`.
Each will have an alternate definition of these parameters based on the values in the list.

Other axes can be defined for other stages of the compile/link/run testing process.
For example, there is an analogous `@ldparams` directive and you can also specify a list of input files as well.