
#include <array>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#include "xsi.h"
#include "xsi_loader.h"

namespace npu_backend {

constexpr int ROWS = 4;
constexpr int COLS = 4;
constexpr int STREAM_CYCLES = 10;

using WeightTile = std::array<int16_t, ROWS * COLS>;
using ActivationStream =
    std::array<std::array<int16_t, ROWS>, STREAM_CYCLES>;
using OutputTile = std::array<int32_t, ROWS * COLS>;

class Backend {
public:

    struct Ports {
        int clk, rst_n;
        int start;

        int weight_tile_addr;
        int output_tile_addr;

        int weight_wr_en;
        int weight_wr_addr;
        int weight_wr_data;

        int A_in;
        int input_done;

        int busy;
        int done;
        int compute_active;

        int output_rd_en;
        int output_rd_addr;
        int output_rd_data;
        int output_rd_valid;
    } p{};

    Backend(
        const std::string& design,
        const std::string& kernel
    ) : loader(design, kernel) {

        s_xsi_setup_info setup;
        std::memset(&setup, 0, sizeof(setup));

        loader.open(&setup);

        if (!loader.isopen())
            throw std::runtime_error("XSim failed to open");

        bindPorts();
        reset();
    }

    ~Backend() {
        if (loader.isopen())
            loader.close();
    }

    Backend(const Backend&) = delete;
    Backend& operator=(const Backend&) = delete;

    void execute(
        const WeightTile& weights,
        const ActivationStream& activations,
        OutputTile& output,
        int weightAddress,
        int outputAddress
    ) {

       
        loadWeights(weights, weightAddress);

        put(p.weight_tile_addr, weightAddress);
        put(p.output_tile_addr, outputAddress);

        
        put(p.start, 1);
        tick();

        put(p.start, 0);

        waitForCompute();

        
        for (int cycle = 0; cycle < STREAM_CYCLES; ++cycle) {

            std::vector<s_xsi_vlog_logicval> bus(2);

            for (int lane = 0; lane < ROWS; ++lane) {

                uint16_t value =
                    static_cast<uint16_t>(
                        activations[cycle][lane]
                    );

                // Lane 0 occupies bits [63:48].
                setBits(
                    bus,
                    (ROWS - 1 - lane) * 16,
                    16,
                    value
                );
            }

            putVector(p.A_in, bus);

           
            put(p.input_done, cycle == 6 ? 1 : 0);

            tick();
        }

        put(p.input_done, 0);

        waitForDone();

        
        output = readOutput(outputAddress);

        
        tick();
    }

private:

    Xsi::Loader loader;

    
    int port(const char* name) {

        int id = loader.get_port_number(name);

        if (id < 0) {
            throw std::runtime_error(
                std::string("Missing XSI port: ") + name
            );
        }

        return id;
    }

    void bindPorts() {

        p.clk = port("clk");
        p.rst_n = port("rst_n");

        p.start = port("start");

        p.weight_tile_addr = port("weight_tile_addr");
        p.output_tile_addr = port("output_tile_addr");

        p.weight_wr_en = port("weight_wr_en");
        p.weight_wr_addr = port("weight_wr_addr");
        p.weight_wr_data = port("weight_wr_data");

        p.A_in = port("A_in");
        p.input_done = port("input_done");

        p.busy = port("busy");
        p.done = port("done");
        p.compute_active = port("compute_active");

        p.output_rd_en = port("output_rd_en");
        p.output_rd_addr = port("output_rd_addr");
        p.output_rd_data = port("output_rd_data");
        p.output_rd_valid = port("output_rd_valid");
    }

    
    void put(int id, uint32_t value) {

        s_xsi_vlog_logicval v{};

        v.aVal = value;
        v.bVal = 0;

        loader.put_value(id, &v);
    }

    uint32_t get(int id) {

        s_xsi_vlog_logicval v{};

        loader.get_value(id, &v);

        return v.aVal;
    }

    void putVector(
        int id,
        const std::vector<s_xsi_vlog_logicval>& value
    ) {
        loader.put_value(id, value.data());
    }

    std::vector<s_xsi_vlog_logicval> getVector(
        int id,
        int words
    ) {

        std::vector<s_xsi_vlog_logicval> value(words);

        loader.get_value(id, value.data());

        return value;
    }

    // ------------------------------------------------
    // BIT PACKING
    // ------------------------------------------------

