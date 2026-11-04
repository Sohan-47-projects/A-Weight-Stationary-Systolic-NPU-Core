# A Weight Stationary Systolic NPU Core 

[![HDL](https://img.shields.io/badge/HDL-SystemVerilog-blue)](#verification--closed-loop-co-simulation)
[![Architecture](https://img.shields.io/badge/Architecture-Systolic_Array_(Weight--Stationary)-orange)](#hardware-datapath)


A custom Neural Processing Unit (NPU) core built from scratch in SystemVerilog and C++. It features a 4×4 weight-stationary INT16/INT32 systolic array, dedicated tile buffers, a deterministic FSM controller, and a software matrix-tiling engine capable of computing arbitrary matrix dimensions.

### A Quick Note on the Simulation Setup
This project demonstrates a functional NPU core alongside a tiny misadventure of mine trying to call simulated hardware directly from a custom made C++ library. The C++-to-RTL bridge currently relies on the AMD Vivado Xilinx Simulation Interface (`XSI`), which makes the software side heavily dependent on a local Vivado installation. 

If you want to simulate the RTL yourself, **I strongly recommend using Verilator instead**. Once I get my hands on a physical FPGA board, I will replace the simulation backend with actual hardware drivers and an AXI bus wrapper. Until then, here is the co-simulation implementation, feel free to ignore the XSI-dependent files (`xsi_backend.*`, `npu_xsi_top.sv`) unless you already have the Vivado toolchain installed.

## System Architecture

<img width="1536" height="1024" alt="7d4d7a9f-c018-4d5b-ba7b-42643766cda8" src="https://github.com/user-attachments/assets/d8ba7498-8972-42db-8fa6-a827625d3d66" />


### Hardware Datapath (`rtl/`)
- **Processing Elements (`PE.sv`):** Each PE holds a stationary 16-bit weight (`W`), multiplies it against a streaming 16-bit activation (`A`), and accumulates the product into a vertically propagating 32-bit partial sum:
  `PS_out = PS_in + (A × W)`
* **Systolic Array (`systolic.sv`):** 16 PEs arranged in a 4×4 grid. Activations flow left-to-right; partial sums flow top-to-bottom:

<img width="1024" height="765" alt="systoli" src="https://github.com/user-attachments/assets/e9d9593d-1a2f-46f1-950b-a4d0660b1e56" />



* **Weight & Output Buffers (`weight_buffer.sv`, `output_buffer.sv`):**
  * **Weight Buffer:** 64 entries × 256 bits (16 × INT16 weights per tile, 16 Kb total), addressed via a 6-bit index.
  * **Output Buffer:** 64 entries × 512 bits (16 × INT32 results per tile, 32 Kb total).
- **Controller (`accelerator_controller.sv`):** A 7-state FSM (`IDLE` → `READ_WEIGHT` → `WAIT_WEIGHT` → `LOAD_ARRAY` → `COMPUTE` → `WRITE_OUTPUT` → `DONE`) that orchestrates weight loading, a 10-cycle skewed activation window, and output capture.

### Skewing & Timing Schedule
To align wavefronts across the 4×4 grid, row *r* activations are delayed by *r* cycles (`A_input[r][t] = A[t - r][r]`). Output partial sums exit the bottom of column *c* for row *i* at deterministic cycle offsets, allowing the controller to filter out invalid intermediate values:

> **t = i + c + (ROWS - 1) + PE_LAT**

## Software Tiling & Scheduling (`src/`)

The C++ runtime exposes a clean API (`npu::ResultMatrix C = npu::matmul(A, B);`) that abstracts hardware orchestration away from the caller:
1. **Arbitrary Dimension Decomposition:** Partitions `A(M×K) × B(K×N)` into `ceil(M/4) × ceil(K/4) × ceil(N/4)` hardware passes.
2. **Boundary Padding:** Automatically zero-pads incomplete edge tiles when `M`, `K`, or `N` are not multiples of 4.
3. **Reduction Accumulation:** Accumulates INT32 partial sums in host memory across the inner tile dimension:
   > `C_tile = Σ (A_tile × B_tile)`
# Syntax 
```cpp
#include "npu.hpp"

// A: M x K, B: K x N (arbitrary dimensions, INT16)
npu::ResultMatrix C = npu::matmul(A, B);
 ```

## Verification & Synthesis

### Functional Verification
Tested end-to-end on non-multiple dimensions (`A(13×11) × B(11×9) = C(13×9)`), requiring 4 × 3 × 3 = 36 hardware tile passes across the XSI co-simulation bridge.


<img width="1221" height="600" alt="Screenshot" src="https://github.com/user-attachments/assets/ef4b9beb-e568-49e5-a3df-ca129ec31b37" />


### Preliminary Synthesis Utilization (Xilinx Zynq-7020)
Synthesized in Vivado 2019.1 targeting `xc7z020clg400-1` (`npu_xsi_top`):

| Resource | Used | Available | Utilization | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Slice LUTs** | 658 | 53,200 | 1.24% | Logic only (0 LUTRAM) |
| **Slice Registers** | 1,058 | 106,400 | 0.99% | 1,056 FDCE, 2 FDRE flip-flops |
| **DSP48E1** | 16 | 220 | 7.27% | 1-to-1 mapping with the 16 MAC PEs |
| **Block RAM Tiles** | 11.5 | 140 | 8.21% | 11× RAMB36E1 + 1× RAMB18E1 |
| **Bonded IOB** | 866 | 125 | 692.80% | Unwrapped wide XSI simulation buses |

*Note: The 866 IOB count is an artifact of exposing flattened 256-bit/512-bit simulation buses at the top module (`npu_xsi_top.sv`) for direct XSI probing. Wrapping the core in a standard AXI4-Lite/AXI-Stream interface will drop pin utilization to normal physical limits.*

## Repository Structure

```text
custom-npu/
├── rtl/
│   ├── PE.sv                       # INT16 MAC processing element
│   ├── systolic.sv                 # 4x4 weight-stationary array
│   ├── weight_buffer.sv            # 64-tile weight memory (256-bit wide)
│   ├── output_buffer.sv            # 64-tile output memory (512-bit wide)
│   ├── accelerator_controller.sv   # 7-state control & de-skew FSM
│   └── npu_xsi_top.sv              # Flattened wrapper for Vivado XSI
├── src/
│   ├── npu.hpp / npu.cpp           # Public matrix API & software tiling engine
│   └── xsi_backend.hpp / .cpp      # Vivado XSI C++ simulation bridge
└── example/
    └── example.cpp                 # End-to-end 13x11 * 11x9 verification test
```

## Building & Running (Vivado XSI Co-Simulation)

If you have AMD Vivado (tested on 2019.1) and MinGW-w64 (`g++`) installed on Windows:

1. **Elaborate the RTL into an XSI Kernel:**
   Compile the `rtl/` sources in Vivado to generate the simulation DLL (`xsim.dir/npu_xsi_sim/xsimk.dll`).
2. **Add Vivado Runtime Libraries to PATH:**
   ```powershell
   $env:PATH = "D:\vivado\Vivado\2019.1\lib\win64.o;$env:PATH"
   ```
3. **Compile the Host Application:**
   *(Requires `xsi_loader.cpp` and headers from your local `<Vivado>/data/xsim/include` directory)*
   ```powershell
   g++ -std=c++17 -O2 `
       -I ./src `
       -I D:\vivado\Vivado\2019.1\data\xsim\include `
       src/npu.cpp src/xsi_backend.cpp example/example.cpp xsi_loader.cpp `
       -o example.exe
   ```
4. **Run:**
   ```powershell
   .\example.exe
   ```

## Future Work
* Add an **AXI4-Lite / AXI-DMA** wrapper to replace the wide XSI top-level ports and bring IOB count within physical FPGA constraints.
* Deploy onto a physical Zynq-7020 board with a bare-metal/Linux C++ driver.
* Implement double-buffered weight loading to overlap data transfer with compute.
