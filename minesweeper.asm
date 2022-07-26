.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


; Initial program execution begins with loading the intro screen.
	jmp show_intro_screen


;*******************************************************************************
;*  Constants                                                                  *
;*******************************************************************************


; c64 graphics addresses and built-in routines. Some are only used during 
; 	initial startup, but are defined here for the sake of readability.


; keyboard I/O
GETCHAR = $FFE4
PUTCHAR = $FFD2


; SID chip addresses used for pseudorandom number generation
SID_CTRL_3 = $D412
SID_FREQ_3_LOW = $D40E
SID_FREQ_3_HIGH = $D40F
RANDOM = $D41B


; video mode and video memory constants
FRAME_COLOR = $D020
BACKGROUND_COLOR = $D021
V_MODE_CTRL = $D011
VIC_BANK_SELECT = $DD00
V_MEMORY_LOCATION = $D018
COLOR = $4000
BITMAP = $6000


; sprite position addresses
INNER_SPRITE_X = $D000
INNER_SPRITE_Y = $D001
OUTER_SPRITE_X = $D002
OUTER_SPRITE_Y = $D003
SPRITES_X_MSB = $D010


; Game constants
X_RANGE = 20
Y_RANGE = 12
TOTAL_CELLS = (X_RANGE*Y_RANGE)
MINES = 40


;*******************************************************************************
;*  Zero-Page Variables and Pointers                                           *
;*******************************************************************************


; Game Over flag. 0 when game is ongoing, 1 when current game is won or lost.
game_over = $02


; $03 and $04 are scratch variables, used for several purposes.
scratch = $03


; Stores the position of the cursor. These values are sometimes manipulated to 
;	engage a click on nearby cells, but are always returned to their 
;	previous values before executing other code.
cursor_x = $05
cursor_y = $06


; These store line and column indexes for iterating through the board. Since in
;	some applications (such as graphics processing) each cell is represented
;	by multiple bytes, a simple byte offset from the beginning of the 
;	relevant array is insufficient. These provide an easy way to tell when 
;	the end of the array is reached.
current_line = $9B
current_col = $9C


; These variables conflict with uses of the scratch variables, but not with each
;	other, so they share a single separate address.
mines_placed = $2A
line_of_three = $2A
current_color = $2A


; Pointers into various memory locations used in the representation of cells.
cells_ptr = $FB
color_ptr = $FD
bitmap_ptr = $F7
graphics_ptr = $F9


; Stores an address to be jumped to for a specific operation, used in the
;	abstract looping routines. Currently unused, will be updated later.
routine_var = $C1


;*******************************************************************************
;*  Common Subroutines                                                         *
;*******************************************************************************


; These subroutines are used throughout the code for various purposes, so they
;	are defined before the main game code for the sake of readability.


; ******** Pointer manipulation routines ********
; These are used to move pointers into the various structures used in the
; 	representation of the board, both in terms of state and graphics.

; ------------------------------------------------


; These four routines adjust the position of a pointer into the cell state 
;	array. Each cell is represented by one byte. The bit format of this
;	state byte is explained with the cell array definition, which is at the
;	very bottom of this source file.

cells_ptr_right:
	lda cells_ptr
	clc
	adc #1
	sta cells_ptr
	lda cells_ptr+1
	adc #0
	sta cells_ptr+1
	rts
	
cells_ptr_left:
	lda cells_ptr
	sec
	sbc #1
	sta cells_ptr
	lda cells_ptr+1
	sbc #0
	sta cells_ptr+1
	rts
	
cells_ptr_up:
	lda cells_ptr
	sec
	sbc #(X_RANGE)
	sta cells_ptr
	lda cells_ptr+1
	sbc #0
	sta cells_ptr+1
	rts
	
cells_ptr_down:
	lda cells_ptr
	clc
	adc #(X_RANGE)
	sta cells_ptr
	lda cells_ptr+1
	adc #0
	sta cells_ptr+1
	rts
	
; ------------------------------------------------


; Bitmap pointer manipulation routines: Adjust the position of the pointer into
;	bitmap screen memory by line and column.	

bitmap_ptr_right:
	lda bitmap_ptr
	clc
	adc #8
	sta bitmap_ptr
	lda bitmap_ptr+1
	adc #0
	sta bitmap_ptr+1
	rts
	
bitmap_ptr_left:
	lda bitmap_ptr
	sec
	sbc #8
	sta bitmap_ptr
	lda bitmap_ptr+1
	sbc #0
	sta bitmap_ptr+1
	rts
	
bitmap_ptr_down:
	inc bitmap_ptr+1
	lda bitmap_ptr
	clc
	adc #64
	sta bitmap_ptr
	lda bitmap_ptr+1
	adc #0
	sta bitmap_ptr+1
	rts
	
bitmap_ptr_up:
	dec bitmap_ptr+1
	lda bitmap_ptr
	sec
	sbc #64
	sta bitmap_ptr
	lda bitmap_ptr+1
	sbc #0
	sta bitmap_ptr+1
	rts
	
; ------------------------------------------------


; Color pointer manipulation routines: Adjust a pointer into screen memory,
;	which is used to store color information in bitmap mode.
	
color_ptr_right:
	lda color_ptr
	clc
	adc #1
	sta color_ptr
	lda color_ptr+1
	adc #0
	sta color_ptr+1
	rts
	
color_ptr_left:
	lda color_ptr
	sec
	sbc #1
	sta color_ptr
	lda color_ptr+1
	sbc #0
	sta color_ptr+1
	rts
	
color_ptr_down:
	lda color_ptr
	clc
	adc #(X_RANGE*2)
	sta color_ptr
	lda color_ptr+1
	adc #0
	sta color_ptr+1
	rts
	
