
#include <iostream>
#include <cstdint>
#include <stdexcept>

#include "npu.hpp"

int main() {

    constexpr int M = 13;
    constexpr int K = 11;
    constexpr int N = 9;

    try {

        

        std::cout << "A: " << M << " x " << K << '\n';
        std::cout << "B: " << K << " x " << N << '\n';
        std::cout << "C: " << M << " x " << N << "\n\n";

        
        npu::Matrix A(M, K);
        npu::Matrix B(K, N);

        for (int i = 0; i < M; ++i) {
            for (int j = 0; j < K; ++j) {
                A(i, j) = static_cast<int16_t>(
                    ((i * 3 + j * 2) % 11) - 5
                );
            }
        }

        for (int i = 0; i < K; ++i) {
            for (int j = 0; j < N; ++j) {
                B(i, j) = static_cast<int16_t>(
                    ((i * 5 + j * 3) % 13) - 6
                );
            }
        }

        
        std::cout << "Running NPU...\n";

        npu::ResultMatrix C = npu::matmul(A, B);

        std::cout << "NPU execution completed.\n\n";

        
        npu::ResultMatrix reference(M, N);

        for (int i = 0; i < M; ++i) {
            for (int j = 0; j < N; ++j) {

                int64_t sum = 0;

                for (int k = 0; k < K; ++k) {
                    sum +=
                        static_cast<int64_t>(A(i, k)) *
                        static_cast<int64_t>(B(k, j));
                }

                reference(i, j) =
                    static_cast<int32_t>(sum);
            }
        }

        

        int errors = 0;

        for (int i = 0; i < M; ++i) {
            for (int j = 0; j < N; ++j) {

                if (C(i, j) != reference(i, j)) {

                    std::cout
                        << "MISMATCH C["
                        << i << "][" << j << "]"
                        << " | NPU: " << C(i, j)
                        << " | CPU: " << reference(i, j)
                        << '\n';

                    ++errors;
                }
            }
        }

    

        std::cout << "\nNPU RESULT:\n";

        for (int i = 0; i < M; ++i) {
            for (int j = 0; j < N; ++j) {
                std::cout.width(7);
                std::cout << C(i, j);
            }

            std::cout << '\n';
        }

       

        if (errors == 0) {
            std::cout << "PASS: ALL "
                      << M * N
                      << " OUTPUT ELEMENTS MATCH.\n";
        }
        else {
            std::cout << "FAIL: "
                      << errors
                      << " MISMATCHES FOUND.\n";
        }

    

        return errors == 0 ? 0 : 1;
    }
    catch (const std::exception& e) {

        std::cerr << "\nNPU ERROR: " << e.what() << '\n';

        return 1;
    }
}
