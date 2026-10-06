; Names: Campo, Macayan, Madridijo | Section: CSC612M G01
section .data
one dq 1.0
small_float dq 0.000001

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

; push arguments to the stack
; win x64 abi
%macro push_arg 0
push    rsi
push    rdi
push    r12
push    rbp
mov     rbp,    rsp
add     rbp,    8*5			
push    rcx
%endmacro

; get the sum of src_dst
%macro get_sum_for_mean 0 
mean_register_setup
mean_check_remainder
mean_add_bulk_loop
mean_add_remainder_loop
%endmacro

%macro mean_register_setup
mov r12, rdx    ; rearranging, see [1]
xor rdx, rdx    ; See [2] mean_register_setup
mov rax, rcx    ; move size
mov rcx, 4      ; no. # of 32-bit sp-fp in 128-bit register
div rcx
mov rsi, rdx    ; remaining elements
mov rdi, rcx    ; no. $ of add loops
mov rdx, r12    ; *src_array
%endmacro

; checks if has left-over elements
%macro mean_check_remainder 0
pxor xmm1, xmm1
cmp rcx, 0
jz L2_MEAN_REMAINDER_LOOP
%endmacro

; [5] mean_add_bulk_loop
%macro mean_add_bulk_loop 0
vpxor xmm2, xmm2, xmm2 ; clear prev_1 = 0
vpxor xmm3, xmm3, xmm3 ; clear prev_2 = 0
.L1_MEAN_ADD_LOOP:
    ; note: xmm is 128-bit
    vcvtps2pd xmm0, [rdx]   ; curr1 := first 2 sp(4-bytes/32-bits) floats to 2 dp(8-bytes/64-bits)
                            ; array still 8-bytes
    vcvtps2pd xmm1, [rdx+8] ; curr2 := first 2 sp(32-bits) floats to 2 dp(64-bits)
    vaddpd xmm2, xmm0, xmm2 ; prev_1 := prev_1 + curr_1, bulk_1 is prev_1
    vaddpd xmm3, xmm1, xmm3 ; prev_2 := prev_2 + curr_2, bulk_2 is prev_2
    add rdx, 16
    loop L1_MEAN_ADD_LOOP
%endmacro

; See [4] mean_add_remainder_loop
%macro mean_add_remainder_loop 0
pxor xmm1, xmm1             ; clear xmm1
mov rcx, rsi                ; remaining
cmp rcx, 0                  
jz MEAN_SUM_BULK_N_PARTIAL  ; jmp if no remaining
.L2_MEAN_REMAINDER_LOOP:
    cvtss2sd xmm0, [rdx]    ; xmm0 <-dp(8-bytes)- rdx
    addsd xmm1, xmm0        ; xmm0 <- xmm0 + xmm1
    loop L2_MEAN_REMAINDER_LOOP 
%endmacro

; See [3] get_mean
%macro get_mean 0
.MEAN_SUM_BULK_N_PARTIAL:
vpxor xmm0, xmm0, xmm0            ; initialize sum from add loop
vaddpd  xmm2, xmm2, xmm3    ; xmm2:[ab, cd] <- xmm2:[a b] + xmm3:[c d]
vhaddpd xmm2, xmm2, xmm2    ; xmm2:[abcd, abcd] <- xmm2[ab, cd] + xmm2[ab, cd]  
addsd xmm0, xmm2         
addsd xmm0, xmm1            ; add remainder/residuals 
pop rcx                     ; rcx <- stack[rcx] assuming stack has rcx(N) on top
cvtsi2sd xmm1,  rcx         ; xmm0(N) <-dp(8-bytes)- rcx
divsd xmm0, xmm1            ; mean = sum / N
cvtsd2ss xmm2, xmm0         ; xmm2 <-sp(4-bytes)- xmm0
movss [r9], xmm2            ; sum *= xmm2
%endmacro

%macro get_sum_for_variance 0
var_setup_register
var_check_remainder
var_add_bulk_loop
var_add_remainder_loop

%endmacro

%macro var_check_remainder 0
mov rcx, rdi
cmp rcx, 0
jz L4_VARIANCE_REMAINDER_LOOP
%endmacro

%macro var_setup_register 0
pxor xmm4, xmm4
pxor xmm5, xmm5
pxor xmm3, xmm3
%endmacro

%macro var_add_bulk_loop
.L3_VARIANCE_BULK_LOOP:
    vcvtps2pd   xmm2, [rdx]          ; first 2 floats  -> doubles
    vcvtps2pd   xmm3, [rdx+8]        ; second 2 floats -> doubles
    vsubpd      xmm2, xmm2, xmm0     ; subtract mean
    vsubpd      xmm3, xmm3, xmm0     ; subtract mean
    vfmadd231pd xmm4, xmm2, xmm2     ; accumulate sq diff 1
    vfmadd231pd xmm5, xmm3, xmm3     ; accumulate sq diff 2
    add         rdx, 16              ; move 4 floats
    loop        L3_VARIANCE_BULK_LOOP

    pxor        xmm3, xmm3
    mov         rcx, rsi             ; load remainder count
    cmp         rcx, 0
    jz          SUM_AND_VAR