color_ptr_up:
	lda color_ptr
	sec
	sbc #(X_RANGE*2)
	sta color_ptr
	lda color_ptr+1
	sbc #0
	sta color_ptr+1
	rts
	
; ------------------------------------------------


; Graphics pointer manipulation routines: These adjust a pointer between the
;	four 8x8 graphics cells that make up one 16x16 board cell. The four
;	sub-cells are defined in the order top-left, top-right, bottom-left,
;	bottom-right. These routines adjust the pointer between these four 
;	locations, in the order top-left -> top-right -> bottom-right -> 
;	bottom-left -> top-left, given that the pointer starts in the top-left
;	position.
	
graphics_ptr_right:
	lda graphics_ptr
	clc
	adc #8
	sta graphics_ptr
	lda graphics_ptr+1
	adc #0
	sta graphics_ptr+1
	rts
	
graphics_ptr_left:
	lda graphics_ptr
	sec
	sbc #8
	sta graphics_ptr
	lda graphics_ptr+1
	sbc #0
	sta graphics_ptr+1
	rts
	
graphics_ptr_down:
	lda graphics_ptr
	clc
	adc #16
	sta graphics_ptr
	lda graphics_ptr+1
	adc #0
	sta graphics_ptr+1
	rts
	
graphics_ptr_up:
	lda graphics_ptr
	sec
	sbc #16
	sta graphics_ptr
	lda graphics_ptr+1
	sbc #0
	sta graphics_ptr+1
	rts
	
; ------------------------------------------------


; Cursor adjustment routines: These not only adjust the cursor index variables,
;	but also adjust the location of the cursor sprites accordingly.
	
cursor_left:
	lda cursor_x
	cmp #0
	bne @move
	rts
@move:
	dec cursor_x
	lda OUTER_SPRITE_X
	sec
	sbc #16
	sta OUTER_SPRITE_X
	lda INNER_SPRITE_X
	sec
	sbc #16
	sta INNER_SPRITE_X
	bcc @set_msb
	rts
@set_msb:
	lda #$00
	sta SPRITES_X_MSB
	rts
	
	
cursor_right:
	lda cursor_x
	cmp #(X_RANGE-1)
	bne @move
	rts
@move:
	inc cursor_x
	lda OUTER_SPRITE_X
	clc
	adc #16
	sta OUTER_SPRITE_X
	lda INNER_SPRITE_X
	clc
	adc #16
	sta INNER_SPRITE_X
	bcs @set_msb
	rts
@set_msb:
	lda #$03
	sta SPRITES_X_MSB
	rts
	
cursor_up:
	lda cursor_y
	cmp #0
	bne @move
	rts
@move:
	dec cursor_y
	lda OUTER_SPRITE_Y
	sec
	sbc #16
	sta OUTER_SPRITE_Y
	lda INNER_SPRITE_Y
	sec
	sbc #16
	sta INNER_SPRITE_Y
	rts
	
	
cursor_down:
	lda cursor_y
	cmp #(Y_RANGE-1)
	bne @move
	rts
@move:
	inc cursor_y
	lda OUTER_SPRITE_Y
	clc
	adc #16
	sta OUTER_SPRITE_Y
	lda INNER_SPRITE_Y
	clc
	adc #16
	sta INNER_SPRITE_Y
	rts

; ------------------------------------------------


; *********** Other Common Subroutines ***********
	
	
; This simple routine is used to draw one individual 8x8 pixel graphics cell.
;	The graphics pointer has previously been set to the correct graphics
;	cell, defined in the penultimate section of this file just before the
;	cell byte array, and the color variable in the zero page has been set
;	to the cell's color. 
	
draw_one_cell:
	lda current_color
	ldy #0
	sta (color_ptr), y
@loop:
	cpy #8
	beq @end
	lda (graphics_ptr), y
	sta (bitmap_ptr), y
	iny
	jmp @loop
@end:
	rts
	
	
;******************************************************************************
;*  Game Initial Startup Code                                                 *
;******************************************************************************
	
	
; This section of code is run only once, when the game starts for the first
;	time. The splash/instructions screen is loaded with text, and the
;	bitmap screen in another bank is loaded with a black screen before
;	switching to another bank and putting the VIC in bitmap mode. Execution
;	flows directly from this initialization stage into the main game loop.
	
	
; Load intro screen text from definition in graphics section near the bottom
;	of this file. This text will persist in the default bank, ready to be
;	displayed again when the user requests to display the instructions
;	screen again.

show_intro_screen:
	ldx #0
	stx BACKGROUND_COLOR
	stx FRAME_COLOR
@loop:	
	lda intro_screen, x
	jsr PUTCHAR
	inx
	cpx #0
	beq next_255
	jmp @loop
next_255:
	ldx #0
@loop:
	lda intro_screen+256, x
	jsr PUTCHAR
	inx
	cpx #0
	beq last_few
	jmp @loop
last_few:
	ldx #0
@loop:
	cpx #(end_intro_screen-intro_screen-512) 
	beq @end
	lda intro_screen+512, x
	jsr PUTCHAR
	inx
	jmp @loop
@end:


; Await user input: Wait for the user to press any key, then continue with
;	initialization code.

await_input:
	jsr GETCHAR
	cmp #0
	beq await_input
	
	
; Initialize SID chip voice 3 -- the output of this voice will be used to
;	generate pseudorandom numbers for use in placing mines on the board.

init_SID_random:
	lda #$FF
	sta SID_FREQ_3_LOW
	sta SID_FREQ_3_HIGH
	lda #$80
	sta SID_CTRL_3
	

