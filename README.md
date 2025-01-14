
# RISC-V Based CNN Hardware Accelerator 


## Overview
This repository contains the design and implementation of a RISC-V-based hardware accelerator to optimize convolutional neural network (CNN) workloads. The project focuses on improving the computational and energy efficiency of CNN operations, particularly 2D convolution and matrix multiplication tasks, by leveraging a custom hardware accelerator integrated into the RISC-V ecosystem using the Chipyard framework.

The project achieves significant speedup by implementing modular components such as multiply-accumulate (MAC) units, hierarchical memory structures, and a direct memory access (DMA) controller.

## Features
- **Hardware Accelerator Design:** Implements CNN operations like 2D convolution and matrix multiplication with modular subsystems.

- **RISC-V Integration:** Seamless interaction with the Rocket Chip processor via memory-mapped registers.

- **Performance Optimization:** Enhanced computational speed and energy efficiency through pipelined architecture and parallel processing.

- **Benchmarking:** Evaluation of accelerator performance against CPU baselines for resource-intensive tasks.

- **FPGA Implementation:** Tested on an AMD Artix-7 FPGA to measure timing and resource utilization.

## Project Highlights

- **MAC Units:** Parallelized pipeline for efficient computation.

- **Memory Management:** Hierarchical memory structures for optimized data access and processing.

- **Floating-Point Precision:** Single-precision arithmetic for higher computational accuracy.

- **Deep Learning Applications:** Supports CNN operations for tasks such as image classification and object detection.

## Architecture

The hardware accelerator is designed with the following components:

- **Memory Subsystem**: Banked memory for parallel access to input data and filter weights.

- **MAC Pipeline**: Eight multiplier units for element-wise operations and an adder tree for efficient summation.

- **FIFO**: Manages data flow and prevents bottlenecks during computation.

- **DMA Controller**: Facilitates data transfer between main memory and the accelerator.

  
## Results

- **Speedup**: Achieved up to 20x speedup for CNN workloads compared to a RISC-V Rocket Chip CPU.
  
- **Efficiency**: Reduced computational delay and enhanced throughput.

- **Accuracy**: Validated correctness with distortion metrics during benchmarking.


## Requirements

- **Chipyard Framework**: Chipyard for RISC-V design and integration.

- **FPGA Board**: AMD Artix-7 FPGA for testing and implementation.

- **Vivado**: Synthesis and analysis of the FPGA design.


## Setup and Usage

- **Clone the repository:** git clone https://github.com/username/riscv-cnn-accelerator.git


- **Install dependencies:**
  - Chipyard
  - Vivado 2024 or later.
 
- Set up the RISC-V toolchain for Chipyard.
 
- Run the provided scripts to initialize and synthesize the design.
 
- Deploy the design on the FPGA and perform benchmarking using the provided test cases.

  
## Benchmarking

- **Matrix Multiplication**: Tested for varying input sizes with consistent speedup over CPU implementations.
  
- **2D Convolution**: Demonstrated exponential reduction in run time for increasing input dimensions.


## Future Work
- Overlap read and write operations to improve memory access efficiency.

- Explore dynamic prefetching mechanisms for better data throughput.

- Integrate larger memory banks to handle more complex CNN tasks.
  
## Contributing
Contributions are welcome! Feel free to fork the repository and submit pull requests for enhancements or fixes.

## Acknowledgments
- University of Arizona, Department of Electrical and Computer Engineering

- **Project team members**: Dasol Ahn, Ayush Vaibhav Bhatti, Muhtasim Alam Chowdhury, Wilbert Hernandez, Owen Sowatzke
