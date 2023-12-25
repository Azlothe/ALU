#<------------------ MACRO DEFINITIONS ---------------------->#


# $regD will be the value of the nth bit
# $regS is the source bit
# $regT is the bit position
.macro extract_nth_bit($regD, $regS, $regT)
	# can reuse $regD in intermediate operations
	srlv $regD, $regS, $regT
	andi $regD, $regD, 1
.end_macro

# same macro but can take whichever bit position needed
.macro extract_immed_bit($regD, $regS, $arg)
	srl $regD, $regS, $arg
	andi $regD, $regD, 1
.end_macro



# $regD is source bit
# $regS is the position of the bit to be inserted
# $regT is the bit value of what to insert
# $maskReg is a temporary mask
.macro insert_to_nth_bit($regD, $regS, $regT, $maskReg)
	li $maskReg, 1
	sllv $maskReg, $maskReg, $regS

	not $maskReg, $maskReg
	and $regD, $regD, $maskReg

	ori $maskReg, $regT, 0
	sllv $maskReg, $maskReg, $regS

	or $regD, $regD, $maskReg
.end_macro


# same macro but can insert at whichever bit position needed
.macro insert_to_immed_bit($regD, $arg, $regT, $maskReg)
	li $maskReg, 1
	sll $maskReg, $maskReg, $arg

	not $maskReg, $maskReg
	and $regD, $regD, $maskReg

	ori $maskReg, $regT, 0
	sll $maskReg, $maskReg, $arg

	or $regD, $regD, $maskReg
.end_macro