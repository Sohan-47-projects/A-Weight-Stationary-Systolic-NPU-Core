
#include "npu.hpp"

#include <cstdint>
#include <stdexcept>
#include <limits>
#include <string>

extern "C" {
    void* npu_xsi_create(const char* design, const char* kernel);
    void npu_xsi_destroy(void* handle);

    void npu_xsi_execute(
        void* handle,
        const int16_t* weights,
        const int16_t* activations,
        int32_t* output,
        int weightAddress,
        int outputAddress
    );
}

namespace npu {



Matrix::Matrix(int r, int c)
    : rows(r), cols(c),
      data(static_cast<size_t>(r) * c, 0) {

    if (r <= 0 || c <= 0)
        throw std::invalid_argument("Invalid matrix dimensions");
}

int16_t& Matrix::operator()(int r, int c) {
    return data.at(static_cast<size_t>(r) * cols + c);
}

int16_t Matrix::operator()(int r, int c) const {
    return data.at(static_cast<size_t>(r) * cols + c);
}

ResultMatrix::ResultMatrix(int r, int c)
    : rows(r), cols(c),
      data(static_cast<size_t>(r) * c, 0) {

    if (r <= 0 || c <= 0)
        throw std::invalid_argument("Invalid result dimensions");
}

int32_t& ResultMatrix::operator()(int r, int c) {
    return data.at(static_cast<size_t>(r) * cols + c);
}

int32_t ResultMatrix::operator()(int r, int c) const {
    return data.at(static_cast<size_t>(r) * cols + c);
}



namespace {

constexpr int TILE = 4;
constexpr int STREAM_CYCLES = 10;

constexpr const char* DESIGN_LIBRARY =
    "xsim.dir/npu_xsi_sim/xsimk.dll";

constexpr const char* KERNEL_LIBRARY =
    "D:/vivado/Vivado/2019.1/lib/win64.o/librdi_simulator_kernel.dll";

class Hardware {
public:
    void* handle;

    Hardware() {
        handle = npu_xsi_create(
            DESIGN_LIBRARY,
            KERNEL_LIBRARY
        );

        if (!handle)
            throw std::runtime_error("Could not initialize NPU hardware");
    }

    ~Hardware() {
        if (handle)
            npu_xsi_destroy(handle);
    }

    Hardware(const Hardware&) = delete;
    Hardware& operator=(const Hardware&) = delete;

    void execute(
        const int16_t* weights,
        const int16_t* activations,
        int32_t* output
    ) {
        npu_xsi_execute(
            handle,
            weights,
            activations,
            output,
            0,
            0
        );
    }
};



void makeWeightTile(
    const Matrix& B,
    int kBase,
    int nBase,
    int16_t* tile
) {
    for (int r = 0; r < TILE; ++r) {
        for (int c = 0; c < TILE; ++c) {
            int k = kBase + r;
            int n = nBase + c;

            tile[r * TILE + c] =
                (k < B.rows && n < B.cols) ? B(k, n) : 0;
        }
    }
}


void makeActivationStream(
    const Matrix& A,
    int mBase,
    int kBase,
    int16_t* stream
) {
    for (int i = 0; i < STREAM_CYCLES * TILE; ++i)
        stream[i] = 0;

    
    for (int m = 0; m < TILE; ++m) {
        for (int k = 0; k < TILE; ++k) {
            int globalM = mBase + m;
            int globalK = kBase + k;

            int cycle = m + k;

            if (globalM < A.rows && globalK < A.cols) {
                stream[cycle * TILE + k] =
                    A(globalM, globalK);
            }
        }
    }
}

}



ResultMatrix matmul(const Matrix& A, const Matrix& B) {

    if (A.cols != B.rows)
        throw std::invalid_argument(
            "A.cols must equal B.rows"
        );

    ResultMatrix C(A.rows, B.cols);

    Hardware hardware;

    const int mTiles = (A.rows + TILE - 1) / TILE;
    const int nTiles = (B.cols + TILE - 1) / TILE;
    const int kTiles = (A.cols + TILE - 1) / TILE;

    for (int mt = 0; mt < mTiles; ++mt) {
        for (int nt = 0; nt < nTiles; ++nt) {

            int32_t accumulated[16] = {};

            for (int kt = 0; kt < kTiles; ++kt) {

                const int mBase = mt * TILE;
                const int nBase = nt * TILE;
                const int kBase = kt * TILE;

                int16_t weights[16] = {};
                int16_t activations[STREAM_CYCLES * TILE] = {};
                int32_t partial[16] = {};

                makeWeightTile(
                    B, kBase, nBase, weights
                );

                makeActivationStream(
                    A, mBase, kBase, activations
                );

                
                hardware.execute(
                    weights,
                    activations,
                    partial
                );

                for (int i = 0; i < 16; ++i) {
                    const int64_t sum =
                        static_cast<int64_t>(accumulated[i]) +
                        partial[i];

                    if (sum < std::numeric_limits<int32_t>::min() ||
                        sum > std::numeric_limits<int32_t>::max()) {
                        throw std::overflow_error(
                            "INT32 accumulation overflow"
                        );
                    }

                    accumulated[i] = static_cast<int32_t>(sum);
                }
            }

            for (int r = 0; r < TILE; ++r) {
                for (int c = 0; c < TILE; ++c) {

                    const int globalR = mt * TILE + r;
                    const int globalC = nt * TILE + c;

                    if (globalR < C.rows && globalC < C.cols) {
                        C(globalR, globalC) =
                            accumulated[r * TILE + c];
                    }
                }
            }
        }
    }

    return C;
}

} 
