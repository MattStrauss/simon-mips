.data

	### Provided stack data ###
	stack_beg: .word   0 : 100
	stack_end:
	

	### Provided queue data ###
	sequence_queue: .word 0 : 10
	
	# Ascii messages ###
	user_input_prompt: .asciiz "Enter the pattern that you just watched \n"
	lose_message: .asciiz "Sorry, you lost. Try again sometime! \n" 
	win_message: "Congratulations, you win! \n" 
	correct_sequence: .asciiz "The correct sequence was "
	
	
	### Lookup tables ###
	BoxTable: .word 1, 1, 1, 'B' # 66 is capital B
		  .word 2, 17, 1, 'G' # 71 is capital G
		  .word 3, 1, 17, 'R' # 82 is capital R
		  .word 4, 17, 17, 'Y' # 89 is capital Y
		  
	
	ColorTable: #.byte 'B', 0xff, 0x00, 0x00 # Blue
		    #.byte 'G', 0x00, 0xff, 0xff # Green
		    #.byte 'R', 0xff, 0xff, 0xff # Red
		    #.byte 'Y', 0xff, 0xff, 0x00 # Yellow
		    #.byte 'W', 0xff, 0xff, 0xff # White
		    #.byte '0', 0x00, 0x00, 0x00 # Black
		    
		    .word 'B', 0x000000ff # Blue
		    .word 'G', 0x0000ff00 # Green
		    .word 'R', 0x00ff0000 # Red
		    .word 'Y', 0x00ffff00 # Tellow
		    .word 'W', 0x00ffffff # White
		    .word '0', 0x00000000 # Black
		 
	

.text

main: 
	init: 
		la $sp, stack_end
	        la $s1, sequence_queue # reset $s1 (~$qp) for sequence
	        la $s6, 0x10040000 # base address of display
	        li $s7, 0 # keeps track of the number of ints in the sequence
	        
	        
	incrementSequence:
		jal getRandomNumber 
		
		move $a0, $v0 # move the random sequence number to $a0 for below method call
		la $s1, sequence_queue # reset $sp (~$qp) for sequence
		jal addNumberToSequence
		addi $s7, $s7, 1 # increment number of sequence items
		
	play: 
	
		la $s1, sequence_queue # reset $sp (~$qp) for sequence
		jal lightItUp
		
		prepareGetUserInput: 
			la $s1, sequence_queue # reset $sp (~$qp) for sequence
			jal getUserInput
		
		
	
						
# generates random number
# argument: none
# return: (int) $v0 contains the random number that was generated and manipulated
getRandomNumber:

	# get seed
	li $a0, 0 # generator number/id
	li, $v0, 30 # sys call for system time
	syscall 
	move $t0, $a0 # store the LSB returned by sys time call to $t0
	
	# get random number
	li $a0, 0 # generator number/id
	move $a1, $t0 # seed for generator 
	li, $v0, 40 # seed random number generator 
	syscall 
	li $a1, 4 # upper bound of random number
	li $v0, 42 # generate random number
	syscall 
	
	beq $a0, 4, finishRandomNumberRoutine
	
	# convert random number to usable sequence number, unless it's 4, then skip the add
	addi $v0, $a0, 1 # add 1 so that the returned value will be in the set {1, 2, 3} which matches the game setup
	
	finishRandomNumberRoutine:
	jr $ra



# adds an additional number to the sequence
# argument: (int) $a0 = number to add to sequence 
# return: none
addNumberToSequence: 

	sll $t0, $s7, 2 # multiply seq # by four to get proper offset
	add $s1, $s1, $t0 # move the queue pointer to the proper mem location

	finishAddNumberSequenceRoutine: 
	sw $a0, ($s1) # store arg 0 (next number for sequence) onto the queue
	
	jr $ra
		
		
	

# uses the current sequence to display the required user input
# argument: none
# return: none	
# dependency: pause method
lightItUp:

	subi $sp, $sp, 4 # make room for the saved items below
	sw $s3, 0($sp) # store $s3 before changing it below, per register protocols
	
	li $s3, 0 # counter 
	
	displaySequence: 
		lw $t1, 0($s1) # load the current sequence number into $t1
		
		la $t0, BoxTable # load base address of color table to $t0
	
		boxTableLoop:
			lw $t2, 0($t0) # load the next word into $t2, this word has the sequence character
			beq $t1, $t2, loadValues
			addi $t0, $t0, 16 # move to the next row in the BoxTable
			b boxTableLoop
		
			loadValues:
				lw $a0, 4($t0) # load the x-coordiante 
				lw $a1, 8($t0) # load the y-coordinate
				lw $a2, 12($t0) # load the color character
				li $a3, 12 # size of box 
		
		 
		displayIt:
			jal drawBox # draw the box on the screen
			
			jal pause # sleep for one second to give the user a chance to see the display
			
			jal clearDisplay
			
			addi $s3, $s3, 1 # increment counter
			add $s1, $s1, 4 # increment the sequence number for the next display
		
			blt $s3, $s7, displaySequence # loop if counter is not equal to the total number of items in the sequence
			
			lw $s3, 0($sp) # restore $s3
			addi $sp, $sp, 4 # reset the $sp back to its original state before moving out of this method
		
			b prepareGetUserInput
		
		
		