; Load the first 24 rows of the screen with black bitmap cells. Since only 24 of
;	25 rows are used for the board, the last strip will be set to the
;	background color in another routine.
	
clear_screen:
	lda #<BITMAP
	sta bitmap_ptr
	lda #>BITMAP
	sta bitmap_ptr+1
	lda #<COLOR
	sta color_ptr
	lda #>COLOR
	sta color_ptr+1
	lda #0
	sta scratch
	ldy #0
@bitmap_loop:
	lda #0
	sta (bitmap_ptr), y
	iny
	cpy #0
	bne @bitmap_loop
	inc scratch
	inc bitmap_ptr+1
	lda scratch
	cmp #$19
	beq @last_64
	jmp @bitmap_loop
@last_64:
	lda #0
	cpy #64
	beq @clear_color
	sta (bitmap_ptr), y
	iny
	jmp @last_64
@clear_color:
	sta scratch
	ldy #0
@color_loop:
	lda #0
	sta (color_ptr), y
	iny
	cpy #0
	bne @color_loop
	inc scratch
	inc color_ptr+1
	lda scratch
	cmp #$03
	beq @last_192_black
	jmp @color_loop
@last_192_black:
	cpy #192
	beq @end
	lda #0
	sta (color_ptr), y
	iny
	jmp @last_192_black
@end:

	lda #$0B
	sta FRAME_COLOR
	sta BACKGROUND_COLOR
	
	lda V_MODE_CTRL
	ora #$20
	sta V_MODE_CTRL
	
	lda VIC_BANK_SELECT
	and #$FC
	ora #$02
	sta VIC_BANK_SELECT
	
	lda #08
	sta V_MEMORY_LOCATION
	

; Load the two sprites, always displayed together in the same location, from
;	their definitions in the graphics section into screen memory, and
;	set the relevant registers to display these sprites.
	
init_sprites:
	ldx #0	
@loop:
	cpx #63
	beq @end
	lda sprite_inner, x
	sta $4400, x
	lda sprite_outer, x
	sta $5000, x
	inx
	jmp @loop
@end:
	lda #64
	sta $43F8
	lda #16
	sta $43F9
	
	lda #$22
	sta $D027
	lda #$11
	sta $D028
	

; ******************************************************************************
; * Outer Game Loop                                                            *
; ******************************************************************************


; This code is run every time a new game is started. Game variables are 
;	initialized, the last row is drawn in frame color, and the cursor
;	sprites are positioned to the starting cursor location. Code execution
;	flows directly from this initialization into the inner game loop.

; ------------------------------------------------


; Initialize variables
	
new_game:
	lda #5
	sta cursor_y
	lda #9
	sta cursor_x
	lda #0
	sta game_over
	lda #$0B
	sta FRAME_COLOR
	lda #$FF


; Draw 25th row in frame color
	
last_strip:
	lda #<COLOR
	clc
	adc #192
	sta color_ptr
	lda #>COLOR
	adc #3
	sta color_ptr+1
	lda #$BB
	ldy #0
@loop:
	cpy #(X_RANGE*2)
	beq @end
	sta (color_ptr), y
	iny
	jmp @loop
@end:


; Initialize the board with blank cells. As is explained with the cell array
;	definition at the bottom of this file, the byte $10 represents a
;	non-mine, unflagged, unrevealed, updated cell with no adjacent mines.

initialize_cells:
	ldx #0
@loop:
	cpx #TOTAL_CELLS
	beq @end
	lda #$10
	sta cells_array,x
	inx
	jmp @loop
@end:
	jsr draw_board


; Position the sprites according to starting position

pos_sprites:	
	lda #23
	sta INNER_SPRITE_X
	sta OUTER_SPRITE_X
	
	lda #49
	sta INNER_SPRITE_Y
	sta OUTER_SPRITE_Y
	
	lda #0
	sta SPRITES_X_MSB
	
y_pos_sprites:	
	ldx #0
@loop:
	cpx cursor_y
	beq @end
	lda OUTER_SPRITE_Y
	clc
	adc #16
	sta OUTER_SPRITE_Y
	lda INNER_SPRITE_Y
	clc
	adc #16
	sta INNER_SPRITE_Y
	inx
	jmp @loop
@end:
x_pos_sprites:
	ldx #0
@loop:
	cpx cursor_x
	beq @end
	lda OUTER_SPRITE_X
	clc
	adc #16
	sta OUTER_SPRITE_X
	lda INNER_SPRITE_X
	clc
	adc #16
	sta INNER_SPRITE_X
	bcc @move_on
	lda #$03
	sta SPRITES_X_MSB
@move_on:
	inx
	jmp @loop
@end:
	lda $D015
	ora #$03
	sta $D015


; A special value in scratch is used to signal that the board has not yet been
;	initialized. This will change to a special value of game_over in the
;	future.

set_not_started:
	lda #$FF
	sta scratch


; ******************************************************************************
; * Inner Game Loop                                                            *
; ******************************************************************************


; This code runs continuously until a new game is started when the player
;	presses the N key. Consists of this single get_input routine, which
;	jumps to other routines depending on the player's selection. Game logic
;	itself is defined in a later section.
	
get_input:
	jsr GETCHAR
	tax
	cmp #$4E
	bne @not_n
	lda scratch
	cmp #$FF
	beq get_input
	jmp new_game
@not_n:
	tax
	cmp #$49
	bne @not_i
	jsr show_intro_again
	jmp get_input
@not_i:
	lda game_over
	beq @not_game_over
	jmp get_input
@not_game_over:
	txa
	cmp #$57
	bne @not_w
	jsr cursor_up
	jmp get_input
