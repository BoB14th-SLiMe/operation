#include <iostream>
#include <vector>
#include <algorithm>
#include <string>

struct Record {
    std::string timestamp;
    int order;
};

int main() {
    std::vector<Record> records = {
        {"2025-09-22T02:52:00.771679Z", 1},  // Request
        {"2025-09-22T02:52:00.776322Z", 2},  // Response register 0 (addr=12)
        {"2025-09-22T02:52:00.776322Z", 3},  // Response register 1 (addr=13)
        {"2025-09-22T02:52:00.776322Z", 4},  // Response register 2 (addr=14)
        {"2025-09-22T02:52:00.798610Z", 5},  // Next request
    };
    
    std::cout << "Before sort:" << std::endl;
    for (const auto& r : records) {
        std::cout << "  " << r.timestamp << " order=" << r.order << std::endl;
    }
    
    // Using std::sort (unstable)
    std::vector<Record> records_unstable = records;
    std::sort(records_unstable.begin(), records_unstable.end(),
        [](const Record& a, const Record& b) {
            return a.timestamp < b.timestamp;
        });
    
    std::cout << "\nAfter std::sort (unstable):" << std::endl;
    for (const auto& r : records_unstable) {
        std::cout << "  " << r.timestamp << " order=" << r.order << std::endl;
    }
    
    // Using std::stable_sort
    std::vector<Record> records_stable = records;
    std::stable_sort(records_stable.begin(), records_stable.end(),
        [](const Record& a, const Record& b) {
            return a.timestamp < b.timestamp;
        });
    
    std::cout << "\nAfter std::stable_sort (stable):" << std::endl;
    for (const auto& r : records_stable) {
        std::cout << "  " << r.timestamp << " order=" << r.order << std::endl;
    }
    
    return 0;
}
