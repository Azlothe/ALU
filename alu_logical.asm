.include "./bitmacros.asm"
.text
.globl au_logical
#####################################################################
# Arguments:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)
#####################################################################
au_logical:

	beq $a2, '+', addition
	beq $a2, '-', subtract
	beq $a2 '*', multiply
	beq $a2, '/', divide
	jr $ra

# Addition
addition:
	addi $sp, $sp, -16
	sw $fp, 16($sp)
	sw $ra, 12($sp)
	sw $a2, 8($sp)
	addi $fp, $sp, 16
	
	li $a2, 0
	jal add_sub_logical
	
	lw $fp, 16($sp)
	lw $ra, 12($sp)
	lw $a2, 8($sp)
	addi $sp, $sp, 16
	jr $ra

#####################################################################

# Subtraction
subtract:
	addi $sp, $sp, -20
	sw $fp, 20($sp)
	sw $ra, 16($sp)
	sw $a1, 12($sp)
	sw $a2, 8($sp)
	addi $fp, $sp, 20
	
	not $a1, $a1
	li $a2, 1
	jal add_sub_logical

	lw $fp, 20($sp)
	lw $ra, 16($sp)
	lw $a1, 12($sp)
	lw $a2, 8($sp)
	addi $sp, $sp, 20
	jr $ra
	
#####################################################################

# Multiplication
multiply:
	# store fp, ra, a0, a1, s0, s1
	addi $sp, $sp, -28
	sw $fp, 28($sp)
	sw $ra, 24($sp)
	sw $a0, 20($sp)
	sw $a1, 16($sp)
	sw $s0, 12($sp)
	sw $s1, 8($sp)
	addi $fp, $sp, 28

	# check if args need to be changed to unsigned with 2s complement
	# $s1 will be holder for sign of product 
	or $t6, $zero, $a0 # holder
	extract_immed_bit($s0, $a0, 31) # $s0 = $a0[31]
	or $s1, $zero, $s0
	beqz $s0, multiply_a0_positive # if $a0[31] == 0: goto multiply_a0_positive
	
	# a0 is negative
	jal twos_complement # $a0, $a1 are unchanged; result in $v0
	or $t6, $zero, $v0 # update holder t6 with unsigned val to place back into $a0

multiply_a0_positive:
	extract_immed_bit($s0, $a1, 31)
	xor $s1, $s1, $s0 # $s1 = multiplicand[31] xor multiplier[31]
	beqz $s0, multiply_a1_positive

	or $a0, $zero, $a1 # $a0 = $a1
	jal twos_complement # must place new unsigned val in $al; $a0 needs to be changed to original
	or $a1, $zero, $v0

multiply_a1_positive:
	or $a0, $zero, $t6 # t6 is holder from beginning and must hold unsigned val even if updated
	jal mult_unsigned
	
	beqz $s1, mult_finish # does product sign have to be changed; if no, goto mult_finish
	
	or $a0, $zero, $v0
	or $a1, $zero, $v1
	jal twos_complement_64bit

