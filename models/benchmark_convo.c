#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define IMAGE_SIZE 1024  // Define the size of the input image (IMAGE_SIZE x IMAGE_SIZE)
#define KERNEL_SIZE 5    // Define the size of the kernel (KERNEL_SIZE x KERNEL_SIZE)

// Function to perform 2D convolution
void cpu_convolution(float **image, float **kernel, float **output) {
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
    // Dynamically allocate memory for image, kernel, and output arrays
    float **image = (float **)malloc(IMAGE_SIZE * sizeof(float *));
    float **output = (float **)malloc(IMAGE_SIZE * sizeof(float *));
    for (int i = 0; i < IMAGE_SIZE; i++) {
        image[i] = (float *)malloc(IMAGE_SIZE * sizeof(float));
        output[i] = (float *)malloc(IMAGE_SIZE * sizeof(float));
    }

    float **kernel = (float **)malloc(KERNEL_SIZE * sizeof(float *));
    for (int i = 0; i < KERNEL_SIZE; i++) {
        kernel[i] = (float *)malloc(KERNEL_SIZE * sizeof(float));
    }

    // Populate the image with random values
    for (int i = 0; i < IMAGE_SIZE; i++) {
        for (int j = 0; j < IMAGE_SIZE; j++) {
            image[i][j] = (float)(rand() % 256);  // Random values between 0 and 255
        }
    }

    // Define a 5x5 kernel (edge detection kernel)
    kernel[0][0] = -1; kernel[0][1] = -1; kernel[0][2] = -1; kernel[0][3] = -1; kernel[0][4] = -1;
    kernel[1][0] = -1; kernel[1][1] =  1; kernel[1][2] =  1; kernel[1][3] =  1; kernel[1][4] = -1;
    kernel[2][0] = -1; kernel[2][1] =  1; kernel[2][2] =  8; kernel[2][3] =  1; kernel[2][4] = -1;
    kernel[3][0] = -1; kernel[3][1] =  1; kernel[3][2] =  1; kernel[3][3] =  1; kernel[3][4] = -1;
    kernel[4][0] = -1; kernel[4][1] = -1; kernel[4][2] = -1; kernel[4][3] = -1; kernel[4][4] = -1;

    // Start measuring execution time
    clock_t start = clock();

    // Perform the convolution
    cpu_convolution(image, kernel, output);

    // Stop measuring execution time
    clock_t end = clock();

    // Calculate and print the execution time
    double time_spent = (double)(end - start) / CLOCKS_PER_SEC;
    printf("Execution time (CPU convolution): %f seconds\n", time_spent);

    // Free dynamically allocated memory
    for (int i = 0; i < IMAGE_SIZE; i++) {
        free(image[i]);
        free(output[i]);
    }
    free(image);
    free(output);

    for (int i = 0; i < KERNEL_SIZE; i++) {
        free(kernel[i]);
    }
    free(kernel);

    return 0;
}
