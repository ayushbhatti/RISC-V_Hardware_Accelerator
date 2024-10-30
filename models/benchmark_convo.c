#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define IMAGE_SIZE 512  // Define the size of the input image (IMAGE_SIZE x IMAGE_SIZE)
#define KERNEL_SIZE 3   // Define the size of the kernel (KERNEL_SIZE x KERNEL_SIZE)

// Function to perform 2D convolution
void cpu_convolution(float image[IMAGE_SIZE][IMAGE_SIZE], float kernel[KERNEL_SIZE][KERNEL_SIZE], float output[IMAGE_SIZE][IMAGE_SIZE]) {
    int i, j, m, n;
    int kernel_radius = KERNEL_SIZE / 2;

    // Iterate over each pixel in the output image
    for (i = 0; i < IMAGE_SIZE; i++) {
        for (j = 0; j < IMAGE_SIZE; j++) {
            float sum = 0.0;

            // Apply the kernel to the surrounding pixels
            for (m = -kernel_radius; m <= kernel_radius; m++) {
                for (n = -kernel_radius; n <= kernel_radius; n++) {
                    // Check if the indices are within bounds
                    if ((i + m >= 0 && i + m < IMAGE_SIZE) && (j + n >= 0 && j + n < IMAGE_SIZE)) {
                        sum += image[i + m][j + n] * kernel[m + kernel_radius][n + kernel_radius];
                    }
                }
            }

            // Store the result in the output matrix
            output[i][j] = sum;
        }
    }
}

int main() {
    // Initialize image and kernel arrays
    float image[IMAGE_SIZE][IMAGE_SIZE];
    float kernel[KERNEL_SIZE][KERNEL_SIZE];
    float output[IMAGE_SIZE][IMAGE_SIZE];

    // Populate the image with random values
    for (int i = 0; i < IMAGE_SIZE; i++) {
        for (int j = 0; j < IMAGE_SIZE; j++) {
            image[i][j] = (float)(rand() % 256);  // Random values between 0 and 255
        }
    }

    // Define a simple 3x3 kernel (e.g., edge detection kernel)
    kernel[0][0] = -1; kernel[0][1] = -1; kernel[0][2] = -1;
    kernel[1][0] = -1; kernel[1][1] =  8; kernel[1][2] = -1;
    kernel[2][0] = -1; kernel[2][1] = -1; kernel[2][2] = -1;

    // Start measuring execution time
    clock_t start = clock();

    // Perform the convolution
    cpu_convolution(image, kernel, output);

    // Stop measuring execution time
    clock_t end = clock();

    // Calculate and print the execution time
    double time_spent = (double)(end - start) / CLOCKS_PER_SEC;
    printf("Execution time (CPU convolution): %f seconds\n", time_spent);

    return 0;
}

