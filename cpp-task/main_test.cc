#include <cassert>
#include <iostream>
#include <string>

#include "main.h"

int main() {
    assert(getMessage() == "Task complete from C++");
    std::cout << "PASSED: Task complete from C++" << std::endl;
    return 0;
}
