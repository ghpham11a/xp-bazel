#include <cassert>
#include <iostream>
#include <nlohmann/json.hpp>

#include "main.h"

int main() {
    // Test that getMessage returns expected value
    assert(getMessage() == "Task complete from C++");

    // Test that nlohmann_json works
    nlohmann::json j;
    j["message"] = getMessage();
    assert(j["message"] == "Task complete from C++");

    std::cout << "PASSED: C++ task with nlohmann_json" << std::endl;
    return 0;
}
