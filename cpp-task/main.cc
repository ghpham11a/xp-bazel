#include "main.h"
#include "subtask-a/subtask_a.h"
#include "subtask-b/subtask_b.h"
#include <iostream>
#include <nlohmann/json.hpp>

int main() {
    std::cout << "  (using nlohmann_json v" << NLOHMANN_JSON_VERSION_MAJOR
              << "." << NLOHMANN_JSON_VERSION_MINOR
              << "." << NLOHMANN_JSON_VERSION_PATCH
              << " — external BCR dependency)" << std::endl;
    std::cout << getMessageA() << std::endl;
    std::cout << getMessageB() << std::endl;
    std::cout << getMessage() << std::endl;
    return 0;
}
