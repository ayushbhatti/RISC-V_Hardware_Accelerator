#include "mex.h"
//#define DEBUG_PRINTS

#define NUM_BITS 32
#define EXP_BITS 8
#define MANTISSA_BITS 23

#define SIGN_BIT (NUM_BITS - 1)
#define EXP_BIT (SIGN_BIT - EXP_BITS)

#define EXP_MASK ((1 << EXP_BITS) - 1)
#define MANTISSA_MASK ((1 << MANTISSA_BITS) - 1)

float floating_point_add(float a, float b)
{
    unsigned int aUint32, bUint32;
    memcpy(&aUint32, &a, sizeof(float));
    memcpy(&bUint32, &b, sizeof(float));

    #ifdef DEBUG_PRINTS
    mexPrintf("a = 0x%08X\n", aUint32);
    mexPrintf("b = 0x%08X\n", bUint32);
    mexPrintf("\n");
    #endif

    unsigned int aSign, bSign;
    unsigned int aExp, bExp;
    unsigned int aMantissa, bMantissa;

    aSign = aUint32 >> SIGN_BIT;
    bSign = bUint32 >> SIGN_BIT;

    aExp = (aUint32 >> EXP_BIT) & EXP_MASK;
    bExp = (bUint32 >> EXP_BIT) & EXP_MASK;

    aMantissa = aUint32 & MANTISSA_MASK;
    bMantissa = bUint32 & MANTISSA_MASK;

    #ifdef DEBUG_PRINTS
    mexPrintf("aSign = %d, aExp = 0x%02X, aMantissa = 0x%06X\n", aSign, aExp, aMantissa);
    mexPrintf("bSign = %d, bExp = 0x%02X, bMantissa = 0x%06X\n", bSign, bExp, bMantissa);
    mexPrintf("\n");
    #endif

    unsigned int sumUint32;
    float sum;

    // Infinity and NaN's
    if ((aExp == 255) || (bExp == 255))
    {
        // NaN
        if ((aMantissa != 0) || (bMantissa != 0))
        {
            sumUint32 = 0x7FC00000;
        }
        // Infinity
        else
        {
            if ((aExp == 255) && (bExp == 255) && (aSign != bSign))
            {
                sumUint32 = 0x7FC00000;
            }
            if (aExp == 255)
            {
                sumUint32 = (aSign << 31) | (0xFF << 23);
            }
            else
            {
                sumUint32 = (bSign << 31) | (0xFF << 23);
            }
        }
        memcpy(&sum, &sumUint32, sizeof(float));
        return sum;
    }

    if (aExp > 0)
    {
        aMantissa = aMantissa | (1 << MANTISSA_BITS);
    }
    else
    {
        aMantissa = aMantissa << 1;
    }

    if (bExp > 0)
    {
        bMantissa = bMantissa | (1 << MANTISSA_BITS);
    }
    else
    {
        bMantissa = bMantissa << 1;
    }

    long long aOperand = (long long) aMantissa;
    long long bOperand = (long long) bMantissa; 

    if (aSign)
    {
        aOperand = -aOperand;
    }

    if (bSign)
    {
        bOperand = -bOperand;
    }

    #ifdef DEBUG_PRINTS
    mexPrintf("aOperand = 0x%08X\n", (int) aOperand);
    mexPrintf("bOperand = 0x%08X\n", (int) bOperand);
    mexPrintf("\n");
    #endif

    unsigned int maxExp = aExp;
    unsigned int minExp = bExp;
    long long maxOperand = aOperand;
    long long minOperand = bOperand;

    if (bExp > aExp)
    {
        maxExp = bExp;
        minExp = aExp;
        maxOperand = bOperand;
        minOperand = aOperand;
    }

    #ifdef DEBUG_PRINTS
    mexPrintf("maxExp = 0x%02X\n", maxExp);
    mexPrintf("minExp = 0x%02X\n", minExp);
    mexPrintf("maxOperand = 0x%08X\n", (int) maxOperand);
    mexPrintf("minOperand = 0x%08X\n", (int) minOperand);
    mexPrintf("\n");
    #endif

    unsigned int expShift = maxExp - minExp;
    if (expShift > 25)
    {
        expShift = 25;
    }

    maxOperand = maxOperand << 25;
    minOperand = minOperand << (25 - expShift);

    #ifdef DEBUG_PRINTS
    mexPrintf("maxOperand = 0x%016llX\n", maxOperand);
    mexPrintf("minOperand = 0x%016llX\n", minOperand);
    mexPrintf("\n");
    #endif

    long long sumOperand = maxOperand + minOperand;

    #ifdef DEBUG_PRINTS
    mexPrintf("sumOperand = 0x%016llX\n", sumOperand);
    mexPrintf("\n");
    #endif

    unsigned int sumSign = 0;
    if (sumOperand < 0)
    {
        sumSign = 1;
        sumOperand = -sumOperand;
    }

    #ifdef DEBUG_PRINTS
    mexPrintf("sumSign = %d\n", sumSign);
    mexPrintf("sumOperand = 0x%016llX\n", sumOperand);
    mexPrintf("\n");
    #endif

    int maxBit = -1;
    for (int i = 0; i < 51; ++i)
    {
        if ((sumOperand >> i) & 1)
        {
            maxBit = i;
        }
    }

    #ifdef DEBUG_PRINTS
    mexPrintf("maxBit = %d\n", maxBit);
    mexPrintf("\n");
    #endif

    if (maxBit > 0)
    {
        unsigned int maxShift = maxExp + 1;
        unsigned int shift = 50 - (unsigned int) maxBit;
        if (shift > maxShift)
        {
            shift = maxShift;
        }

        #ifdef DEBUG_PRINTS
        mexPrintf("maxShift = %d\n", maxShift);
        mexPrintf("shift = %d\n", shift);
        mexPrintf("\n");
        #endif

        sumOperand = sumOperand << shift;

        #ifdef DEBUG_PRINTS
        mexPrintf("sumOperand = %016llX\n", sumOperand);
        mexPrintf("sumOperand >> 27 = %016llX\n", sumOperand >> 27);
        mexPrintf("sumOperand >> 26 = %016llX\n", sumOperand >> 26);
        mexPrintf("sumOperand(25:0) = %016llX\n", sumOperand & 0x3FFFFFF);
        mexPrintf("\n");
        #endif

        long long roundBit = 0;

        if (((sumOperand >> 26) & 1) == 1)
        {
            if (((sumOperand & 0x3FFFFFF) != 0) || (((sumOperand >> 27) & 1) == 1))
            {
                roundBit = 1; 
            }
        }

        #ifdef DEBUG_PRINTS
        mexPrintf("roundBit = %d\n", roundBit);
        mexPrintf("\n");
        #endif

        sumOperand = sumOperand >> 27;
        sumOperand = sumOperand + roundBit;
        if (((sumOperand >> 25) & 1) == 1)
        {
            sumOperand = sumOperand >> 1;
            maxExp = maxExp + 1;
        }

        #ifdef DEBUG_PRINTS
        mexPrintf("sumOperand = %08X\n", (int) sumOperand);
        mexPrintf("\n");
        #endif

        unsigned int sumMantissa = (unsigned int) (sumOperand & 0x7FFFFF);

        #ifdef DEBUG_PRINTS
        mexPrintf("sumMantissa = %08X\n", sumMantissa);
        mexPrintf("\n");
        #endif

        int sumExpUnbounded = (int) maxExp + (maxBit - 48);
        if (sumExpUnbounded < 0)
        {
            sumExpUnbounded = 0;
        }
        else if (sumExpUnbounded > 255)
        {
            sumExpUnbounded = 255;
        }
        unsigned int sumExp = (unsigned int) sumExpUnbounded;

        if (sumExp == 255)
        {
            sumMantissa = 0;
        }

        #ifdef DEBUG_PRINTS
        mexPrintf("sumExp = 0x%02X\n", sumExp);
        mexPrintf("\n");
        #endif

        unsigned int sumUint32 = sumSign << 31 | sumExp << 23 | sumMantissa;
        float sum;

        memcpy(&sum, &sumUint32, sizeof(float));

        return sum;
    }
    else
    {
        return 0.0f;
    }

    // return a + b;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    /*
    mwSize numOfDims = mxGetNumberOfDimensions(prhs[0]);
    mexPrintf("%d\n", numOfDims);
    mwSize* dims = mxGetDimensions(prhs[0]);
    */
    plhs[0] = mxCreateNumericArray(mxGetNumberOfDimensions(prhs[0]), 
        mxGetDimensions(prhs[0]), mxSINGLE_CLASS, mxREAL);
    mwSize numElements = mxGetNumberOfElements(prhs[0]);
    float* sum = mxGetData(plhs[0]);
    float* a = mxGetData(prhs[0]);
    float* b = mxGetData(prhs[1]);
    for (mwSize i = 0; i < numElements; ++i)
    {
        sum[i] = floating_point_add(a[i], b[i]);
    }
    /*
    mwSize numElements = mxGetNumberOfElements(prhs);
    for (mwSize i = 0; i < numOfDims; ++i)
    {
        // mexPrintf("%d\n",i);
        mexPrintf("%d\n",dims[i]);
    }*/
    /*
    const mwSize = 
    const mwSize *mxGetDimensions(plhs[0]);

    float a = mxGetprhs[0];
    float b = *prhs[1];
    float sum = a + b;
    *plhs[0] = sum;*/
}