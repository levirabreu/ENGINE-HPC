#include <iostream>

int main() {
    int s = 0;
    for (int i = 1; i <= 10; i++) {
        s += i;
    }
    std::cout << "C++ OK: soma 1..10 = " << s << std::endl;
    return 0;
}
