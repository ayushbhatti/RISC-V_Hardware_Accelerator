// Memory-mapped register addresses (as defined by the hardware design)
#define ACCELERATOR_START_ADDR  0x80001000
#define ACCELERATOR_INPUT_ADDR  0x80001004
#define ACCELERATOR_OUTPUT_ADDR 0x80001008
#define ACCELERATOR_OP_TYPE     0x8000100C
#define ACCELERATOR_START       0x80001010

// Example function to start convolution operation
void start_convolution(uint32_t input_addr, uint32_t output_addr) {
    // Set input and output data addresses
    *((volatile uint32_t *) ACCELERATOR_INPUT_ADDR) = input_addr;
    *((volatile uint32_t *) ACCELERATOR_OUTPUT_ADDR) = output_addr;

    // Set operation type to "convolution" (assuming 0 is convolution)
    *((volatile uint32_t *) ACCELERATOR_OP_TYPE) = 0;

    // Start the hardware accelerator
    *((volatile uint32_t *) ACCELERATOR_START) = 1;
}