@not_w:
	txa
	cmp #$41
	bne @not_a
	jsr cursor_left
	jmp get_input
@not_a:
	txa
	cmp #$53
	bne @not_s
	jsr cursor_down
	jmp get_input
@not_s:
	txa
	cmp #$44
	bne @not_d
	jsr cursor_right
	jmp get_input
@not_d:
	txa
	cmp #$45
	bne @not_e
	lda scratch
	cmp #$FF
	beq get_input
	jsr right_click_cell
	jsr draw_board
	jsr check_state
	jmp get_input
@not_e:
	txa
	cmp #$20
	bne get_input
	lda scratch
	cmp #$FF
	bne @after_first_click
	jsr randomize_board
	jsr count_adjacent
@after_first_click:
	jsr left_click_cell
	jsr draw_board
	jsr check_state
	jmp get_input
	

; ******************************************************************************
; * Game Routines                                                              *
; ******************************************************************************


; These routines manipulate the board according to the operation the player has
;	selected, and update graphics and game variables accordingly

; ------------------------------------------------


; Switches the VIC back to the default bank and default text mode to display the
;	screen data loaded at the beginning of the program, waits for user input,
;	then switches back to the main board view.
	
show_intro_again:
	lda $D015
	and #$FC
	sta $D015
	lda FRAME_COLOR
	pha
	lda #0
	sta BACKGROUND_COLOR
	sta FRAME_COLOR
	lda #$14
	sta V_MEMORY_LOCATION
	lda V_MODE_CTRL
	and #$DF
	sta V_MODE_CTRL
	lda VIC_BANK_SELECT
	and #$FC
	ora #$03
	sta VIC_BANK_SELECT
@await_input:
	jsr GETCHAR
	cmp #0
	beq @await_input
	pla
	sta FRAME_COLOR
	lda #$08
	sta V_MEMORY_LOCATION
	lda V_MODE_CTRL
	ora #$20
	sta V_MODE_CTRL
	lda VIC_BANK_SELECT
	and #$FC
	ora #$02
	sta VIC_BANK_SELECT
	lda $D015
	ora #$03
	sta $D015
	rts


; Check for a win or loss, and update the frame color (and 25th bitmap row)
;	accordingly: red for loss, green for win.

check_state:
	lda game_over
	beq not_loss
	lda #$22
	sta FRAME_COLOR
	lda #<COLOR
	clc
	adc #192
	sta color_ptr
	lda #>COLOR
	adc #3
	sta color_ptr+1
	lda #$22
	ldy #0
@loop:
	cpy #(X_RANGE*2)
	beq @end
	sta (color_ptr), y
	iny
	jmp @loop
@end:
	rts
not_loss:
	lda #0
	sta scratch
	sta scratch+1
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	ldy #0
@loop:
	cpy #(TOTAL_CELLS)
	beq @end
	lda (cells_ptr), y
	and #$20
	bne @flagged
	lda (cells_ptr), y
	and #$40
	beq @unrevealed
	iny
	jmp @loop
@flagged:
	inc scratch
	iny
	jmp @loop
@unrevealed:
	inc scratch+1
	iny
	jmp @loop
@end:
	lda scratch+1
	cmp #0
	bne @return
	lda scratch
	cmp #MINES
	bne @return
	lda #1
	sta game_over
	lda $D015
	and #$FC
	sta $D015
	lda #$55
	sta FRAME_COLOR
	lda #<COLOR
	clc
	adc #192
	sta color_ptr
	lda #>COLOR
	adc #3
	sta color_ptr+1
	lda #$55
	ldy #0
@loop2:
	cpy #(X_RANGE*2)
	beq @return
	sta (color_ptr), y
	iny
	jmp @loop2
@return:
	rts


; Infinite loop. Used for debugging purposes, to enter the monitor and check
;	registers and memory. Will eventually be removed.

inf:	
	nop
	jmp inf
	
	
; Sets the cells array pointer to the location indicated by the cursor. Used
;	when "left-clicking" or "right-clicking" a cell (spacebar and E key
;	respectively).	

set_cells_ptr_to_cursor:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	ldx cursor_y
@y_loop:
	cpx #0
	beq @end
	jsr cells_ptr_down
	dex
	jmp @y_loop
@end:
	ldx cursor_x
@x_loop:
	cpx #0
	beq @done
	jsr cells_ptr_right
	dex
	jmp @x_loop
@done:
	rts
	
	
; "Right-clicks" a cell, flagging any unflagged unrevealed cell and unflagging
;	any flagged unrevealed cell. Revealed cells are unaffected.

right_click_cell:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr),y
	and #$40
	beq @unrevealed
	rts
@unrevealed:
	lda (cells_ptr), y
	ora #$10
	sta (cells_ptr), y
	and #$20
	beq @not_flagged
	lda (cells_ptr), y
	and #$DF
	sta (cells_ptr), y
	rts
@not_flagged:
	lda (cells_ptr), y
	ora #$20
	sta (cells_ptr), y
	rts
	

; This next routine is really a few smaller routines, and depending on what
;	specific operation is invoking it, a few of these sub-steps can be
;	jumped to. When a left-click is invoked from the keyboard, there are two
;	valid cases: An unrevealed cell was clicked, or a revealed cell with the
;	appropriate number of adjacent flags was clicked. When an unrevealed
;	cell with zero adjacent mines is clicked, all adjacent cells must be
;	recursively revealed to reveal the largest possible contiguous area with
;	no adjacent mines. 

; The first label, left_click_cell, is jumped to when the player invokes a 
;	"left click" from the keyboard. It checks whether or not the cell is
;	revealed, and if it is, jumps to a later routine to check how many flags
;	are adjacent to it. This operation will be explained later with the
;	relevant routine. If the cell is not revealed, the following label,
;	click_cells_recursive, with its redundant revealed check, is bypassed.

