; Names: Campo, Macayan, Madridijo | Section: CSC612M G01
section .data
one dd 1.0
small_float dd 0.000001

section .text
bits 64
default rel

/*
; void cfunc(unsigned int size, float* src_array, float* dst_array, float* mean, float* var) {
;     double sum = 0.0;
;
;     for (unsigned int i = 0; i < size; i++) {
;         sum += (double)src_array[i];
;     }
;
;     *mean = (float)(sum / size);
;
;     double sum_sq_diff = 0.0;
;     for (unsigned int i = 0; i < size; i++) {
;         double diff = (double)src_array[i] - *mean;
;         sum_sq_diff += diff * diff;
;     }
;
;     *var = (float)(sum_sq_diff / size);
;
;     double denominator = sqrt(*var + 1e-6);
;
;     //loop for Z-score Vector Normalization
;     for (unsigned int i = 0; i < size; i++) {
;         dst_array[i] = (float)(((double)src_array[i] - *mean) / denominator);
;     }
; }
*/

%macro push_arg 0
; push arguments to the stack
push    rsi
push    rdi
push    r12
push    rbp
mov     rbp,    rsp
add     rbp,    8*5			
push    rcx
%endmacro

%macro pop_arg 0
pop     rcx
pop     rbp
pop     r12
pop     rdi
pop     rsi
%endmacro

global xmmfunc
xmmfunc:
	push_arg


    pop_arg
	ret