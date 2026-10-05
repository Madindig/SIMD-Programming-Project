// Names: Campo, Macayan, Madridijo | Section : CSC612M G01
#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <time.h>
#include <math.h>

void cfunc(unsigned int size, float* src_array, float* dst_array, float* mean, float* var) {
	float sum = 0.0f;

	//loop for mean
	for (unsigned int i = 0; i < size; i++) {
		sum += src_array[i];
	}

	*mean = sum / size;

	//loop for variance
	float sum_sq_diff = 0.0f;
	for (unsigned int i = 0; i < size; i++) {
		float diff = src_array[i] - *mean;
		sum_sq_diff += diff * diff;
	}

	*var = sum_sq_diff / size;

	float denominator = sqrtf(*var + 1e-6f);

	//loop for Z-score Vector Normalization
	for (unsigned int i = 0; i < size; i++) {
		dst_array[i] = (src_array[i] - *mean) / denominator;
	}
}

int main() {
	srand(time(NULL));

	int size_list[3] = { 20, 26, 30 };
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

	// ---- Timing cfunc with QueryPerformanceCounter ----
	const int runs = 30;
	LARGE_INTEGER freq, t_start, t_end;
	QueryPerformanceFrequency(&freq); // ticks per second

	printf("\nTiming cfunc (average of %d runs):\n", runs);

	for (int i = 0; i < 4; i++) {
		unsigned int size = (i < 3) ? (1u << size_list[i]) : 1003;

		dst_c_array[i] = (float*)malloc(sizeof(float) * size);

		double total_ms = 0.0;
		for (int r = 0; r < runs; r++) {
			QueryPerformanceCounter(&t_start);
			cfunc(size, src_array[i], dst_c_array[i], &mean_c_array[i], &var_c_array[i]);
			QueryPerformanceCounter(&t_end);

			total_ms += (double)(t_end.QuadPart - t_start.QuadPart) * 1000.0 / (double)freq.QuadPart;
		}

		if (i < 3) {
			printf("Size 2 ^ %d: %.4lf ms (mean = %f, var = %f)\n", size_list[i], total_ms / runs, mean_c_array[i], var_c_array[i]);
		}
		else {
			printf("Size %u: %.4lf ms (mean = %f, var = %f)\n", size, total_ms / runs, mean_c_array[i], var_c_array[i]);
		}
	}
}