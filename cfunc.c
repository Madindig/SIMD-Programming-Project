void cfunc(unsigned int size, float* src_array, float* dst_array, float* mean, float* var) {
	double sum = 0.0;

	for (unsigned int i = 0; i < size; i++) {
		sum += (double)src_array[i];
	}

	*mean = (float)(sum / size);

	double sum_sq_diff = 0.0;
	for (unsigned int i = 0; i < size; i++) {
		double diff = (double)src_array[i] - *mean;
		sum_sq_diff += diff * diff;
	}

	*var = (float)(sum_sq_diff / size);

	double denominator = sqrt(*var + 1e-6);

	//loop for Z-score Vector Normalization
	for (unsigned int i = 0; i < size; i++) {
		dst_array[i] = (float)(((double)src_array[i] - *mean) / denominator);
	}
}