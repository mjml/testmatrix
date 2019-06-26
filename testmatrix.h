#pragma once

#include <iostream>

#ifndef __EXE__
#error "The header testmatrix.h is intended to be used with the testmatrix framework."
#endif

inline void report_executable_parameters ()
{
	std::cout << "[" << __EXE__ << "]\n";
	std::cout << "__CXXPARAMS__: " << __CXXPARAMS__ << std::endl;
	std::cout << "__LDPARAMS__: " << __LDPARAMS__ << std::endl;
	std::cout << std::flush;
}

inline void report_success ()
{
	
}

inline void report_error (const std::exception& e)
{
	std::cerr << e.what() << "\n";
	std::cerr.flush();
}
