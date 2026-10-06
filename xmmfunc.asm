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

%macro check_remainder 0
pxor xmm1, xmm1
cmp rcx, 0
jz REMAINDER_LOOP
%endmacro

%macro add_loop 0
; accumulators
vpxor xmm2, xmm2, xmm2 ; clear prev_1 = 0
vpxor xmm3, xmm3, xmm3 ; clear prev_2 = 0
.L1_ADD_LOOP:
    ; note: xmm is 128-bit
    vcvtps2pd xmm0, [rdx]   ; curr1 := first 2 sp(32-bits) floats to 2 dp(64-bits)
    vcvtps2pd xmm1, [rdx+2] ; curr2 := first 2 sp(32-bits) floats to 2 dp(64-bits)
    vaddpd xmm2, xmm0, xmm2 ; prev_1 := prev_1 + curr_1
    vaddpd xmm3, xmm1, xmm3 ; prev_2 := prev_2 + curr_2
    add rdx, 4
    loop L1_ADD_LOOP
%endmacro

%macro remainder_loop 0
pxor xmm1, xmm1
mov rcx, rsi                ;
cmp rcx, 0                  ;
jz SUM_AND_MEAN             ;
.L2_REMAINDER_LOOP:
    cvtss2sd xmm0, [rdx]
    addsd xmm1, xmm0        ;
    loop L2_REMAINDER_LOOP  ;
%endmacro

%macro get_sum 0
; get the sum of src_dst
mov r12, rdx
xor rdx, rdx
; note: div 
; size / 4 bit  => ans r remainder  
; eax  / rcx    => eax r edx
mov rax, rcx    ; move size
mov rcx, 4      ; no. # of 32-bit sp-fp in 128-bit register
mov rsi, rdx    ; remaining start
mov rdi, rcx    ; remaining end
mov rdx, r12    ; *src_array
check_remainder
add_loop
remainder_loop
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