; click_cells_recursive is only called from inside this routine, when an
;	unrevealed cell with no adjacent mines is found. Like left_click_cell,
;	this section checks if a cell is revealed, but since it's only called
;	recursively and clicks on appropriately-flagged revealed cells can only
;	come from the user, it simply returns when a revealed cell is found.

; click_cell_no_revealed_check is jumped to from the click_surrounding routine,
;	which will be explained later. A jump to this label bypasses the 
;	revealed check, as it will be called on a revealed cell that has been
;	confirmed to have the correct number of adjacent flags. If it has zero
;	adjacent mines, its surrounding cells will be clicked recursively 
;	according to the normal rules.

left_click_cell:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr), y
	and #$40
	beq click_cell_no_revealed_check
	jsr click_surrounding
click_cells_recursive:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr), y
	and #$40
	beq @unrevealed
	rts
@unrevealed:
click_cell_no_revealed_check:
	lda (cells_ptr), y
	and #$20
	beq @not_flagged
	rts
@not_flagged:
	lda (cells_ptr), y
	and #$80
	beq @not_mine
	ora #$01
	sta (cells_ptr), y
	jsr reveal_mines
	rts
@not_mine:
	lda (cells_ptr), y
	ora #$50
	sta (cells_ptr), y
	and #$0F
	beq chain_click
	rts
chain_click:
	lda #0
	sta line_of_three
	lda cursor_y
	cmp #0
	beq @first_row
	dec cursor_y
	jmp @check_row
@first_row:
	inc line_of_three
@check_row:
	lda line_of_three
	cmp #3
	bne @not_over
	dec cursor_y
	dec cursor_y
	rts
@not_over:
	cmp #2
	bne @still_not_over
	lda cursor_y
	cmp #Y_RANGE
	bne @still_not_over
	dec cursor_y
	rts
@still_not_over:
	lda cursor_x
	cmp #0
	beq @middle_col
	dec cursor_x
	lda line_of_three
	pha
	jsr click_cells_recursive
	pla
	sta line_of_three
	inc cursor_x
@middle_col:
	lda line_of_three
	pha
	jsr click_cells_recursive
	pla
	sta line_of_three
	lda cursor_x
	cmp #(X_RANGE-1)
	beq @after_last_col
	inc cursor_x
	lda line_of_three
	pha
	jsr click_cells_recursive
	pla
	sta line_of_three
	dec cursor_x
@after_last_col:
	inc cursor_y
	inc line_of_three
	jmp @check_row
	
	
; This routine is called when a mine is clicked and the game is lost. All mines
;	are set to revealed, and the game_over flag is set.
	
reveal_mines:
	lda $D015
	and #$FC
	sta $D015
	lda #1
	sta game_over
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	lda #0
	sta current_line
	sta current_col
@loop:
	ldy #0
	lda (cells_ptr),y
	and #$A0
	cmp #$00
	bne @process_this
	jmp @next_cell
@process_this:
	lda (cells_ptr), y
	ora #$50
	sta (cells_ptr), y
@next_cell:
	jsr cells_ptr_right
	inc current_col
	lda current_col
	cmp #X_RANGE
	bne @go_back
	lda #0
	sta current_col
	inc current_line
	lda current_line
	cmp #Y_RANGE
	bne @go_back
	rts
@go_back:
	jmp @loop
	

; This routine is invoked from left_click_cell if it is called on a revealed
;	cell. The routine first counts the number of adjacent flags, and if this
;	number equals the number of mines adjacent to the cell, the surrounding
;	cells are clicked. Reading through this now, I can tell that there is
;	redundant code -- this will be removed in a later update.
	
click_surrounding:
	lda #0
	sta scratch
	sta line_of_three
	lda cursor_y
	cmp #0
	bne @back_one
	inc line_of_three
	jmp @process_line
@back_one:
	jsr cells_ptr_up
@process_line:
	lda cursor_x
	cmp #0
	beq @after_first
	jsr cells_ptr_left
	jsr check_flag
	jsr cells_ptr_right
@after_first:
	jsr check_flag
	lda cursor_x
	cmp #(X_RANGE-1)
	bne @do_last_col
	jmp @to_next_ln
@do_last_col:
	jsr cells_ptr_right
	jsr check_flag
	jsr cells_ptr_left
@to_next_ln:
	lda line_of_three
	cmp #2
	bne @not_third
	jsr cells_ptr_up
	jmp @end
@not_third:
	cmp #0
	beq @move_on
	lda cursor_y
	cmp #(Y_RANGE-1)
	bne @move_on
	jmp @end
@move_on:
	jsr cells_ptr_down
	inc line_of_three
	jmp @process_line
@end:
	ldy #0
	lda (cells_ptr), y
	and #$0F
	cmp scratch
	beq actually_click_surrounding
@return:
	rts
actually_click_surrounding:
	lda #0
	sta line_of_three
	lda cursor_y
	cmp #0
	beq @first_row
	dec cursor_y
	jmp @check_row
@first_row:
	inc line_of_three
@check_row:
	lda line_of_three
	cmp #3
	bne @not_over
	dec cursor_y
	dec cursor_y
	rts
@not_over:
	cmp #2
	bne @still_not_over
	lda cursor_y
	cmp #Y_RANGE
	bne @still_not_over
	dec cursor_y
	rts
@still_not_over:
	lda cursor_x
	cmp #0
	beq @middle_col
	dec cursor_x
	lda line_of_three
	pha
	jsr click_cells_recursive
	pla
	sta line_of_three
	inc cursor_x
