.text
.globl au_normal
#####################################################################
# Argument:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)
# Notes:
#####################################################################
au_normal:
	beq $a2, '+', addition
	beq $a2, '-', subtract
	beq $a2 '*', multiply
	beq $a2, '/', divide
	jr $ra

addition:
	add $v0, $a0, $a1
	jr $ra

subtract:
	sub $v0, $a0, $a1
	jr $ra

multiply:
	mul $v0, $a0, $a1
	mfhi $v1
	jr $ra

divide:
	div $v0, $a0, $a1
	mfhi $v1
	jr $ra