# pauses system for one second
# argument: none
# return: none
pause:	
	li $t0, 1000 # number of miliseconds to wait
	
	# get intitial time and store in $t1
	li $v0, 30 # sys call for system time
	syscall 
	move $t1, $a0 # store the LSB returned by sys time call to $t1
	
	waitTimeLoop: 
		# get current time
		syscall 
	
		# subtract init time from current time and compare to required wait time
		sub $t2, $a0, $t1 # subtract init time from current time and store in $t2
		blt $t2, $t0, waitTimeLoop # compare diff to required wait time, loop if less than
		
		jr $ra
	

	
# draw a black box over the entire display
# argument: none
# return: none				
clearDisplay:	
	subi $sp, $sp, 4 # make room for the saved items below
	sw $ra, 0($sp) # store $ra
	
	li $a0, 0 # set $a0 to zero
	li $a1, 0 # set $a1 to zero
	li $a2, '0' # color should be black which is char 0
	li $a3, 32 # full screen, all 32 rows
	
	jal drawBox
	
	lw $ra, 0($sp) # put the correct $ra back to get to this method's caller below
	addi $sp, $sp, 4 # adjust $sp back to its original state
	jr $ra
	
	


# draw a horizontal line of an arbitraty lennth
# argument: $a0: x-coordinate, $a1: y-coordinate, $a2: color, $a3: rows of box
# return: none				
drawBox:
	move $s0, $a3 # set $s0 equal to $a3
	subi $sp, $sp, 24 # make room for the saved items below
	sw $ra, 0($sp) # store $ra
	sw $s0, 20($sp) # store $s0 before changing below
	
	boxLoop:
		sw $a1, 4($sp) # store $a1
		sw $a2, 8($sp) # store $a2
		sw $a0, 12($sp) # store $a0
		sw $a3, 16($sp) # store $a3
		
		jal drawHorizontalLine
		
		lw $a1, 4($sp) # store $a1
		lw $a2, 8($sp) # store $a2
		lw $a0, 12($sp) # store $a0
		lw $a3, 16($sp) # store $a3
		
		addi $a1, $a1, 1 # increment the y-coordinate
		subi $s0, $s0, 1 # decrement box row count
		
		bnez $s0, boxLoop
		
		lw $s0, 20($sp) # restore $s0 to its state before this method
		lw $ra, 0($sp) # put the correct $ra back to get to this method's caller below
		addi $sp, $sp, 24 # adjust $sp back to its original state
	
		jr $ra



# draw a horizontal line of an arbitraty lennth
# argument: $a0: x-coordinate, $a1: y-coordinate, $a2: color, $a3: length of line
# return: none				
drawHorizontalLine:
	subi $sp, $sp, 20 # make room for the saved items below
	sw $ra, 0($sp) # store $ra

	horzontalLineLoop: 
		sw $a1, 4($sp) # store $a1
		sw $a2, 8($sp) # store $a2
		sw $a0, 12($sp) # store $a0
		sw $a3, 16($sp) # store $a3
		
		jal drawDot
		
		lw $a1, 4($sp) # store $a1
		lw $a2, 8($sp) # store $a2
		lw $a0, 12($sp) # store $a0
		lw $a3, 16($sp) # store $a3
		
		addi $a0, $a0, 1 # increment the x-coordinate
		subi $a3, $a3, 1 # decrement the line number
		bnez $a3, horzontalLineLoop
 
		lw $ra, 0($sp) # put the correct $ra back to get to this method's caller below
		addi $sp, $sp, 20 # adjust $sp back to its original state
	
		jr $ra
		
		
# draw a vertical line of an arbitraty lennth
# argument: $a0: x-coordinate, $a1: y-coordinate, $a2: color, $a3: length of line
# return: none				
drawVerticalLine:
	subi $sp, $sp, 20 # make room for the saved items below
	sw $ra, 0($sp) # store $ra

	verticalLineLoop: 
		sw $a1, 4($sp) # store $a1
		sw $a2, 8($sp) # store $a2
		sw $a0, 12($sp) # store $a0
		sw $a3, 16($sp) # store $a3
		
		jal drawDot
		
		lw $a1, 4($sp) # store $a1
		lw $a2, 8($sp) # store $a2
		lw $a0, 12($sp) # store $a0
		lw $a3, 16($sp) # store $a3
		
		addi $a1, $a1, 4 # increment the y-coordinate
		subi $a3, $a3, 1 # decrement the line number
		bnez $a3, verticalLineLoop
 
		lw $ra, 0($sp) # put the correct $ra back to get to this method's caller below
		addi $sp, $sp, 20 # adjust $sp back to its original state
	
		jr $ra
	
	
