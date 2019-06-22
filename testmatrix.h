#pragma once

#include <iostream>

#ifndef __EXE__
#error "The header testmatrix.h is intended to be used with the testmatrix framework."
#endif

inline void report_executable_parameters ()
{
	std::cout << "[" << __EXE__ << "-run" << __CASE__ "]\n";
	std::cout << "__CXXPARAMS__: " << __CXXPARAMS__ << "\n";
	std::cout << "__LDPARAMS__: " << __LDPARAMS__ << "\n";
}

