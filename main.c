// Names: Campo, Macayan, Madridijo | Section : CSC612M G01
#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <time.h>
#include <math.h>
#define RUNS 30
#define TOLERANCE 0.0f

int close_enough(float a, float b) {
	return fabsf(a - b) <= TOLERANCE * fmaxf(1.0f, fabsf(a));
}

void cfunc(unsigned int size, float* src_array, float* dst_array, float* mean, float* var) {
	double sum = 0.0;

	for (unsigned int i = 0; i < size; i++) {
		sum += (double)src_array[i];
	}

	double m = sum / size;
	*mean = (float)m;

	double sum_sq_diff = 0.0;
	for (unsigned int i = 0; i < size; i++) {
		double diff = (double)src_array[i] - m;
		sum_sq_diff += diff * diff;
	}

	double v = sum_sq_diff / size;
	*var = (float)v;

	double denominator_reciprocal = 1.0 / sqrt(v + 1e-6);

	//loop for Z-score Vector Normalization
	for (unsigned int i = 0; i < size; i++) {
		dst_array[i] = (float)(((double)src_array[i] - m) * denominator_reciprocal);
	}
}

extern void x86_64func(unsigned int size, float* src_array, float* dst_array, float* mean, float* var);
extern void xmmfunc(unsigned int size, float* src_array, float* dst_array, float* mean, float* var);
extern void ymmfunc(unsigned int size, float* src_array, float* dst_array, float* mean, float* var);

void time_implementation(int impl, unsigned int size, float* src_array, float* dst_array, float* mean, float* var) {
	//const char* impl_names[4] = { "C", "x86-64", "XMM", "YMM" };
	const char* impl_names[2] = { "C", "YMM" };

	LARGE_INTEGER freq, t_start, t_end;
	QueryPerformanceFrequency(&freq); // ticks per second

	double total_ms = 0.0;
	for (int r = 0; r < RUNS; r++) {
		QueryPerformanceCounter(&t_start);
		switch (impl) {
			case 0:
				cfunc(size, src_array, dst_array, mean, var);
				break;
			case 1: //change back to 3
				ymmfunc(size, src_array, dst_array, mean, var);
				break;
		}
		QueryPerformanceCounter(&t_end);

		total_ms += (double)(t_end.QuadPart - t_start.QuadPart) * 1000.0 / (double)freq.QuadPart;
	}

	printf("  %s: %.4lf ms (mean = %f, var = %f)\n", impl_names[impl], total_ms / RUNS, *mean, *var);
}

void check_implementation(int impl, unsigned int size, float* c_dst_array, float c_mean, float c_var, float* dst_array, float mean, float var) {
	//const char* impl_names[4] = { "C", "x86-64", "XMM", "YMM" };
	const char* impl_names[2] = { "C", "YMM" };

	printf("  %s:\n", impl_names[impl]);
	printf("    Mean: %.10f, Variance: %.10f\n", mean, var);

	printf("    First 5 values: ");
	for (unsigned int j = 0; j < 5 && j < size; j++) {
		printf("%.10f, ", dst_array[j]);
	}

	printf("\n    Last 5 values: ");
	for (unsigned int j = (size > 5) ? size - 5 : 0; j < size; j++) {
		printf("%.10f, ", dst_array[j]);
	}
	printf("\n");

	unsigned int meansEqual = close_enough(c_mean, mean);
	unsigned int varsEqual = close_enough(c_var, var);

	if (meansEqual) {
		printf("    Means are equal.\n");
	}
	else {
		printf("    Means differ.\n");
	}

	if (varsEqual) {
		printf("    Variances are equal.\n");
	}
	else {
		printf("    Variances differ.\n");
	}

	unsigned int isEqual = 1;

	for (unsigned int j = 0; j < size; j++) {
		isEqual &= close_enough(c_dst_array[j], dst_array[j]);

		if (!isEqual) { //find the first Z-score that differs from the C baseline
			printf("    Values at index %u are different: %.10f vs %.10f\n", j, dst_array[j], c_dst_array[j]);
			break;
		}
	}

	if (isEqual) {
		printf("    Z-scores are equal.\n");
	}
	else {
		printf("    Z-scores differ.\n");
	}
}

