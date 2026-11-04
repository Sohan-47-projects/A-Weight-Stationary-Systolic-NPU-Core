
#pragma once

#include <cstdint>
#include <vector>

namespace npu {

class Matrix {
public:
    int rows;
    int cols;
    std::vector<int16_t> data;

    Matrix(int rows, int cols);

    int16_t& operator()(int row, int col);
    int16_t operator()(int row, int col) const;
};

class ResultMatrix {
public:
    int rows;
    int cols;
    std::vector<int32_t> data;

    ResultMatrix(int rows, int cols);

    int32_t& operator()(int row, int col);
    int32_t operator()(int row, int col) const;
};

ResultMatrix matmul(const Matrix& A, const Matrix& B);

} // namespace npu
