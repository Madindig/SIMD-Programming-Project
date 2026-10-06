; Names: Campo, Macayan, Madridijo | Section: CSC612M G01
section .data
one dd 1.0
small_float dd 0.000001

section .text
bits 64
default rel

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

%macro push_arg 0
; push arguments to the stack
; win x64 abi
push    rsi
push    rdi
push    r12
push    rbp
mov     rbp,    rsp
add     rbp,    8*5			
push    rcx
%endmacro

%macro pop_arg 0
; pop arguments
pop     rcx
pop     rbp
pop     r12
pop     rdi
pop     rsi
%endmacro

%macro get_sum 0
; get the sum of src_dst
mov r12, rdx
xor rdx, rdx
; note: div 
; size / 4 bit  => ans r remainder  
; eax  / rcx    => eax r edx
mov rax, rcx    ; move size
mov rcx, 4      ; number of sp-fp in 128-bit register
mov rsi, rdx
mov rdi, rcx    
mov rdx, r12
vpxor xmm2, xmm2, xmm2
vpxor xmm3, xmm3, xmm3
pxor xmm1, xmm1
cmp rcx, 0
jz REMAINDER_LOOP

ADD_LOOP:
    vcvtps2


%endmacro

global xmmfunc
; Compute for Z-score (dst_array) from Input (src_array) by getting mean and variance
; rcx       : array size
; rdx       : pointer src_array
; r8        : pointer dst_array
; r9        : pointer to mean
; rbp+32    : pointer to var
xmmfunc:
	push_arg
    get_sum

    pop_arg
	ret