int main() {
	srand(time(NULL));

	int size_list[3] = { 20, 26, 28 };
	float* src_array[4] = { NULL, NULL, NULL, NULL };
	float* dst_c_array[4] = { NULL, NULL, NULL, NULL };
	float* dst_x86_64_array[4] = { NULL, NULL, NULL, NULL };
	float* dst_xmm_array[4] = { NULL, NULL, NULL, NULL };
	float* dst_ymm_array[4] = { NULL, NULL, NULL, NULL };
	float mean_c_array[4] = { 0 };
	float mean_x86_64_array[4] = { 0 };
	float mean_xmm_array[4] = { 0 };
	float mean_ymm_array[4] = { 0 };
	float var_c_array[4] = { 0 };
	float var_x86_64_array[4] = { 0 };
	float var_xmm_array[4] = { 0 };
	float var_ymm_array[4] = { 0 };

	printf("Initializing arrays with random values...\n");

	for (int i = 0; i < 4; i++) {
		unsigned int size = (i < 3) ? (1u << size_list[i]) : 1003;

		src_array[i] = (float*)malloc(sizeof(float) * size);
		dst_c_array[i] = (float*)malloc(sizeof(float) * size);
		dst_x86_64_array[i] = (float*)malloc(sizeof(float) * size);
		dst_xmm_array[i] = (float*)malloc(sizeof(float) * size);
		dst_ymm_array[i] = (float*)malloc(sizeof(float) * size);

		if (i < 3) {
			printf("Initial values for size 2 ^ %d: ", size_list[i]);
		}
		else {
			printf("Initial values for size %d: ", size);
		}

		// Fill arrays with random floats in between -100 and +100
		for (unsigned int j = 0; j < size; j++) {
			src_array[i][j] = (rand() / (float)RAND_MAX * 200.0f) - 100.0f;
			if (j < 5) {
				printf("%f, ", src_array[i][j]);
			}
		}
		printf("\n");
	}

	// timing all 4 implementations (C, x86_64, XMM, YMM) for all 4 sizes (2^20, 2^26, 2^30, 1003)
	printf("\nTiming (average of %d runs):\n", RUNS);

	for (int i = 0; i < 4; i++) {
		unsigned int size = (i < 3) ? (1u << size_list[i]) : 1003;

		if (i < 3) {
			printf("Size 2 ^ %d:\n", size_list[i]);
		}
		else {
			printf("Size %u:\n", size);
		}

		//destination, mean, and variance of each implementation for this size (0 : C; 1 : x86-64; 2 : XMM; 3 : YMM)
		//float* dst_list[4] = { dst_c_array[i], dst_x86_64_array[i], dst_xmm_array[i], dst_ymm_array[i] };
		//float* mean_list[4] = { &mean_c_array[i], &mean_x86_64_array[i], &mean_xmm_array[i], &mean_ymm_array[i] };
		//float* var_list[4] = { &var_c_array[i], &var_x86_64_array[i], &var_xmm_array[i], &var_ymm_array[i] };
		float* dst_list[2] = { dst_c_array[i], dst_ymm_array[i] };
		float* mean_list[2] = { &mean_c_array[i], &mean_ymm_array[i] };
		float* var_list[2] = { &var_c_array[i], &var_ymm_array[i] };

		for (int impl = 0; impl < 2; impl++) { //change to i < 4
			time_implementation(impl, size, src_array[i], dst_list[impl], mean_list[impl], var_list[impl]);
		}
	}

	// correctness check for all 4 implementations (C, x86_64, XMM, YMM) for all 4 sizes (2^20, 2^26, 2^30, 1003)
	printf("\nCorrectness check (compared to C):\n");

	for (int i = 0; i < 4; i++) {
		unsigned int size = (i < 3) ? (1u << size_list[i]) : 1003;

		if (i < 3) {
			printf("Size 2 ^ %d:\n", size_list[i]);
		}
		else {
			printf("Size %u:\n", size);
		}

		//destination, mean, and variance of each implementation for this size (0 : C; 1 : x86-64; 2 : XMM; 3 : YMM)
		//float* dst_list[4] = { dst_c_array[i], dst_x86_64_array[i], dst_xmm_array[i], dst_ymm_array[i] };
		//float* mean_list[4] = { &mean_c_array[i], &mean_x86_64_array[i], &mean_xmm_array[i], &mean_ymm_array[i] };
		//float* var_list[4] = { &var_c_array[i], &var_x86_64_array[i], &var_xmm_array[i], &var_ymm_array[i] };
		float* dst_list[2] = { dst_c_array[i], dst_ymm_array[i] };
		float* mean_list[2] = { &mean_c_array[i], &mean_ymm_array[i] };
		float* var_list[2] = { &var_c_array[i], &var_ymm_array[i] };

		for (int impl = 0; impl < 2; impl++) { //change to impl < 4
			check_implementation(impl, size, dst_c_array[i], mean_c_array[i], var_c_array[i], dst_list[impl], *mean_list[impl], *var_list[impl]);
		}
	}
}