@middle_col:
	lda line_of_three
	pha
	jsr click_cells_recursive
	pla
	sta line_of_three
	lda cursor_x
	cmp #(X_RANGE-1)
	beq @after_last_col
	inc cursor_x
	lda line_of_three
	pha
	jsr click_cells_recursive
	pla
	sta line_of_three
	dec cursor_x
@after_last_col:
	inc cursor_y
	inc line_of_three
	jmp @check_row
@end:
	ldy #0
	lda (cells_ptr), y
	and #$0F
	cmp scratch
	bne @return
	jsr click_cell_no_revealed_check
@return:
	rts
	
	
; Simply checks a cell for a flag and increments the scratch variable if it is
;	found.

check_flag:
	ldy #0
	lda (cells_ptr), y
	and #$20
	bne @flagged
	rts
@flagged:
	inc scratch
	rts


; Places the appropriate number of mines on the board in random locations. Used
;	to initialize the board after the first left click. The 3x3 area 
;	surrounding the first click is avoided, as are already-existing mines.

randomize_board:
	lda #0
	sta mines_placed
get_randoms:
get_rand_x:
	lda RANDOM
	cmp #((256/X_RANGE)*X_RANGE)
	bcs get_rand_x
@loop:
	cmp #X_RANGE
	bcc @end
	sec
	sbc #X_RANGE
	jmp @loop
@end:
	tax
get_rand_y:
	lda RANDOM
	cmp #((256/Y_RANGE)*Y_RANGE)
	bcs get_rand_y
@loop:
	cmp #Y_RANGE
	bcc @end
	sec
	sbc #Y_RANGE
	jmp @loop
@end:
	tay
check_cursor:
check_x:
	inx
	cpx cursor_x
	dex
	bcc go_on
	inc cursor_x
	inc cursor_x
	cpx cursor_x
	dec cursor_x
	dec cursor_x
	bcs go_on
check_y:
	iny
	cpy cursor_y
	dey
	bcc go_on
	inc cursor_y
	inc cursor_y
	cpy cursor_y
	dec cursor_y
	dec cursor_y
	bcs go_on
	jmp get_randoms
go_on:
convert_addr:
convert_y:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
@loop:
	cpy #0
	beq @end
	lda cells_ptr
	clc
	adc #X_RANGE
	sta cells_ptr
	lda cells_ptr+1
	adc #0
	sta cells_ptr+1
	dey
	jmp @loop
@end:
convert_x:
	stx scratch
	lda cells_ptr
	clc
	adc scratch
	sta cells_ptr
	lda cells_ptr+1
	adc #0
	sta cells_ptr+1
check_mine:
	ldy #0
	lda (cells_ptr),y
	and #$80
	cmp #0
	bne @go_back
	lda (cells_ptr),y
	ora #$80
	sta (cells_ptr),y
	inc mines_placed
	lda mines_placed
	cmp #MINES
	bne @go_back
	rts
@go_back:
	jmp get_randoms
	
	
; Increments the mine count of all cells surrounding each mine.
	
inc_mine_count:
	lda (cells_ptr),y
	tax
	inx
	txa
	sta (cells_ptr),y
	rts
	
count_adjacent:
	lda #0
	sta line_of_three
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	lda #0
	sta current_line
	sta current_col
@loop:
	ldy #0
	lda (cells_ptr),y
	and #$80
	cmp #$00
	bne @process_this
	jmp @next_cell
@process_this:
	lda #0
	sta line_of_three
	lda current_line
	cmp #0
	bne @back_one
	inc line_of_three
	jmp @process_line
@back_one:
	jsr cells_ptr_up
@process_line:
	lda current_col
	cmp #0
	beq @after_first
	jsr cells_ptr_left
	jsr inc_mine_count
	jsr cells_ptr_right
@after_first:
	jsr inc_mine_count
	lda current_col
	cmp #(X_RANGE-1)
	bne @do_last_col
	jmp @to_next_ln
@do_last_col:
	jsr cells_ptr_right
	jsr inc_mine_count
	jsr cells_ptr_left
@to_next_ln:
	lda line_of_three
	cmp #2
	bne @not_third
	jsr cells_ptr_up
	jmp @next_cell
@not_third:
	cmp #0
	beq @move_on
	lda current_line
	cmp #(Y_RANGE-1)
	bne @move_on
	jmp @next_cell
@move_on:
	jsr cells_ptr_down
	inc line_of_three
	jmp @process_line
@next_cell:
	jsr cells_ptr_right
	inc current_col
	lda current_col
	cmp #X_RANGE
	bne @go_back
	lda #0
	sta current_col
	inc current_line
	lda current_line
	cmp #Y_RANGE
	bne @go_back
	jmp zero_mine_adjacencies
@go_back:
	jmp @loop
	
	
; Zeroes out the adjacent mines count for all mine-cells. This count is only
;	relevant for non-mine cells, and one of the bits in the cell state byte
;	is used to flag the mine that was clicked when the game is lost.

zero_mine_adjacencies:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	lda #0
	sta current_line
	sta current_col
@loop:
	ldy #0
	lda (cells_ptr),y
	and #$80
	cmp #$00
	bne @process_this
	jmp @next_cell
@process_this:
	lda (cells_ptr), y
	and #$F0
	sta (cells_ptr), y
@next_cell:
	jsr cells_ptr_right
	inc current_col
	lda current_col
	cmp #X_RANGE
	bne @go_back
	lda #0
	sta current_col
	inc current_line
	lda current_line
	cmp #Y_RANGE
	bne @go_back
	rts
@go_back:
	jmp @loop
	