%endmacro

%macro var_add_remainder_loop
.L4_VARIANCE_REMAINDER_LOOP:
    cvtss2sd xmm2, [rdx]
    subsd xmm2, xmm0
    vfmadd231sd xmm3, xmm2, xmm2 ; accumulate differences xmm3 += xmm2 * xmm2
    add rdx, 4
    loop L4_VARIANCE_REMAINDER_LOOP
%endmacro

; See [3] get_mean
%macro get_variance 0
.VAR_SUM_BULK_N_PARTIAL:
vpxor       xmm2, xmm2, xmm2          ; xmm := 0
vaddpd      xmm4, xmm4, xmm5    ; xmm4:[ab, cd] <- xmm4:[a b] + xmm4:[c d]
vhaddpd     xmm4, xmm4, xmm4    ; xmm4:[abcd, abcd] <- xmm4[ab, cd] + xmm4[ab, cd] 
addsd       xmm2, xmm4          ; xmm2 += bulk
addsd       xmm2, xmm3          ; xmm2 += partial
divsd       xmm2, xmm1          ; xmm2 = variance (double)
cvtsd2ss    xmm3, xmm2
mov         rax, [rbp+32]       ; load var pointer
movss       [rax], xmm3         ; store *var
%endmacro

%macro get_zscore 0
addsd xmm2, [small_float]
sqrtsd xmm2, xmm2           ; get std := sqrt(var)
vrcp28pd xmm2
mov rcx, rdi
cmp rcx, 0
jz L6_Z_REMAINDER_LOOP
.L5_Z_BULK_ADD_LOOP:
    vcvtps2pd   xmm3, [rdx]         ; xmm3 <-dp(8-byte)-
    vcvtps2pd   xmm4, [rdx+8]       ; xmm4 <-dp(8-byte)-
    vsubpd      xmm3, xmm3, xmm0    ; src_array - mean
    vsubpd      xmm4, xmm4, xmm0    ; src_array - mean
    vmulpd      xmm3, xmm3, xmm2    ; (src_array - mean) * std
    vmulpd      xmm4, xmm4, xmm2    ; (src_array - mean) * std
    vcvtpd2ps   xmm3, xmm3          ; xmm3 <-sp(4-byte)- xmm3
    vcvtpd2ps   xmm4, xmm4          ; xmm3 <-sp(4-byte)- xmm3
    movq        [r8], xmm3          ; store 2 floats (8 bytes)
    movq        [r8+8], xmm4        ; store 2 floats (8 bytes)
    add         r8, 16              ; next 4 sp (4-bytes) floats
    add         rdx, 16             ; next 4 sp (4-bytes) floats
    loop L5_Z_BULK_ADD_LOOP
mov         rcx, rsi            ; load remainder count
cmp         rcx, 0
jz          .END
.L6_Z_REMAINDER_ADD_LOOP:
    cvtss2sd    xmm3, [rdx]
    subsd       xmm3, xmm0
    mulsd       xmm3, xmm2
    cvtsd2ss    xmm3, xmm3
    movss       [r8], xmm3          ; store z-score float
    add         rdx, 4
    add         r8, 4
    loop        .Z_REMAINDER_LOOP
%endmacro

; pop arguments, see [1]
%macro pop_arg 0
pop     rbp
pop     r12
pop     rdi
pop     rsi
%endmacro

; See [1] xmm func
global xmmfunc
xmmfunc:
	push_arg
    
    get_sum_for_mean
    get_mean
    
    get_sum_for_variance
    get_variance

    get_zscore

    pop_arg
	ret

; Notes:
; [1] xmmfunc
; Compute for Z-score (dst_array) from Input (src_array) by getting mean and variance
; rcx       : array size
; rdx       : pointer src_array
; r8        : pointer dst_array
; r9        : pointer to mean
; rbp+32    : pointer to var
;
; [2] mean_register_setup
; note: div 
; size / 4 bit  => ans r remainder  
; eax  / rcx    => eax r edx
;
; [3] get_mean
; gets mean
; INPUT:
;   XMM3 := bulk_1 sum
;   XMM2 := bulk_2 sum
;   XMM1 := residual sum
; RETURNS: XMM0 := sum
;
; [4] mean_add_remainder_loop
; add remaining left-over elements to get residual sum
; INPUT: rsi 
; RETURNS: xmm1 := residual sum
;
; [5] mean_add_bulk_loop
; sum elements in bulk
; RETURNS: 
; XMM2 := bulk_1, 
; XMM3 := bulk_2