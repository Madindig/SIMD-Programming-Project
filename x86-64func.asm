; Names: Campo, Macayan, Madridijo | Section: CSC612M G01
default rel
bit 64

section .data
align 8
zero    dq 0.0
epsilon dq 1.0e-6

section .text
global x86_64func

x86_64func:
	mov ecx, ecx
	mov r11, [rsp + 40]
	cvtsi2sd xmm1, rcx

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
    divsd   xmm0, xmm1
    cvtsd2ss xmm2, xmm0
    movss   [r9], xmm2
    cvtss2sd xmm2, xmm2

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
    divsd   xmm0, xmm1
    cvtsd2ss xmm0, xmm0
    movss   [r11], xmm0
    cvtss2sd xmm0, xmm0
    addsd   xmm0, [epsilon]
    sqrtsd  xmm4, xmm0
    xor     r10d, r10d
    test    rcx, rcx
    jz      .done

.z_loop:
    cvtss2sd xmm3, [rdx + r10*4]
    subsd   xmm3, xmm2
    divsd   xmm3, xmm4
    cvtsd2ss xmm3, xmm3
    movss   [r8 + r10*4], xmm3
    inc     r10
    cmp     r10, rcx
    jb      .z_loop
 
.done:
    ret