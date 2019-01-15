// func Sasum(N int, X []float32, incX int) float32
TEXT ·Sasum(SB), 7, $0
	MOVQ	N+0(FP), BP
	MOVQ	X_data+8(FP), SI
	MOVQ	incX+32(FP), AX

	// Check data bounaries
	MOVQ	BP, CX
	DECQ	CX
	IMULQ	AX, CX	// CX = incX * (N - 1)
	CMPQ	CX, X_len+16(FP)
	JGE		panic

	// Clear accumulators
	XORPS	X0, X0

	// Setup mask for sign bit clear
	PCMPEQW	X4, X4
	PSRLL	$1, X4

	// Setup strides
	SALQ	$2, AX	// AX = sizeof(float32) * incX

	// Check that there are 4 or more pairs for SIMD calculations
	SUBQ	$4, BP
	JL		rest	// There are less than 4 pairs to process

	// Check if incX != 1 or incY != 1
	CMPQ	AX, $4
	JNE	with_stride

	// Fully optimized loop (for incX == incY == 1)
	full_simd_loop:
		// Clear sign on all four values
		MOVUPS	(SI), X1
		ANDPS	X4, X1

		// Update data pointer
		ADDQ	$16, SI

		// Accumulate the results of multiplications
		ADDPS	X1, X0

		SUBQ	$4, BP
		JGE		full_simd_loop	// There are 4 or more pairs to process

	JMP hsum

with_stride:
	// Setup long strides
	MOVQ	AX, CX
	SALQ	$1, CX 	// CX = 8 * incX

	// Partially optimized loop
	half_simd_loop:
		// Load first two values
		MOVSS	(SI), X1
		MOVSS	(SI)(AX*1), X2

		// Create half-vector
		UNPCKLPS	X2, X1

		// Update data pointers using long strides
		ADDQ	CX, SI

		// Load second two values
		MOVSS	(SI), X2
		MOVSS	(SI)(AX*1), X3

		// Create half-vector
		UNPCKLPS	X3, X2

		// Update data pointer using long strides
		ADDQ	CX, SI
		
		// Create full-vector
		MOVLHPS	X2, X1

		// Clear sign on all four values
		ANDPS	X4, X1

		// Accumulate the result of multiplication
		ADDPS	X1, X0

		SUBQ	$4, BP
		JGE		half_simd_loop	// There are 4 or more values to process

hsum:
	// Horizontal sum
	MOVHLPS X0, X1
	ADDPS	X0, X1
	MOVSS	X1, X0
	SHUFPS	$0xe1, X1, X1
	ADDSS	X1, X0

rest:
	// Undo last SUBQ
	ADDQ	$4,	BP

	// Check that are there any value to process
	JE	end

	loop:
		// Multiply one value
		MOVSS	(SI), X1
		ANDPS	X4, X1

		// Update data pointers
		ADDQ	AX, SI

		// Accumulate the results of multiplication
		ADDSS	X1, X0

		DECQ	BP
		JNE		loop

end:
	// Return the square root of sum
	MOVSS	X0, r+40(FP)
	RET

panic:
	CALL	runtime·panicindex(SB)
	RET
