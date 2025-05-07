#include "include/julia/julia.h"
#include <iostream>
JULIA_DEFINE_FAST_TLS

int main() {
    std::cout << "PATH: " << getenv("PATH") << std::endl;
    jl_init_with_image("bin","../my_sysimage.so");
    jl_eval_string("display(\"hello\")");
}