; This routine draws the board in bitmap memory, only updating cells with the
;	update bit set for the sake of efficiency. A more detailed explanation
;	will be provided later.
	
draw_board:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	lda #<COLOR
	sta color_ptr
	lda #>COLOR
	sta color_ptr+1
	lda #<BITMAP
	sta bitmap_ptr
	lda #>BITMAP
	sta bitmap_ptr+1
	lda #0
	sta current_line
	sta current_col
@loop:
	ldy #0
	lda (cells_ptr), y
	and #$10
	beq @advance
	jsr draw_cell
@advance:
	jsr cells_ptr_right
	jsr color_ptr_right
	jsr color_ptr_right
	jsr bitmap_ptr_right
	jsr bitmap_ptr_right
	inc current_col
	lda current_col
	cmp #X_RANGE
	bne @loop
	lda #0
	sta current_col
	inc current_line
	lda current_line
	cmp #Y_RANGE
	beq @end
	jsr bitmap_ptr_down
	jsr color_ptr_down
	jmp @loop
@end:
	rts
	

; Draws one individual cell.
	
draw_cell:
	ldy #0
	lda (cells_ptr), y
	and #$EF
	sta (cells_ptr), y
	jsr identify_cell
	jsr draw_one_cell
	jsr bitmap_ptr_right
	jsr color_ptr_right
	jsr graphics_ptr_right
	jsr draw_one_cell
	jsr bitmap_ptr_down
	jsr color_ptr_down
	jsr graphics_ptr_down
	jsr draw_one_cell
	jsr bitmap_ptr_left
	jsr color_ptr_left
	jsr graphics_ptr_left
	jsr draw_one_cell
	jsr bitmap_ptr_up
	jsr color_ptr_up
	jsr graphics_ptr_up
	rts
	
	
; Sets the graphics pointer and color variable depending on what type of cell
;	needs to be displayed.
	
identify_cell:
	and #$20
	bne @flagged
	lda (cells_ptr), y
	and #$40
	bne @revealed
	lda #<unrevealed
	sta graphics_ptr
	lda #>unrevealed
	sta graphics_ptr+1
	lda #$0F
	sta current_color
	rts
@flagged:
	lda #<flag
	sta graphics_ptr
	lda #>flag
	sta graphics_ptr+1
	lda (cells_ptr), y
	and #$C0
	cmp #$40
	beq @false_flag
	lda #$0F
	jmp @after_color
@false_flag:
	lda #$02
@after_color:
	sta current_color
	rts
@revealed:
	lda (cells_ptr), y
	and #$80
	beq @not_mine
	lda #<mine
	sta graphics_ptr
	lda #>mine
	sta graphics_ptr+1
	lda (cells_ptr), y
	and #$0F
	bne @exploded
	lda #$0C
	jmp @after
@exploded:
	lda #$02
@after:
	sta current_color
	rts
@not_mine:
	lda (cells_ptr), y
	and #$0F
	cmp #0
	bne @not_zero
	lda #<revealed_0
	sta graphics_ptr
	lda #>revealed_0
	sta graphics_ptr+1
	lda #$0C
	sta current_color
	rts
@not_zero:
	cmp #1
	bne @not_one
	lda #<revealed_1
	sta graphics_ptr
	lda #>revealed_1
	sta graphics_ptr+1
	lda #$0E
	sta current_color
	rts
@not_one:
	cmp #2
	bne @not_two
	lda #<revealed_2
	sta graphics_ptr
	lda #>revealed_2
	sta graphics_ptr+1
	lda #$05
	sta current_color
	rts
@not_two:
	cmp #3
	bne @not_three
	lda #<revealed_3
	sta graphics_ptr
	lda #>revealed_3
	sta graphics_ptr+1
	lda #$0A
	sta current_color
	rts
@not_three:
	cmp #4
	bne @not_four
	lda #<revealed_4
	sta graphics_ptr
	lda #>revealed_4
	sta graphics_ptr+1
	lda #$06
	sta current_color
	rts
@not_four:
	cmp #5
	bne @not_five
	lda #<revealed_5
	sta graphics_ptr
	lda #>revealed_5
	sta graphics_ptr+1
	lda #$02
	sta current_color
	rts
@not_five:
	cmp #6
	bne @not_six
	lda #<revealed_6
	sta graphics_ptr
	lda #>revealed_6
	sta graphics_ptr+1
	lda #$03
	sta current_color
	rts
@not_six:
	cmp #7
	bne @not_seven
	lda #<revealed_7
	sta graphics_ptr
	lda #>revealed_7
	sta graphics_ptr+1
	lda #$08
	sta current_color
	rts
@not_seven:
	lda #<revealed_8
	sta graphics_ptr
	lda #>revealed_8
	sta graphics_ptr+1
	lda #$09
	sta current_color
	rts
	
	
; ******************************************************************************
; * Graphics                                                                   *
; ******************************************************************************

	
; Data used for graphics -- Intro/instructions screen text, sprite data, and the
;	four bitmap cells that make up each cell graphic.

; ------------------------------------------------
	
intro_screen:
.byte $93, $05, $0D
.byte "              minesweeper", $0D, $0D
.byte "        written in 6502 assembly", $0D, $0D
.byte "           programmed for the", $0D
.byte "        commodore 64 in 2022 by", $0D
.byte "             kai sandstrom", $0D, $0D
.byte "       controls:", $0D, $0D
.byte "       wasd:   move cursor", $0D
.byte "       space:  clear mine", $0D
.byte "       e:      flag/unflag mine", $0D
.byte "       n:      start new game", $0D
.byte "       i:      show instructions", $0D, $0D
.byte " revealed cells with the correct number", $0D
.byte " of flags surrounding can be clicked to", $0D
.byte "  reveal remaining cells. if the flags", $0D
.byte " are incorrect, a mine will be clicked,", $0D
.byte "       and the game will be lost.", $0D, $0D
.byte "       press any key to continue."
end_intro_screen:

