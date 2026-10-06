; Names: Campo, Macayan, Madridijo | Section: CSC612M G01
section .data
one dq 1.0
small_float dq 0.000001
section .text
bits 64
default rel

global ymmfunc

; rcx : size
; rdx : pointer src_array
; r8 : pointer dst_array
; r9 : pointer to mean
; rbp+32 : pointer to var
ymmfunc:
	push rsi
	push rdi
	push r12
	push rbp
	mov rbp, rsp
	add rbp, 8*5			
		push rcx		; save size in stack
		mov r12, rdx	; save pointer to src_array in r12

		xor rdx, rdx	; clear rdx for div
		mov rax, rcx	; mov size to rax as dividend (edx:eax)
		mov rcx, 8		; mov 8 to rcx as divisor
		div ecx			; eax = # of add loops | edx = remainder

		mov ecx, eax	; mov # of add loops to ecx
		mov rsi, rdx	; store remainder in rsi
		mov rdi, rcx	; store number of add loops in rdi
		mov rdx, r12	; restore pointer to src_array in rdx

		vpxor ymm2, ymm2, ymm2		; clear ymm2 for accumulation
		vpxor ymm3, ymm3, ymm3		; clear ymm3 for accumulation
		
		pxor xmm1, xmm1		; clear xmm1 accumlation in REMAINDER_LOOP
		cmp rcx, 0			; check if add loops is 0
		jz REMAINDER_LOOP	; if add loops is 0, skip add loop and go to REMAINDER_LOOP

		ADD_LOOP:
			vcvtps2pd ymm0, [rdx]		; first 4 floats to double-precision FP		
			vcvtps2pd ymm1, [rdx+16]	; second 4 floats to double-precision FP	
			vaddpd ymm2, ymm0, ymm2		; accumulate 1st 4 sums in ymm2
			vaddpd ymm3, ymm1, ymm3		; accumulate 2nd 4 sums in ymm3
			add rdx, 32					; move to next 8 single-precision floats
			loop ADD_LOOP				; loop until ecx = 0

		pxor xmm1, xmm1		; clear xmm1 accumlation in REMAINDER_LOOP
		mov rcx, rsi		; move remainder to rcx to use in REMAINDER_LOOP

		cmp rcx, 0			; check if remainder is 0
		jz SUM_AND_MEAN		; if remainder is 0, skip remainder loop and go to SUM_AND_MEAN

		REMAINDER_LOOP:
			cvtss2sd xmm0, [rdx]	; load remaining single-precision FP as double-precision FP
			addsd xmm1, xmm0		; accumulate remaining double-precision FP
			add rdx, 4				; move to next float
			loop REMAINDER_LOOP		; loop until rcx = 0

		SUM_AND_MEAN:

		vhaddpd ymm2, ymm2, ymm3		; [a b c d] + [e f g h] = [ab cd ef gh]
		vhaddpd ymm2, ymm2, ymm2		; [ab cd ef gh] + [ab cd ef gh] = [abcd efgh abcd efgh]
		vpermpd ymm2, ymm2, 0b10110100	; swap 3rd and 4th double-precision FP in ymm2 to get [abcd efgh efgh abcd]
		vextractf128 xmm0, ymm2, 1		; extract upper 128 bits of ymm2 to xmm0
		addsd xmm0, xmm2				; add lower low 32 (xmm2 : abcd) and upper low 32 (xmm0 : efgh) of ymm2 to get the sum w/o remainder 
		addsd xmm0, xmm1				; add the remainder sum (xmm1) to the partial sum (xmm0) to get the total sum in xmm0

		pop rcx				; restore size from stack
		cvtsi2sd xmm1, rcx	; convert size to double-precision FP in xmm1
		divsd xmm0, xmm1	; divide sum by size to get mean in xmm0
		cvtsd2ss xmm2, xmm0	; convert mean to single-precision FP in xmm2
		movss [r9], xmm2	; store in memory pointed by r9

		mov rdx, r12		; restore pointer to src_array in rdx

		; TO DO: VAR_ADD_LOOP; VAR_REMAINDER_LOOP; variance calculation; denominator calculation; Z_LOOP; Z_REMAINDER_LOOP
		; rsi : remainder | rdi : # of add loops | xmm0 : mean | xmm1 : size in double-precision FP | rdx : pointer to src_array
		; USE ymm2 onwards to preserve the mean and size values for variance calculation

		vpxor ymm4, ymm4, ymm4		; clear ymm4 for accumulation
		vpxor ymm5, ymm5, ymm5		; clear ymm5 for accumulation
		vbroadcastsd ymm0, xmm0		; broadcast mean to ymm0 for variance calculation

		mov rcx, rdi				; move # of add loops to rcx to use in VAR_ADD_LOOP
		pxor xmm3, xmm3				; clear xmm3 accumlation in VAR_REMAINDER_LOOP
		cmp rcx, 0					; check if add loops is 0
		jz VAR_REMAINDER_LOOP		; if add loops is 0, skip add loop and go to VAR_REMAINDER_LOOP

		VAR_ADD_LOOP:
			vcvtps2pd ymm2, [rdx]			; first 4 single-precision FP to double-precision FP
			vcvtps2pd ymm3, [rdx+16]		; second 4 single-precision FP to double-precision FP
			vsubpd ymm2, ymm2, ymm0			; subtract mean from first 4 floats
			vsubpd ymm3, ymm3, ymm0			; subtract mean from second 4 floats
			vfmadd231pd ymm4, ymm2, ymm2	; square the difference for first 4 floats and then accumulate in ymm4
			vfmadd231pd ymm5, ymm3, ymm3	; square the difference for second 4 floats and then accumulate in ymm5
			add rdx, 32						; move to next 8 single-precision floats
			loop VAR_ADD_LOOP				; loop until ecx = 0

		pxor xmm3, xmm3		; clear xmm3 accumlation in VAR_REMAINDER_LOOP
		mov rcx, rsi		; move remainder to rcx to use in VAR_REMAINDER_LOOP

		cmp rcx, 0			; check if remainder is 0
		jz SUM_AND_VAR		; if remainder is 0, skip remainder loop and go to SUM_AND_VAR

		VAR_REMAINDER_LOOP:
			cvtss2sd xmm2, [rdx]			; load remaining single-precision FP
			subsd xmm2, xmm0				; subtract mean from remaining single-precision FP
			vfmadd231sd xmm3, xmm2, xmm2	; square the difference for remaining single-precision FP and then accumulate in xmm3
			add rdx, 4						; move to next float
			loop VAR_REMAINDER_LOOP			; loop until rcx = 0

		SUM_AND_VAR:

		vhaddpd ymm4, ymm4, ymm5		; [a b c d] + [e f g h] = [ab cd ef gh]
		vhaddpd ymm4, ymm4, ymm4		; [ab cd ef gh] + [ab cd ef gh] = [abcd efgh abcd efgh]
		vpermpd ymm4, ymm4, 0b10110100	; swap 3rd and 4th double-precision FP in ymm4 to get [abcd efgh efgh abcd]
		vextractf128 xmm2, ymm4, 1		; extract upper 128 bits of ymm4 to xmm2
		addsd xmm2, xmm4				; add lower low 32 (xmm4 : abcd) and upper low 32 (xmm2 : efgh) of ymm4 to get the sum w/o remainder 
		addsd xmm2, xmm3				; add the remainder sum (xmm3) to the partial sum (xmm2) to get the total sum in xmm2

		divsd xmm2, xmm1		; divide sum by size to get variance in xmm2
		cvtsd2ss xmm3, xmm2		; convert variance to single-precision FP in xmm3
		mov rax, [rbp+32]		; load pointer to register from the stack
		movss [rax], xmm3		; store variance as single-precision FP in memory pointed to by pointer in rax (also in rbp+32)

		mov rdx, r12		; restore pointer to src_array in rdx

		; rsi : remainder | rdi : # of add loops | xmm0 : mean | xmm1 : size in single-precision FP | xmm2 : variance | rdx : pointer to src_array
		; | ymm2 : z-score denominator (stddev)
		; USE ymm3 onwards to preserve the mean, size, and denominator values for z-score calculation

		addsd xmm2, [small_float]	; add small_float to variance
		sqrtsd xmm2, xmm2			; calculate square root of variance to get stddev (denominator) in xmm2
		movsd  xmm3, [one]          ;
		divsd  xmm3, xmm2			; reciprocal of stddev in xmm3
		vbroadcastsd ymm2, xmm3		; broadcast reciprocal of denominator to ymm2 for z-score calculation
		
		mov rcx, rdi				; move # of add loops to rcx to use in Z_LOOP
		cmp rcx, 0					; check if add loops is 0
		jz Z_REMAINDER_LOOP			; if add loops is 0, skip add loop and go to Z_REMAINDER_LOOP

		Z_LOOP:
			vcvtps2pd ymm3, [rdx]		; first 4 single-precision FP to double-precision FP
			vcvtps2pd ymm4, [rdx+16]	; second 4 single-precision FP to double-precision FP
			vsubpd ymm3, ymm3, ymm0		; subtract mean from first 4 floats
			vsubpd ymm4, ymm4, ymm0		; subtract mean from second 4 floats
			vmulpd ymm3, ymm3, ymm2		; multiply by reciprocal of stddev to get z-scores for first 4 floats
			vmulpd ymm4, ymm4, ymm2		; multiply by reciprocal of stddev to get z-scores for second 4 floats
			vcvtpd2ps xmm3, ymm3		; convert first 4 z-scores to single-precision FP
			vcvtpd2ps xmm4, ymm4		; convert second 4 z-scores to single-precision FP
			vmovdqu [r8], xmm3			; store first 4 z-scores
			vmovdqu [r8+16], xmm4		; store second 4 z-scores
			add r8, 32					; move to next 4 floats in dst_array
			add rdx, 32					; move to next 4 floats in src_array
			loop Z_LOOP					; loop until rcx = 0

		mov rcx, rsi		; move remainder to rcx to use in Z_REMAINDER_LOOP

		cmp rcx, 0			; check if remainder is 0
		jz END		; if remainder is 0, skip remainder loop and go to END

		Z_REMAINDER_LOOP:
			cvtss2sd xmm3, [rdx]	; load remaining single-precision FP as double-precision FP
			subsd xmm3, xmm0		; subtract mean from remaining single-precision FP
			mulsd xmm3, xmm2		; multiply by reciprocal of stddev to get z-score for remaining single-precision FP
			cvtsd2ss xmm3, xmm3		; convert z-score to single-precision FP
			movss [r8], xmm3		; store z-score
			add rdx, 4				; move to next float in src_array
			add r8, 4				; move to next float in dst_array
			loop Z_REMAINDER_LOOP	; loop until rcx = 0

		END:

	pop rbp
	pop r12
	pop rdi
	pop rsi
	ret