mult_finish:
	lw $fp, 28($sp)
	lw $ra, 24($sp)
	lw $a0, 20($sp)
	lw $a1, 16($sp)
	lw $s0, 12($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 28
	jr $ra

#####################################################################

# Division

# $a0 is dividend; $a1 is divisor
# $v0 is quotient; $v1 is remainder
divide:
	# store fp, ra, a0, a1, s0, s1
	addi $sp, $sp, -28
	sw $fp, 28($sp)
	sw $ra, 24($sp)
	sw $a0, 20($sp)
	sw $a1, 16($sp)
	sw $s0, 12($sp)
	sw $s1, 8($sp)
	addi $fp, $sp, 28

	# $s0 will carry the sign to determine if need 2s complement
	# $s1 will carry the sign for quotient
	# check divisor first, then dividend
	# when checking $a0 (aka dividend), $s0 will also carry sign of remainder
	extract_immed_bit($s0, $a1, 31)
	or $t6, $zero, $a0 # save value
	or $s1, $zero, $s0
	beqz $s0, divide_a1_positive
	
	or $a0, $zero, $a1
	jal twos_complement
	or $a1, $zero, $v0

divide_a1_positive:
	or $a0, $zero, $t6
	extract_immed_bit($s0, $a0, 31)
	xor $s1, $s1, $s0 # $s1 = dividend[31] xor divisor[31] = sign of quotient
	beqz $s0, divide_a0_positive
	
	jal twos_complement
	or $a0, $zero, $v0

divide_a0_positive:
	jal divide_unsigned
	beqz $s0, remainder_positive
	
	or $a0, $zero, $v1
	or $s0, $zero, $v0 # need to save quotient val from being overwritten; can reuse $s0
	jal twos_complement
	or $v1, $zero, $v0
	or $v0, $zero, $s0

remainder_positive:
	beqz $s1, quotient_positive
	
	or $a0, $zero, $v0
	or $s1, $zero, $v1 # need to save remainder val from being overwritten
	jal twos_complement
	or $v1, $zero, $s1

quotient_positive:
	lw $fp, 28($sp)
	lw $ra, 24($sp)
	lw $a0, 20($sp)
	lw $a1, 16($sp)
	lw $s0, 12($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 28
	jr $ra

# au-logical end

#####################################################################
#####################################################################

# Utility Procedures

# Adder/Subtracter like in hardware
add_sub_logical:
	li $t7, 0 # iterator for bit
	or $t2, $zero, $a2 # addition/subtraction starting carry bit

add_sub_for:
	beq $t7, 32, add_sub_end

	extract_nth_bit($t0, $a0, $t7) # a
	extract_nth_bit($t1, $a1, $t7) # b

	xor $t3, $t0, $t1 # a xor b
	and $t0, $t0, $t1 # a and b
	xor $t4, $t2, $t3 # carry_in xor a xor b
	insert_to_nth_bit($v0, $t7, $t4, $t1)
	
	and $t1, $t2, $t3 # (carry_in and a xor b)
	or $t2, $t1, $t0 # carry out
	addi $t7, $t7, 1
	j add_sub_for

add_sub_end:
	or $v1, $zero, $t2 # upgrade to return final carry out
	jr $ra
	
#####################################################################

# Takes $a0 and returns the 2's complement of it in $v0
twos_complement:
	addi $sp, $sp, -24
	sw $fp, 24($sp)
	sw $ra, 20($sp)
	sw $a0, 16($sp)
	sw $a1, 12($sp)
	sw $a2, 8($sp)
	addi $fp, $sp, 24

	not $a0, $a0
	li $a1, 1
	li $a2, 0
	jal add_sub_logical
	
	lw $fp, 24($sp)
	lw $ra, 20($sp)
	lw $a0, 16($sp)
	lw $a1, 12($sp)
	lw $a2, 8($sp)
	addi $sp, $sp, 24
	jr $ra

#####################################################################

# Takes $a1 and $a0 as concatenated 64-bit and returns the 2's complement
# $a0 2's complement goes in $v0
# $a1 2's complement goes in $v1
twos_complement_64bit:
	addi $sp, $sp, -24
	sw $fp, 24($sp)
	sw $ra, 20($sp)
	sw $a0, 16($sp)
	sw $a2, 12($sp) # $a2 is stored before $a1 since $a1 will be loaded in middle of operation
	sw $a1, 8($sp)
	addi $fp, $sp, 24
	
	not $a0, $a0
	li $a1, 1
	li $a2, 0
	jal add_sub_logical # v0 has sum; vl has final carry bit
	
	or $t5, $zero, $v0 # save $a0 2's complement in $t5 for now
	
	lw $a1, 8($sp) # set $a1 to its original value as stored in stack
	not $a1, $a1
	or $a0, $zero, $v1 # set $a0 to final carry bit from getting $a0 2's complement
	jal add_sub_logical
	or $v1, $zero, $v0
	or $v0, $zero, $t5 # give $v0 back $a0 2's complement from holder
	
	lw $fp, 24($sp)
	lw $ra, 20($sp)
	lw $a0, 16($sp)
	lw $a2, 12($sp)
	lw $a1, 8($sp)
	addi $sp, $sp, 24
	jr $ra

#####################################################################
#####################################################################

# Multiplication for unsigned values
mult_unsigned:
	addi $sp, $sp, -16
	sw $fp, 16($sp)
	sw $ra, 12($sp)
	sw $a1, 8($sp)
	addi $fp, $sp, 16
	
	or $v0, $zero, $a1 # lo = multiplier
	li $v1, 0 # hi = 0
	li $t6, 0 # iterator

mult_for:
	beq $t6, 32, mult_end
	extract_immed_bit($t0, $v0, 0) # $t0 = lo lsb
	beqz $t0, mult_lsb0 # if $t0 == 0: goto mult_lsb0

	# current lo lsb is 1; need to add hi with multiplicand
	or $a1, $zero, $v1
	or $t5, $zero, $v0 # temporary holder
	jal add_sub_logical
	
	or $v1, $zero, $v0 # value has been added and set into hi
	or $v0, $zero, $t5 # bring back value with holder
	
mult_lsb0:
	# right shift the hi/lo concat
	srl $v0, $v0, 1
	extract_immed_bit($t0, $v1, 0)
	insert_to_immed_bit($v0, 31, $t0, $t1)
	srl $v1, $v1, 1
	
	addi $t6, $t6, 1
	j mult_for

mult_end:
	lw $fp, 16($sp)
	lw $ra, 12($sp)
	lw $a1, 8($sp)
	addi $sp, $sp, 16
	jr $ra

#####################################################################

# Division for unsigned values
divide_unsigned:
	addi $sp, $sp, -16
	sw $fp, 16($sp)
	sw $ra, 12($sp)
	sw $a0, 8($sp)
	addi $fp, $sp, 16

	or $v0, $zero, $a0 # lower 32 bit is dividend
	li $v1, 0 # set higher 32 bit/remainder to 0
	li $t6, 0 # iterator
divide_for:
	beq $t6, 32, divide_unsigned_end

	# left shift the 64-bit remainder/dividend concat
	sll $v1, $v1, 1
	extract_immed_bit($t0, $v0, 31)
	insert_to_immed_bit($v1, 0, $t0, $t1)
	sll $v0, $v0, 1 # preemptively place a 0 as we shift

	# have to set up $a0 and $a1 for subtraction
	# $a1 is already divisor
	# $a0 must become the remainder
	or $a0, $zero, $v1
	or $t5, $zero, $v0 # save current quotient value since v0 will change; no worries about $v1
	jal subtract
	bltz $v0, divisor_does_not_fit # does subtraction give a negative number; if yes, divisor doesn't fit
	
	# divisor can fit; keep the value and insert 1
	or $v1, $zero, $v0
	li $t0, 1
	insert_to_immed_bit($t5, 0, $t0, $t1)
	j divide_iterate

divisor_does_not_fit:
	# rollback
	or $v1, $zero, $a0

divide_iterate:
	or $v0, $zero, $t5 # new value of quotient ready for next iteration regardless of shift
	addi $t6, $t6, 1
	j divide_for

divide_unsigned_end:
	lw $fp, 16($sp)
	lw $ra, 12($sp)
	lw $a0, 8($sp)
	addi $sp, $sp, 16
	jr $ra