sprite_outer:
.byte %11111111, %11111111, %11100000
.byte %10000000, %00000000, %00100000
.byte %10111111, %11111111, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10100000, %00000000, %10100000
.byte %10111111, %11111111, %10100000
.byte %10000000, %00000000, %00100000
.byte %11111111, %11111111, %11100000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000

sprite_inner:
.byte %00000000, %00000000, %00000000
.byte %01111111, %11111111, %11000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01000000, %00000000, %01000000
.byte %01111111, %11111111, %11000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
.byte %00000000, %00000000, %00000000
	
revealed_0:
unrevealed:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11111111
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000

.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_1:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000001
.byte %10000011
.byte %10000111
.byte %10000001

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11000000
.byte %11000000
.byte %11000000
.byte %11000000
.byte %11000000

.byte %10000001
.byte %10000001
.byte %10000001
.byte %10000111
.byte %10000111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11000000
.byte %11000000
.byte %11000000
.byte %11110000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_2:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10001111
.byte %10011111
.byte %10011100
.byte %10000000
.byte %10000000

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11110000
.byte %11111000
.byte %00111000
.byte %00111000
.byte %11110000

.byte %10000011
.byte %10001111
.byte %10011110
.byte %10011111
.byte %10011111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11100000
.byte %10000000
.byte %00000000
.byte %11111000
.byte %11111000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_3:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10011111
.byte %10011111
.byte %10000000
.byte %10000000
.byte %10000011

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11110000
.byte %11111000
.byte %00111000
.byte %00111000
.byte %11110000

.byte %10000011
.byte %10000000
.byte %10000000
.byte %10011111
.byte %10011111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11110000
.byte %00111000
.byte %00111000
.byte %11111000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_4:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10000111
.byte %10000111
.byte %10001110
.byte %10001110
.byte %10011111

.byte %11111111
.byte %00000000
.byte %00000000
.byte %01110000
.byte %01110000
.byte %01110000
.byte %01110000
.byte %11111000

.byte %10011111
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11111000
.byte %01110000
.byte %01110000
.byte %01110000
.byte %01110000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_5:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10011111
.byte %10011111
.byte %10011100
.byte %10011100
.byte %10011111

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11111000
.byte %11111000
.byte %00000000
.byte %00000000
.byte %11110000

.byte %10011111
.byte %10000000
.byte %10000000
.byte %10011111
.byte %10011111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11111000
.byte %00111000
.byte %00111000
.byte %11111000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_6:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10001111
.byte %10011111
.byte %10011100
.byte %10011100
.byte %10011111

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11110000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %11110000

.byte %10011111
.byte %10011100
.byte %10011100
.byte %10011111
.byte %10001111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11111000
.byte %00111000
.byte %00111000
.byte %11111000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_7:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10011111
.byte %10011111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11111000
.byte %11111000
.byte %00111000
.byte %00111000
.byte %01110000

.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000001
.byte %10000001
.byte %10000000
.byte %10000000
.byte %10000000

.byte %01110000
.byte %11100000
.byte %11100000
.byte %11000000
.byte %11000000
.byte %00000000
.byte %00000000
.byte %00000000

revealed_8:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10001111
.byte %10011111
.byte %10011100
.byte %10011100
.byte %10001111

.byte %11111111
.byte %00000000
.byte %00000000
.byte %11110000
.byte %11111000
.byte %00111000
.byte %00111000
.byte %11110000

.byte %10001111
.byte %10011100
.byte %10011100
.byte %10011111
.byte %10001111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11110000
.byte %00111000
.byte %00111000
.byte %11111000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000

mine:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10001011
.byte %10000111
.byte %10001100
.byte %10001100

.byte %11111111
.byte %00000000
.byte %10000000
.byte %10000000
.byte %11101000
.byte %11110000
.byte %11111000
.byte %11111000

.byte %10111111
.byte %10001111
.byte %10001111
.byte %10000111
.byte %10001011
.byte %10000000
.byte %10000000
.byte %10000000

.byte %11111110
.byte %11111000
.byte %11111000
.byte %11110000
.byte %11101000
.byte %10000000
.byte %10000000
.byte %00000000

flag:
.byte %11111111
.byte %10000000
.byte %10000000
.byte %10000001
.byte %10000111
.byte %10001111
.byte %10000111
.byte %10000001

.byte %11111111
.byte %00000000
.byte %00000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000
.byte %10000000

.byte %10000000
.byte %10000000
.byte %10000011
.byte %10001111
.byte %10001111
.byte %10000000
.byte %10000000
.byte %10000000

.byte %10000000
.byte %10000000
.byte %11000000
.byte %11110000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000


; ******************************************************************************
; * Cells Array                                                                *
; ******************************************************************************


; This simple label defines the start of the cell state bytes array, as I
;	couldn't figure out how to reserve a specific number of bytes in memory
;	using the cc65 assembler macros without providing values for each 
;	individual byte.

; The functions of the bits in a state byte are as follows:
;	Bit 7: Set if the cell is a mine.
;	Bit 6: Set if the cell is flagged.
;	Bit 5: Set if the cell is revealed.
;	Bit 4: Set if the cell has been updated since it was last drawn.
;	Bits 3-0: Store the integer number of mines adjacent to this cell (0-8).
;	Bit 0: If the cell is a mine, bit 0 is set if this specific cell was the
;		one clicked on by the player to lose the game.

cells_array:


