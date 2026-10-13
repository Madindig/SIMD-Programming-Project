# SIMD Programming Project

## Description

Four implementations of mean, variance, and z-score vector normalization.

1. C program;
2. x86-64 assembly language; 
3. x86-64 SIMD AVX2 assembly language using XMM register; 
4. x86-64 SIMD AVX2 assembly language using YMM register.

The four implementation functions take the same five parameters:
1. unsigned int size // The number of elements passed
2. float* src_array // The base pointer of the input vector X, which contains random single-precision FP values between -100.0f and +100.0f
3. float* dst_array // The base pointer of the destination vector Z
4. float* mean // The address where the mean of X will be stored
5. float* var // The address where the variance of X will be stored

Results are reported at four sizes, namely 2^20, 2^26, 2^30, and 1003.

## Authors:
- Campo, Roan
- Macayan, Denzel
- Madridijo, Luis

## 1) Execution Time (screenshot)

The execution times below were obtained from Madridijo's machine in release mode using QueryPerformanceFrequency and QueryPerformanceCounter to measure the execution times of only the function executions (cfunc, x86_64func, xmmfunc, and ymmfunc) at each size. The final values reported are in milliseconds.

### Image 1: Execution times on Madridijo's machine in release mode
<img src="images/1)%20Execution%20Times.png">

## 2) Comparative Tables of Execution Times

### Table 1: Execution Times as Speedup of C (ET_C/ET_other implementation)
| Size | C (ms) | x86-64 (ms) | XMM (ms) | YMM (ms) |
|------|-------:|------------:|---------:|---------:|
| 2^20 | 10.1091 | 3.7885 (2.67x) | 1.2600 (8.02x) | 0.7539 (13.41x) |
| 2^26 | 636.3575 | 264.0319 (2.41x) | 76.0839 (8.36x) | 61.7276 (10.31x) |
| 2^30 | 10388.1158 | 5438.4869 (1.91x) | 3104.4192 (3.35x) | 4219.3723 (2.46x) |
| 1003 | 0.0182 | 0.0050 (3.64x) | 0.0019 (9.58x) | 0.0018 (10.11x) |

Across the four sizes measured, C consistently had the slowest execution time, followed by x86-64, then the two SIMD implementations. The speedup from C to x86-64 likely comes from storing variables used in each iteration in the registers instead of in memory. In particular, the 
- accumulators for the mean and variance loops and
- the mean used in the variance and z-score loops

are stored in xmm registers instead of as double variables, saving time loading them from memory. The switch to registers has additional benefits for the accumulator variables because the updated accumulator value also has to be stored in memory in the C version, while in the x86-64 version, the accumulated value just stays in the register.

### Table 2: Execution Times of Assembly Implementations as Speedup of x86-64 (ET_x86-64/ET_other implementation)

| Size | x86-64 (ms) | XMM (ms) | YMM (ms) |
|------|------------:|---------:|---------:|
| 2^20 | 3.7885 | 1.2600 (3.01x) | 0.7539 (5.03x) |
| 2^26 | 264.0319 | 76.0839 (3.47x) | 61.7276 (4.28x) |
| 2^30 | 5438.4869 | 3104.4192 (1.75x) | 4219.3723 (1.29x) |
| 1003 | 0.0050 | 0.0019 (2.63x) | 0.0018 (2.78x) |

Across the three assembly implementations, the x86-64 implementation consistently had the slowest execution time, followed by the XMM implementation and the YMM implementation. The XMM implementation for mean and variance saves time by loading four single-precision (SP) floats at a time, converting them to double precision (DP), then accumulating the four DP floats in two XMM registers using packed symmetric addition (or vfmadd231pd for variance calculation). This way of accumulating in registers means that after the loop, we are left with four DP floats that we can add together using horizontal addition to get the final totals needed for both mean and variance calculations. The z-score implementation also uses packed symmetric operations (subtract and multiply) to compute four z-scores in one loop, but again, using DP for added precision means we need two XMM registers to compute four z-scores at a time.

### Table 3: Execution Times of SIMD Implementations as Speedup of XMM (ET_XMM/ET_YMM)

| Size | XMM (ms) | YMM (ms) |
|------|---------:|---------:|
| 2^20 | 1.2600 | 0.7539 (1.67x) |
| 2^26 | 76.0839 | 61.7276 (1.23x) |
| 2^30 | 3104.4192 | 4219.3723 (0.74x) |
| 1003 | 0.0019 | 0.0018 (1.06x) |

The YMM implementation leverages the doubled size of YMM registers to process twice as many SP floats per loop. Using DP for added precision means that, in the mean and variance calculations, eight DP sums can be accumulated in two YMM registers using packed symmetric addition (or vfmadd231pd for variance calculation), and these eight DP sums are then added together after the loop using horizontal add, similar to the XMM implementation. The z-score computation can now also process eight SP floats per loop, using one YMM register for storing the DP version of the first four SP floats and another YMM register for the DP version of the second four SP floats.

## 3) Correctness Check

Below are the correctness checks on the z-scores using the output of C as the ground truth for correctness. Note that the results are only considered correct if they are within 10^-6 of the C implementation's computed value.

### Image 2: Correctness check for 2^20 elements on Madridijo's machine in release mode
<img src="images/3%20-%206)%20Correctness%20Check%20(Size%20%3D%202%20to%20the%2020th).png">

### Image 3: Correctness check for 2^26 elements on Madridijo's machine in release mode
<img src="images/3%20-%206)%20Correctness%20Check%20(Size%20%3D%202%20to%20the%2026th).png">

### Image 4: Correctness check for 2^30 elements on Madridijo's machine in release mode
<img src="images/3%20-%206)%20Correctness%20Check%20(Size%20%3D%202%20to%20the%2030th).png">

## 4) Boundary Check

Below is the boundary check to ensure that XMM and YMM can process boundary elements if the number of elements is not divisible by the number of SP floats it can process in one loop. We chose to perform the boundary check on 1003 elements since 1003 is not divisible by four (XMM) or eight (YMM).

### Image 5: Boundary check for 1003 elements on Madridijo's machine in release mode
<img src="images/7)%20Boundary%20Check.png">

On both XMM and YMM, two values were needed to ensure that an input of any number of elements could be processed.

$$
\text{primary loops} = \left\lfloor \frac{\text{elements passed}}{\text{SP floats processed in parallel}} \right\rfloor
$$

$$
\text{remainder loops} = \text{elements passed} \bmod \text{SP floats processed in parallel}
$$

These values are stored in registers to later overwrite rcx whenever necessary. The first **primary loops x 4 (XMM) or 8 (YMM)** elements are processed in the primary loops for mean, variance, and z-score calculation, while the remainder elements are processed one at a time in the remainder loops, similar to how they are processed in the x86-64 implementation. Control structures ensure that the appropriate loops are used if no primary loops are needed (primary loops == 0) or a remainder loop is needed (remainder loops > 0).

## 5) Analysis of Speedups

One result not aligned with the theoretical speedups is the speedup of XMM and YMM compared to an x86-64 baseline. Although XMM and YMM processing four and eight SP floats at a time predicts a 4x and 8x speedup, many parts of the code do not actually benefit from this speedup, such as the scalar division, square root, reciprocal, and storage of mean and variance. Other parts of the SIMD code are not necessary for the x86-64 version but become necessary for the SIMD implementations, such as the horizontal adds at the end of the mean and variance calculation, broadcasting of the mean and z-score denominator's reciprocal, and the computation and control flow logic to allow for the processing of boundary elements in remainder loops. These non-speedups and additional instructions could explain why the speedup from x86-64 does not match the theoretical speedup of 4x and 8x. 

A different explanation is hinted at by the trend of the speedup from the x86-64 version to the SIMD versions as the size of the input vector increases. As the size of the input vector increases, the execution time advantage of SIMD compared to x86-64 decreases. This trend implies that the proportion of execution time spent doing the parallel computation, which is responsible for the speedup, decreases as the size of the input vector increases. Since most of the execution time is spent inside the primary loops and the only other instructions inside the primary loops besides the parallel computations are memory-bound reads and writes, one likely explanation is that a lot of the execution time is spent waiting on memory operations inside the loops to complete, bottlenecking the rest of the parallel computing code since the data has not yet arrived from or been written to the RAM. 

## 6) Problems and Solutions, Unique Methods, and AHA moments

The main problem we encountered was the consistent failure of the error check when first implementing using AVX2. We found that we could not guarantee the results would pass the error check every run because using single precision for the arithmetic of computing the variance meant any imprecision in the mean value calculation was magnified because of the squared term inside the variance summation. To ensure that all the intermediary arithmetic was as precise as possible, we switched all the intermediary computations from SP to DP floats. This is a trade-off between precision and performance. There is additional overhead when loading and storing because of the need to convert the SP floats to DP floats and back again. Additionally, since one DP float is double the size of an SP float, we can now process only half the number of elements at a time using packed symmetric operations because we are constrained by the size of the XMM and YMM registers.

Other problems we encountered had to do with optimization. For instance, before the z-score computation in the assembly implementations, we solved for the reciprocal of the denominator and saved this value in a register so we could use vmulpd/mulsd instead of vdivpd/divsd (vdivpd/divsd is much slower). We also discovered an instruction called vfmadd231pd, which we used to square the difference and add the squared difference to the accumulator registers in one step instead of separately using vmulpd and vaddpd. 
