; Names: Campo, Macayan, Madridijo | Section: CSC612M G01
; adapted to x86-64 assembly from the C variation

section .data
align 8
zero    dq 0.0      ;accumulator
one     dq 1.0      ;numerator for reciprocal solution
epsilon dq 1.0e-6   ; constant to avoid division by zero

section .text
default rel
bits 64

global x86_64func

x86_64func:
    mov ecx, ecx        ;zero-extend 32-bit into RCX and clear upper 32 bits
    mov r11, [rsp + 40] ;load 5th arguement
    cvtsi2sd xmm1, rcx  ;convert to double for more accurate computation

    movsd xmm0, [zero]
    xor r10d, r10d
    test rcx, rcx
    jz .mean_div

.sum_loop:
    cvtss2sd xmm3, [rdx + r10*4]
    addsd   xmm0, xmm3           
    inc     r10                  
    cmp     r10, rcx             
    jb      .sum_loop

.mean_div:
    divsd   xmm0, xmm1           ; mean = sum / n
    cvtsd2ss xmm2, xmm0          ; convert mean to float as required by the specification
    movss   [r9], xmm2          
    cvtss2sd xmm2, xmm2          ; convert mean back to double for variance calculation

    movsd   xmm0, [zero]
    xor     r10d, r10d
    test    rcx, rcx
    jz      .var_div

.var_loop:
    cvtss2sd xmm3, [rdx + r10*4] 
    subsd   xmm3, xmm2              
    mulsd   xmm3, xmm3              
    addsd   xmm0, xmm3              
    inc     r10
    cmp     r10, rcx
    jb      .var_loop

.var_div:
    divsd   xmm0, xmm1          ; var = sumsq / n  (population variance)
    cvtsd2ss xmm0, xmm0         ; convert variance to float as required by the specification
    movss   [r11], xmm0
    cvtss2sd xmm0, xmm0         ; back to double
    addsd   xmm0, [epsilon]
    sqrtsd  xmm4, xmm0
    movsd   xmm1, [one]
    divsd   xmm1, xmm4          ; xmm1 = 1 / std (one divide here, multiplies in the loop)
    xor     r10d, r10d
    test    rcx, rcx
    jz      .done

.z_loop:
    movss   xmm3, [rdx + r10*4]
    cvtss2sd xmm3, xmm3
    subsd   xmm3, xmm2
    mulsd xmm3, xmm1
    cvtsd2ss xmm3, xmm3
    movss   [r8 + r10*4], xmm3
    inc     r10
    cmp     r10, rcx
    jb      .z_loop
 
.done:
    ret