# draws a dot of the chosen at the location provided by the x and y coordinate 
# argument: $a0: x-coordinate, $a1: y-coordinate, $a2: color
# return: none
drawDot:
	subi $sp, $sp, 8 # make room for the saved items below
	sw $ra, 4($sp) # store $ra
	sw $a2, 0($sp) # store the chosen color
	
	jal calculateAddress
	
	lw $a2, 0($sp) # restore $a2
	sw $v0, 0($sp) # save the pixel mem location for below
	
	jal getColor
	lw $v0, 0($sp) # restore $v0
	
	sw $v1, 0($v0) # draw the dot
	lw $ra, 4($sp) # put the correct $ra back to get to this method's caller below
	addi $sp, $sp, 8 # adjust $sp back to its original state
	
	jr $ra
	

# caclulates address of pixel based off y and x coordinates 
# argument: $a0: x-coordinate, $a1: y-coordinate, $a2: color
# return: $v0: calculated memory address of pixel based on (x,y) Cartesian coordinates 
calculateAddress: 
	
	move $v0, $s6 # set $v0 to the base address of display
	sll $a0, $a0, 2 # multiply x coordiante by 4 to get proper column
	sll $a1, $a1, 7 # multiply y coordinate by 32 to get the row and then by 4 (b/c stored as words)
	
	add $a0, $a0, $a1 # add the two numbers to get the proper offset and store in $a1
	add $v0, $v0, $a0 # add the offset to $v0, which already contained the base address of display
	
	jr $ra

# return the color value in $v1 based on the argument
# argument: $a2: contains character B, G, R, Y or 0
# return: $v1: 32 bit color value
getColor:
	
	la $t0, ColorTable # load base address of color table to $t0
	
	colorTableLoop:
		lw $t1, 0($t0) # load the next byte into $t1, this byte has the color character
		beq $t1, $a2, loadColorValue
		addi $t0, $t0, 8 # move 2 word up to get the next color character
		b colorTableLoop
		
		loadColorValue:
			
			lw $v1, 4($t0) # place the whole word in $v1
			
			jr $ra
			


# get the user's input 
# argument: none
# return: none		
getUserInput: 

	li $t0, 0 # counter

	getInputLoop:
	
		beq $t0, $s7, sequence_solved # if the user guessed all the items in the current sequence
		
		lw $t1, 0($s1) # load the current sequence number into $t1
		
		li $v0, 4 # print string
		la $a0, user_input_prompt # load the user input prompt address
		syscall 
	
		li $v0, 12 # read char from user (read value goes into $v0)
		syscall
		subi $t2, $v0, 48 # change char to decimal value representation
		
		bne $t1, $t2, lose_notification # if user input doesn't match pattern, they lost
		
		addi $t0, $t0, 1 # increment the counter
		addi $s1, $s1, 4 # move the queue pointer up one position
		
		beq $t1, $t2, getInputLoop # if the user guessed the right number, loop again
		


# user got sequence right, determine if another needs to be added or they won
# argument: none
# return: none
sequence_solved:
	beq $s7, 5, win_notfication # if the person solved the sequence with 5 items, they win
	b incrementSequence


# notify user that they lost
# argument: none
# return: none
lose_notification:

	li $v0, 4 # print string
	la $a0, lose_message # load the user input prompt address
	syscall 
	
	b printCorrectSequence

		
# notify user that they won 
# argument: none
# return: none	
win_notfication:

	li $v0, 4 # print string
	la $a0, win_message # load the user input prompt address
	syscall 
	
	b exit
	

# exit game
# argument: none
# return: none	
exit: 
	li $v0, 10 # exit 
	syscall 
	
	
# print the correct sequence to the display so the user can see what they did wrong
printCorrectSequence: 
	la $a0, correct_sequence # load the correct sequence message
	syscall 
	la $s1, sequence_queue # reset $sp (~$qp) for sequence
	
	li $t0, 0
	li $v0, 1 # print int
	printLoop:
		lw $a0, 0($s1) # load the current sequence number into $t1
		syscall

		addi $t0, $t0, 1
		addi $s1, $s1, 4
		blt $t0, $s7, printLoop
	
	b exit
		
		
	
		