    static void setBits(
        std::vector<s_xsi_vlog_logicval>& bus,
        int lsb,
        int width,
        uint32_t value
    ) {

        for (int bit = 0; bit < width; ++bit) {

            if ((value >> bit) & 1U) {

                int position = lsb + bit;

                bus[position / 32].aVal |=
                    (1U << (position % 32));
            }
        }
    }

    static uint32_t getBits(
        const std::vector<s_xsi_vlog_logicval>& bus,
        int lsb,
        int width
    ) {

        uint32_t value = 0;

        for (int bit = 0; bit < width; ++bit) {

            int position = lsb + bit;

            if ((bus[position / 32].aVal >>
                 (position % 32)) & 1U) {

                value |= (1U << bit);
            }
        }

        return value;
    }

    
    void tick() {

        put(p.clk, 0);
        loader.run(5000);

        put(p.clk, 1);
        loader.run(5000);

        int status = loader.get_status();

        if (status != xsiNormal) {

            const char* error = loader.get_error_info();

            throw std::runtime_error(
                error ? error : "XSim reported an error"
            );
        }
    }

    

    void reset() {

        put(p.clk, 0);
        put(p.rst_n, 0);

        put(p.start, 0);
        put(p.weight_wr_en, 0);
        put(p.input_done, 0);
        put(p.output_rd_en, 0);

        for (int i = 0; i < 4; ++i)
            tick();

        put(p.rst_n, 1);

        for (int i = 0; i < 2; ++i)
            tick();
    }

    
    void loadWeights(
        const WeightTile& weights,
        int address
    ) {

        // 256-bit tile = 8 XSI words.
        std::vector<s_xsi_vlog_logicval> bus(8);

        for (int lane = 0; lane < 16; ++lane) {

            int bitPosition = 256 - (lane + 1) * 16;

            uint16_t value =
                static_cast<uint16_t>(weights[lane]);

            setBits(bus, bitPosition, 16, value);
        }

        put(p.weight_wr_addr, address);
        putVector(p.weight_wr_data, bus);

        put(p.weight_wr_en, 1);

        tick();

        put(p.weight_wr_en, 0);
    }

    
    void waitForCompute() {

        for (int i = 0; i < 100; ++i) {

            if (get(p.compute_active))
                return;

            tick();
        }

        throw std::runtime_error(
            "Timeout waiting for COMPUTE"
        );
    }

    void waitForDone() {

        for (int i = 0; i < 100; ++i) {

            if (get(p.done))
                return;

            tick();
        }

        throw std::runtime_error(
            "Timeout waiting for DONE"
        );
    }

    
    OutputTile readOutput(int address) {

        put(p.output_rd_addr, address);
        put(p.output_rd_en, 1);

        tick();

        put(p.output_rd_en, 0);

        if (!get(p.output_rd_valid)) {

            tick();

            if (!get(p.output_rd_valid)) {
                throw std::runtime_error(
                    "Output read timeout"
                );
            }
        }

        
        auto bus = getVector(p.output_rd_data, 16);

        OutputTile result{};

        for (int lane = 0; lane < 16; ++lane) {

            int bitPosition = 512 - (lane + 1) * 32;

            uint32_t bits = getBits(
                bus,
                bitPosition,
                32
            );

            std::memcpy(
                &result[lane],
                &bits,
                sizeof(int32_t)
            );
        }

        return result;
    }
};

} // namespace npu_backend




extern "C" {

void* npu_xsi_create(
    const char* design,
    const char* kernel
) {

    return new npu_backend::Backend(
        design,
        kernel
    );
}

void npu_xsi_destroy(void* handle) {

    delete static_cast<npu_backend::Backend*>(handle);
}

void npu_xsi_execute(
    void* handle,
    const int16_t* weights,
    const int16_t* activations,
    int32_t* output,
    int weightAddress,
    int outputAddress
) {

    auto* backend =
        static_cast<npu_backend::Backend*>(handle);

    npu_backend::WeightTile w{};
    npu_backend::ActivationStream a{};
    npu_backend::OutputTile o{};

    for (int i = 0; i < 16; ++i)
        w[i] = weights[i];

    for (int cycle = 0; cycle < 10; ++cycle) {

        for (int lane = 0; lane < 4; ++lane) {

            a[cycle][lane] =
                activations[cycle * 4 + lane];
        }
    }

    backend->execute(
        w,
        a,
        o,
        weightAddress,
        outputAddress
    );

    for (int i = 0; i < 16; ++i)
        output[i] = o[i];
}

} // extern "C"
