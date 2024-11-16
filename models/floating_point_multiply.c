#include "mex.h"
//#define DEBUG_PRINT

// Floating-point bit mapping
#define NUM_BITS 32
#define EXP_BITS 8
#define MANTISSA_BITS 23

// Location of sign bit and exponent field
#define SIGN_BIT (NUM_BITS - 1)
#define EXP_BIT  (SIGN_BIT - EXP_BITS)

// Masks to extract exponent and mantissa fields
#define EXP_MASK      ((1 << EXP_BITS) - 1)
#define MANTISSA_MASK ((1 << MANTISSA_BITS) - 1)

#define BIAS ((1 << (EXP_BITS - 1)) - 1)
#define PROD_WIDTH (2 * (MANTISSA_BITS + 1) - 1)

float floating_point_multiply(float a, float b)
{
    // View the floating point numbers as uint32's
    unsigned int aUint32, bUint32;
    memcpy(&aUint32, &a, sizeof(float));
    memcpy(&bUint32, &b, sizeof(float));

    // Extract the sign, exponent, and mantissa fields from the floating point numbers
    unsigned int aSign, bSign;
    unsigned int aExp, bExp;
    unsigned int aMantissa, bMantissa;

    aSign = aUint32 >> SIGN_BIT;
    bSign = bUint32 >> SIGN_BIT;

    aExp = (aUint32 >> EXP_BIT) & EXP_MASK;
    bExp = (bUint32 >> EXP_BIT) & EXP_MASK;

    aMantissa = aUint32 & MANTISSA_MASK;
    bMantissa = bUint32 & MANTISSA_MASK;

    #ifdef DEBUG_PRINT
        printf("aSign = %d\n", aSign);
        printf("bSign = %d\n\n", aSign);

        printf("aExp = %d\n", aExp);
        printf("bExp = %d\n\n", bExp);

        printf("aMantissa = 0x%08X\n", aMantissa);
        printf("bMantissa = 0x%08X\n\n", bMantissa);
    #endif
    
    unsigned int aNaN = 0;
    unsigned int bNaN = 0;
    unsigned int aInf = 0;
    unsigned int bInf = 0;
    if (aExp == 255)
    {
        if (aMantissa == 0)
        {
            aInf = 1;
        }
        else
        {
            aNaN = 1;
        }
    }
    if (bExp == 255)
    {
        if (bMantissa == 0)
        {
            bInf = 1;
        }
        else
        {
            bNaN = 1;
        }
    }

    unsigned int prodNaN = aNaN | bNaN;

    unsigned int aZero = 0;
    unsigned int bZero = 0;

    if (aExp == 0 && aMantissa==0)
    {
        aZero = 1;
    }
    if (bExp == 0 && bMantissa==0)
    {
        bZero = 1;
    }

    prodNaN = prodNaN | (aInf & bZero) | (bInf & aZero);
    unsigned int prodInf = aInf | bInf;

    if (aExp != 0)
    {
        aMantissa = aMantissa | (1 << MANTISSA_BITS);
    }
    else
    {
        aMantissa = aMantissa << 1;
    }
    
    if (bExp != 0)
    {
        bMantissa = bMantissa | (1 << MANTISSA_BITS);
    }
    else
    {
        bMantissa = bMantissa << 1;
    }

    #ifdef DEBUG_PRINT
        printf("aMantissa = 0x%08X\n", aMantissa);
        printf("bMantissa = 0x%08X\n\n", bMantissa);
    #endif

    unsigned int aShift = 0;
    unsigned int bShift = 0;

    unsigned int i;
    for (i = 0; i <= MANTISSA_BITS; ++i)
    {
        if ((aMantissa >> i) & 1)
        {
            aShift = (MANTISSA_BITS - i);
        }
        if ((bMantissa >> i) & 1)
        {
            bShift = (MANTISSA_BITS - i);
        }
    }

    unsigned int prodSign = aSign ^ bSign;

    // int prodShift = (int) aShift + (int) bShift;

    #ifdef DEBUG_PRINT
        printf("aShift = %d\n", aShift);
        printf("bShift = %d\n", bShift);
    #endif

    unsigned long long prod = (unsigned long long) ((unsigned long long) aMantissa) * ((unsigned long long) bMantissa);

    int prodShift = 0;
    int prodZero = 1;
    for (i = 0; i < 48; ++i)
    {
        if ((prod >> i) & 1)
        {
            prodShift = 47 - i;
            prodZero = 0;
        }
    }

    #ifdef DEBUG_PRINT
        printf("prod = 0x%016llX\n\n", prod);
        printf("prodShift = %d\n\n", prodShift);
    #endif

    int prodExp = (int) aExp + (int) bExp - BIAS + 1;

    #ifdef DEBUG_PRINT
        printf("prodExp = %d\n\n", prodExp);
    #endif

    prod = prod << prodShift;
    prodExp = prodExp - prodShift;

    #ifdef DEBUG_PRINT
        printf("prodExp = %d\n\n", prodExp);
    #endif

    if (prodExp > 0)
    {
        prodShift = 0;
    }
    else
    {
        if (prodExp <= -24)
        {
            prodShift = 25;
        }
        else
        {
            prodShift = -prodExp + 1;
        }
    }

    if (prodExp < 0)
    {
        prodExp = 0;
    }

    unsigned long long truncBits = prod << 15; 
    truncBits = truncBits << (25 - prodShift);
    truncBits = truncBits >> 15;

    unsigned int prodMantissa = prod >> (24 + prodShift);

    #ifdef DEBUG_PRINT
        printf("prodMantissa = 0x%018X\n\n", prodMantissa);
    #endif

    unsigned int roundBit = 0;
    if ((truncBits >> 48) & 1)
    {
        unsigned long long mask = ((((unsigned long long) 1) << 48) - 1);
        #ifdef DEBUG_PRINT
            printf("mask = 0x%016llX\n\n", mask);
            printf("(prodMantissa & 1) = %d\n\n", (prodMantissa & 1));
        #endif
        if ((prodMantissa & 1) || (truncBits & mask))
        {
            roundBit = 1;
        }
    }

    #ifdef DEBUG_PRINT
        printf("truncBits = 0x%016llX\n\n", truncBits);
        printf("roundBit = %d\n\n", roundBit);
    #endif

    prodMantissa = prodMantissa + roundBit;

    if (prodShift == 0)
    {
        if ((prodMantissa >> 24) && 1)
        {
            prodExp++;
        }
    }
    else
    {
        if ((prodMantissa >> 23) && 1)
        {
            prodExp++;
        }
    }

    prodMantissa = prodMantissa & ((1 << 23) - 1);

    #ifdef DEBUG_PRINT
        printf("prodExp = %d\n\n", prodExp);
    #endif

    if (prodExp >= 255)
    {
        prodInf = 1;
    }
    
    /*#ifdef DEBUG_PRINT
        printf("prodShift = %d\n\n", prodShift);
    #endif

    if (prodShift >= 0)
    {
        #ifdef DEBUG_PRINT
            printf("shift left!\n");
        #endif
        prod = prod << prodShift;
    }
    else
    {
        #ifdef DEBUG_PRINT
            printf("shift right!\n");
        #endif
        int shift = -prodShift;
        #ifdef DEBUG_PRINT
            printf("shift = %d\n", shift);
        #endif
        if (shift > 48)
        {
            shift = 48;
        }
        prod = prod >> shift;
    }

    #ifdef DEBUG_PRINT
        printf("prod = 0x%016llX\n\n", prod);
    #endif

    if (prodExp >= 255)
    {
        prodInf = 1;
    }

    unsigned int prodMantissa = (unsigned int) (prod >> 24) & MANTISSA_MASK;

    unsigned int roundBit = 0;
    if (prod & (1 << 23))
    {
        if (((prod >> 24) & 1) || (prod & ((1 << 23)-1)))
        {
            roundBit = 1;
        }
    }
    prodMantissa = prodMantissa + roundBit;*/

    if (prodNaN)
    {
        prodExp = 0xFF;
        prodMantissa = 1 << (MANTISSA_BITS - 1);
    }
    else if (prodInf)
    {
        prodExp = 0xFF;
        prodMantissa = 0;
    }
    
    unsigned int prodUint32 = (prodSign << 31) | (prodExp << 23) | prodMantissa;
    float prodFloat;

    memcpy(&prodFloat, &prodUint32, sizeof(float));

    return prodFloat;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    plhs[0] = mxCreateNumericArray(mxGetNumberOfDimensions(prhs[0]), 
        mxGetDimensions(prhs[0]), mxSINGLE_CLASS, mxREAL);
    mwSize numElements = mxGetNumberOfElements(prhs[0]);
    float* prod = mxGetData(plhs[0]);
    float* a = mxGetData(prhs[0]);
    float* b = mxGetData(prhs[1]);
    for (mwSize i = 0; i < numElements; ++i)
    {
        prod[i] = floating_point_multiply(a[i], b[i]);
    }
}