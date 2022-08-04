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


; C64 graphics addresses and built-in routines. Some are only used during 
; 	initial startup, but are defined here for the sake of readability.


; Keyboard I/O
GETCHAR = $FFE4
PUTCHAR = $FFD2


; SID chip addresses used for pseudorandom number generation
SID_CTRL_3      = $D412
SID_FREQ_3_LOW  = $D40E
SID_FREQ_3_HIGH = $D40F
RANDOM          = $D41B


; Video mode and video memory constants
FRAME_COLOR         = $D020
BACKGROUND_COLOR    = $D021
V_MODE_CTRL         = $D011
VIC_BANK_SELECT     = $DD00
V_MEMORY_LOCATION   = $D018
COLOR               = $4000
BITMAP              = $6000
MODE_CLEAR_MASK     = $FC
MODE_BITMAP_MASK    = $02
MODE_TEXT_MASK      = $03
BITMAP_MEM_LOCATION = $08
TEXT_MEM_LOCATION   = $14
V_MODE_BITMAP_MASK  = $20
V_MODE_TEXT_MASK    = $DF


; Color value constants
; For bitmap graphics, these values will be ANDed with $0F to set the color of
;	graphics cells' 1 bits to black, and the 0 bits to the relevant color.
BLACK      = $00
WHITE      = $11
LIGHT_GRAY = $FF
MID_GRAY   = $CC
DARK_GRAY  = $BB
LIGHT_RED  = $AA
DARK_RED   = $22
LIGHT_BLUE = $EE
DARK_BLUE  = $66
CYAN       = $33
GREEN      = $55
BROWN      = $99
ORANGE     = $88

; Sprite addresses and constants
INNER_SPRITE_X        = $D000
INNER_SPRITE_Y        = $D001
OUTER_SPRITE_X        = $D002
OUTER_SPRITE_Y        = $D003
SPRITES_X_MSB         = $D010
INNER_SPRITE_LOCATION = $4400
OUTER_SPRITE_LOCATION = $5000
INNER_SPRITE_OFFSET   = 16
OUTER_SPRITE_OFFSET   = 64
INNER_SPRITE_POINTER  = $43F9
OUTER_SPRITE_POINTER  = $43F8
INNER_SPRITE_COLOR    = $D027
OUTER_SPRITE_COLOR    = $D028
SHOW_SPRITES_REG      = $D015
SHOW_SPRITES_MASK     = $03
HIDE_SPRITES_MASK     = $FC

; Game constants
X_RANGE     = 20
Y_RANGE     = 12
TOTAL_CELLS = (X_RANGE*Y_RANGE)
MINES       = 40


;*******************************************************************************
;*  Zero-Page Variables and Pointers                                           *
;*******************************************************************************


; Game Over flag. 0 when game is over, 1 when game is ongoing, 2 when game has
;	not yet been started (board mines are not yet initialized).
game_over = $02


; $03 and $04 are scratch variables, used for several purposes.
scratch            = $03
mines_placed       = scratch
line_of_three      = scratch+1
current_color      = scratch
num_flags_adjacent = scratch
num_unrevealed     = scratch+1


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
current_col  = $9C


; Pointers into various memory locations used in the representation of cells.
cells_ptr       = $FB
color_ptr       = $FD
bitmap_ptr      = $F7
graphics_ptr    = $F9
stack_queue_ptr = $BB


; Stores an address to be jumped to for a specific operation, used in the
;	abstract looping routines.
subroutine_ptr = $C1


; ******************************************************************************
; * Cells Array                                                                *
; ******************************************************************************


; The cell bytes array is located near the end of program memory, after the
;	graphics. It is 240 bytes long, the same as the number of cells in the
;	20x12 board. It is explained here instead of at the end of the file for
;	the sake of readability.

; The functions of the bits in a state byte are as follows:
;	Bit 7: Set if the cell is a mine.
;	Bit 6: Set if the cell is flagged.
;	Bit 5: Set if the cell is revealed.
;	Bit 4: Set if the cell has been updated since it was last drawn.

;	If the cell is not a mine (bit 7 is clear):
;	Bits 3-0: Store the integer number of mines adjacent to this cell (0-8).

;	If the cell is a mine (bit 7 is set):
;	Bits 3-1: Unused.
;	Bit 0: Set if this specific cell was the one clicked by the player to
;		lose the game.


cells_array = after_graphics
	
	
; ******************************************************************************
; * Chain Click Stack-Queue                                                    *
; ******************************************************************************


; This structure is used when chain-clicking cells with zero adjacent mines. As
;	will be explained with the left-click routine, the original recursive
;	approach to clicking all adjacent cells had the possibility of
;	overflowing the 6502 stack under certain circumstances. The stack-queue
;	is placed in memory after the graphics and cells array, with no other
;	program code or data following it, allowing it to grow as much as
;	necessary. The theoretical maximum size in the astronomically unlikely
;	worst-case scenario is 372 bytes, found through experimentation.

; This structure is implemented as a LIFO stack. It is described as a 
;	"stack-queue" because its function is to store the address and
;	coordinates of cells that are waiting to be expanded. The only reason it
;	was implemented as a stack instead of a queue was convenience -- a stack
;	implementation only requires one pointer and can grow to whatever
;	arbitrary size is necessary without creeping through memory.

stack_queue = (after_graphics+TOTAL_CELLS)

	
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


; Stack-queue routines: Add or fetch the cells pointer, current line, and
;	current column values from the stack-queue and update the stack-queue
;	pointer accordingly

stack_queue_put:
	ldy #0
	lda cells_ptr
	sta (stack_queue_ptr), y
	iny
	lda cells_ptr+1
	sta (stack_queue_ptr), y
	iny
	lda current_line
	sta (stack_queue_ptr), y
	iny
	lda current_col
	sta (stack_queue_ptr), y
	lda stack_queue_ptr
	clc
	adc #4
	sta stack_queue_ptr
	lda stack_queue_ptr+1
	adc #0
	sta stack_queue_ptr+1
	rts
	
stack_queue_get:
	lda stack_queue_ptr
	sec
	sbc #4
	sta stack_queue_ptr
	lda stack_queue_ptr+1
	sbc #0
	sta stack_queue_ptr+1
	ldy #0
	lda (stack_queue_ptr), y
	sta cells_ptr
	iny
	lda (stack_queue_ptr), y
	sta cells_ptr+1
	iny
	lda (stack_queue_ptr), y
	sta current_line
	iny
	lda (stack_queue_ptr), y
	sta current_col
	rts
	
; ------------------------------------------------


; ********** Abstract Looping Routines ***********


; With the cells array pointer and x/y position variables set prior to the call,
;	this subroutine performs an abstract task on each of the cells adjacent
;	to the original. The address of the abstract task's subroutine is loaded
;	into the subroutine pointer before this routine is called.

for_all_surrounding:
	lda #0
	sta line_of_three
@check_top_row:
	lda current_line
	bne @do_first_row
	inc line_of_three
	jmp @process_row
@do_first_row:
	jsr cells_ptr_up
	dec current_line
@process_row:
@left_col:
	lda current_col
	beq @middle_col
	jsr cells_ptr_left
	dec current_col
	jsr do_task
	inc current_col
	jsr cells_ptr_right
@middle_col:
	lda line_of_three
	cmp #1
	beq @right_col
	jsr do_task
@right_col:
	lda current_col
	cmp #(X_RANGE-1)
	beq @next_line
	jsr cells_ptr_right
	inc current_col
	jsr do_task
	dec current_col
	jsr cells_ptr_left
@next_line:
	lda line_of_three
	cmp #2
	bne @not_last_row
	jsr cells_ptr_up
	dec current_line
	rts
@not_last_row:
	lda line_of_three
	cmp #1
	bne @to_next
	lda current_line
	cmp #(Y_RANGE-1)
	beq @end
@to_next:
	inc line_of_three
	inc current_line
	jsr cells_ptr_down
	jmp @process_row
@end:
	rts
	
	
; Simply jumps to the subroutine stored in the subroutine pointer. The rts
;	instruction at the end of the stored subroutine will return execution to
;	the point in for_all_adjacent from which do_task was called.

do_task:
	jmp (subroutine_ptr)
	

; *********** Other Common Subroutines ***********
	

; These routines show and hide the two sprites that make up the cursor,
;	respectively.

show_sprites:
	lda SHOW_SPRITES_REG
	ora #SHOW_SPRITES_MASK
	sta SHOW_SPRITES_REG
	rts

hide_sprites:
	lda SHOW_SPRITES_REG
	and #HIDE_SPRITES_MASK
	sta SHOW_SPRITES_REG
	rts
	
	
; Since the game board only uses 24 out of 25 rows, the final row of the screen
;	must be filled in with the frame color. This routine performs this 
;	action using the color stored in the current_color variable.
	
draw_last_strip:
	lda #<COLOR
	clc
	adc #192
	sta color_ptr
	lda #>COLOR
	adc #3
	sta color_ptr+1
	lda current_color
	ldy #0
@loop:
	cpy #(X_RANGE*2)
	beq @end
	sta (color_ptr), y
	iny
	jmp @loop
@end:
	rts


; Sets the VIC to bitmap mode, pointing to the appropriate memory locations to
;	display the board. Used on initial startup, and when exiting the
;	instructions screen.

switch_screen_bitmap:	
	lda VIC_BANK_SELECT
	and #MODE_CLEAR_MASK
	ora #MODE_BITMAP_MASK
	sta VIC_BANK_SELECT
	
	lda #BITMAP_MEM_LOCATION
	sta V_MEMORY_LOCATION
	
	lda V_MODE_CTRL
	ora #V_MODE_BITMAP_MASK
	sta V_MODE_CTRL
	
	lda #DARK_GRAY
	sta FRAME_COLOR
	
	rts
	
	
; Sets the VIC to text mode, pointing to the appropriate memory locations to
;	display the info screen. Used when displaying the info screen during
;	a game.
	
switch_screen_text:
	lda VIC_BANK_SELECT
	and #MODE_CLEAR_MASK
	ora #MODE_TEXT_MASK
	sta VIC_BANK_SELECT
	
	lda #TEXT_MEM_LOCATION
	sta V_MEMORY_LOCATION
	
	lda V_MODE_CTRL
	and #V_MODE_TEXT_MASK
	sta V_MODE_CTRL
	
	lda #BLACK
	sta FRAME_COLOR
	
	rts

	
;******************************************************************************
;*  Game Initial Startup Code                                                 *
;******************************************************************************
	
	
; This section of code is run only once, when the game starts for the first
;	time. The splash/instructions screen is loaded with text, the sprites
;	and SID pseudorandom number generator are initialized, and the screen is
;	loaded with empty board cells.
	
	
; Load intro screen text from definition in graphics section near the bottom
;	of this file. This text will persist in the default bank, ready to be
;	displayed again when the user requests to display the instructions
;	screen again.

show_intro_screen:
	ldx #BLACK
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
	beq await_input
	
	
; Initialize SID chip voice 3 -- the output of this voice will be used to
;	generate pseudorandom numbers for use in placing mines on the board.

init_SID_random:
	lda #$FF
	sta SID_FREQ_3_LOW
	sta SID_FREQ_3_HIGH
	lda #$80
	sta SID_CTRL_3
	

; Load the two sprites, always displayed together in the same location, from
;	their definitions in the graphics section into screen memory, and
;	set the relevant registers to display these sprites.
	
init_sprites:
	ldx #0	
@loop:
	cpx #63
	beq @end
	lda sprite_inner, x
	sta INNER_SPRITE_LOCATION, x
	lda sprite_outer, x
	sta OUTER_SPRITE_LOCATION, x
	inx
	jmp @loop
@end:
	lda #INNER_SPRITE_OFFSET
	sta INNER_SPRITE_POINTER
	lda #OUTER_SPRITE_OFFSET
	sta OUTER_SPRITE_POINTER
	
	lda #DARK_RED
	sta INNER_SPRITE_COLOR
	lda #WHITE
	sta OUTER_SPRITE_COLOR
	
	
; Copy the initial board into screen memory. This will be redundantly executed
;	below in the outer game loop, but it needs to be done on initial startup
;	in order to avoid seeing the initial screen garbage get overwritten with
;	board data.
	
	jsr draw_board
	
	
; Draw the last strip in border color. Like the above, this is redundant, but
;	is important for displaying the screen correctly the instant the text
;	screen is switched to bitmap.
	
	lda #DARK_GRAY
	sta current_color
	jsr draw_last_strip	

	

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
	lda #2
	sta game_over
	lda #<stack_queue
	sta stack_queue_ptr
	lda #>stack_queue
	sta stack_queue_ptr+1


; Initialize the board with blank cells. As is explained in the cell array
;	definition, the byte $10 represents a non-mine, unflagged, unrevealed,
;	updated cell with no adjacent mines.

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



; Draw 25th row in frame color

	lda #DARK_GRAY
	sta current_color
	jsr draw_last_strip


; Position the sprites according to starting position and set them active.

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
	jsr show_sprites

	
; Put the VIC chip into bitmap mode, pointing to the appropriate memory banks.
;	This is redundant all times this code is executed except the first, but
;	is used to ensure the screen is not shown until it is fully set up.

	jsr switch_screen_bitmap


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
@check_n:
	cmp #$4E
	bne @check_i
	lda game_over
	cmp #2
	beq get_input
	jmp new_game
@check_i:
	tax
	cmp #$49
	bne @check_game_over
	jsr show_intro_again
	jmp get_input
@check_game_over:
	lda game_over
	bne @check_w
	jmp get_input
@check_w:
	txa
	cmp #$57
	bne @check_a
	jsr cursor_up
	jmp get_input
@check_a:
	txa
	cmp #$41
	bne @check_s
	jsr cursor_left
	jmp get_input
@check_s:
	txa
	cmp #$53
	bne @check_d
	jsr cursor_down
	jmp get_input
@check_d:
	txa
	cmp #$44
	bne @check_e
	jsr cursor_right
	jmp get_input
@check_e:
	txa
	cmp #$45
	bne @check_space
	lda game_over
	cmp #2
	beq get_input
	jsr right_click_cell
	jsr draw_board
	jsr check_state
	jmp get_input
@check_space:
	txa
	cmp #$20
	bne get_input
	lda game_over
	cmp #2
	bne @after_first_click
	lda #1
	sta game_over
	jsr initialize_mines
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
;	screen data loaded at the beginning of the program, waits for user 
;	input, then switches back to the main board view.
	
show_intro_again:
	jsr hide_sprites
	jsr switch_screen_text
@await_input:
	jsr GETCHAR
	beq @await_input
	jsr switch_screen_bitmap
	lda game_over
	beq @return
	jsr show_sprites
@return:
	rts


; Checks for a win or loss, and updates the frame color (and 25th bitmap row)
;	accordingly: red for loss, green for win.
; When checking for a win, one of the zeropage scratch variables is used to
;	count flagged cells, and the other is used to count unrevealed cells. If
;	the number of flags equals the MINES constant and the number of
;	unrevealed cells is zero, the game is won.

check_state:
	lda game_over
	bne not_loss
	lda #DARK_RED
	sta FRAME_COLOR
	sta current_color
	jsr draw_last_strip
	rts
not_loss:
	lda #0
	sta num_flags_adjacent
	sta num_unrevealed
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
	inc num_flags_adjacent
	iny
	jmp @loop
@unrevealed:
	inc num_unrevealed
	iny
	jmp @loop
@end:
	lda num_unrevealed
	bne @return
	lda num_flags_adjacent
	cmp #MINES
	bne @return
	lda #0
	sta game_over
	jsr hide_sprites
	lda #GREEN
	sta FRAME_COLOR
	sta current_color
	jsr draw_last_strip
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
	stx current_line
@y_loop:
	cpx #0
	beq @end
	jsr cells_ptr_down
	dex
	jmp @y_loop
@end:
	ldx cursor_x
	stx current_col
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
@flagged:
	lda (cells_ptr), y
	and #$DF
	sta (cells_ptr), y
	rts
@not_flagged:
	lda (cells_ptr), y
	ora #$20
	sta (cells_ptr), y
	rts
	

; The left-click routine is complicated by the fact that when an unflagged,
;	unrevealed cell with no adjacent mines is clicked, all surrounding
;	unflagged cells must be programmatically clicked, which can in turn
;	trigger additional chain clicks on their adjacent cells. The original
;	implementation of the chain-click algorithm used recursive subroutine
;	calls, and required pushing an index variable on to the stack as well,
;	using three bytes of stack memory for each recursive call. In the
;	unlikely event that any given click revealed about one third of the
;	board, this would result in a stack overflow. No stack overflows
;	occurred when testing this approach, but the issue was made clear after
;	abstracting the task of looping through all adjacent cells to a
;	subroutine with indirect jumps to the relevant task -- the additional
;	subroutine call made stack overflows occur with significant frequency.

; The solution is to use a separate structure from the 6502 stack with enough
;	memory to store all necessary information in the (astronomically 
;	unlikely) worst-case scenario. In this code, the structure is called a
;	"stack-queue," as information is fetched LIFO, but the structure is
;	used much like a typical queue -- eligible cell's eligible neighbors
;	are all added before the next cell's information is fetched. For
;	example, the first cell's top-left neighbor will be the first cell
;	added to the stack-queue, but of the first cell's neighbors, it will be
;	the last to be processed.

; Due to this complication, the entire left-click routine revolves around the
;	use of this stack-queue. First, the routine checks if a cell is already
;	revealed or is a mine, which are handled by separate code incompatible
;	with the stack-queue loop. Otherwise, reveal_put_valid_cell is called,
;	which performs additional checks, and depending on the results, may
;	set the cell to revealed and/or add it to the stack-queue. Next, the
;	routine checks if the stack-queue is empty. Following the call to
;	the previous subroutine, this will be the case if any cell that is not
;	unflagged and unrevealed with no adjacent mines was clicked by the
;	user. If the stack-queue is empty, the routine simply returns, as the
;	call to reveal_put_valid_cell already cet the cell to revealed if
;	applicable. If the stack-queue is not empty, a chain-click must occur.
;	The most-recently-added element in the stack-queue is fetched, and 
;	the abstract for_all_adjacent subroutine is called with 
;	reveal_put_valid_cell loaded into the subroutine pointer. After this is
;	complete, execution jumps back to the start of the chain-click loop, and
;	this loop continues executing until the stack-queue is empty.

left_click_cell:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr), y
	and #$40
	bne click_surrounding
@chain_click_init:
	lda #<reveal_put_valid_cell
	sta subroutine_ptr
	lda #>reveal_put_valid_cell
	sta subroutine_ptr+1
	jsr reveal_put_valid_cell
chain_click_loop:
	lda stack_queue_ptr
	cmp #<stack_queue
	bne @get_next_cell
	lda stack_queue_ptr+1
	cmp #>stack_queue
	bne @get_next_cell
	rts
@get_next_cell:
click_adjacent_cells:
	jsr stack_queue_get
	jsr for_all_surrounding
	jmp chain_click_loop
reset_stack_queue_ptr:
	rts


; As was explained earlier, this subroutine is called when left-clicking a
;	cell. If the cell is already revealed or is flagged, it simply returns.
;	Next the routine checks if the cell is a mine -- this only occurs when
;	a click has been made on a revealed cell with the correct number of
;	adjacent flags. If it is, the mines are revealed and the game is over.
;	If these checks all pass, the cell is set to revealed. Next, the number
;	of adjacent mines is checked. If it is zero, the cell is added to the
;	stack-queue, and will later be chain-clicked.

reveal_put_valid_cell:
@check_revealed:
	ldy #0
	lda (cells_ptr), y
	and #$20
	beq @check_flagged
	rts
@check_flagged:
	lda (cells_ptr), y
	and #$40
	beq @check_mine
	rts
@check_mine:
	lda (cells_ptr), y
	and #$80
	beq @set_revealed
	jsr reveal_mines_flags
	rts
@set_revealed:
	lda (cells_ptr), y
	ora #$50
	sta (cells_ptr), y
	lda (cells_ptr), y
	and #$0F
	bne @dont_put
	jsr stack_queue_put
@dont_put:
	rts	
	
	
; This routine is invoked from left_click_cell if it is called on a revealed
;	cell. The routine first counts the number of adjacent flags using the
;	abstract looping subroutine for_all_adjacent with the subroutine pointer
;	set to check_flags_surrounding. The results are stored in the first
;	scratch variable on the zero page. If these results equal the number
;	of adjacent mines (stored in the lower four bits of the cell's state
;	byte in the cells array), the current cell is placed in the stack-
;	queue, the subroutine pointer is set to reveal_put_valid_cell, and
;	execution is transferred directly to the last part of left_click_cell,
;	where the adjacent cells are expanded. This setup is done directly here
;	instead of in left_click_cell in order to bypass the revealed check in
;	reveal_put_valid_cell, as the initial cell being expanded will already
;	be revealed.

click_surrounding:
	lda #0
	sta num_flags_adjacent
	lda #<check_flags_surrounding
	sta subroutine_ptr
	lda #>check_flags_surrounding
	sta subroutine_ptr+1
	jsr for_all_surrounding
	ldy #0
	lda (cells_ptr), y
	and #$0F
	cmp num_flags_adjacent
	bne @return
	jsr stack_queue_put
	lda #<reveal_put_valid_cell
	sta subroutine_ptr
	lda #>reveal_put_valid_cell
	sta subroutine_ptr+1
	jmp click_adjacent_cells
@return:
	rts
	
	
check_flags_surrounding:
	ldy #0
	lda (cells_ptr), y
	and #$20
	beq @end
	inc num_flags_adjacent
@end:
	rts
	
	
; This routine is called when a mine is clicked and the game is lost. All mines
;	and flags are set to revealed, and the game_over flag is set to 0 for
;	game over.
	
reveal_mines_flags:
	jsr hide_sprites
	lda #0
	sta game_over
	ldy #0
	lda (cells_ptr), y
	ora #$01
	sta (cells_ptr), y
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
@loop:
	cpy #TOTAL_CELLS
	beq @end
	lda (cells_ptr), y
	and #$A0
	beq @next_cell
	lda (cells_ptr), y
	ora #$50
	sta (cells_ptr), y
@next_cell:
	iny
	jmp @loop
@end:
	rts


; Called after the first left click is made. These next several routines flow
;	from one to another until the rts instruction is reached at the end of
;	zero_mine_adjacencies. After this code is run, the board will be 
;	populated with the correct number of mines in random locations with no
;	mines adjacent to the cell that was clicked first. Avoiding this first-
;	clicked cell ensures that the first click will always reveal more than
;	one mine, limiting the chance that guessing will be required after only
;	one click.


; First, set up the subroutine pointer with the routine that will be used in
;	the last step of the loop to increment adjacent mine counts of cells
;	adjacent to each mine.

initialize_mines:
	lda #<inc_mine_count
	sta subroutine_ptr
	lda #>inc_mine_count
	sta subroutine_ptr+1
	

; Initialize mines_placed counter before the main loop.

randomize_board:
	lda #0
	sta mines_placed
	
	
; For each coordinate axis, a pseudorandom byte is generated. This byte is then
;	decremented by the range of the axis until it is small enough to be a
;	valid coordinate. In order to ensure that all coordinates occur with
;	the same frequency (assuming equal frequency of pseudorandom bytes),
;	the random byte is first compared to the greatest number modulo
;	TOTAL_CELLS smaller than 256, and if it is greater than or equal to
;	this value, a new random byte is generated.
	
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
	
	
; Next, the random coordinates are compared to the cursor coordinates. If the
;	random coordinate pair falls inside the 3x3 area centered on the cursor,
;	a new random coordinate pair is generated.
	
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


; This routine follows a similar pattern to set_cells_ptr_to_cursor, but uses
;	the random coordinates stored in the x and y registers instead of the
;	cursor values. When execution reaches the end, the cells array pointer
;	will be set to the randomly-generated position.

convert_addr:
convert_y:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	lda #0
	sta current_line
	sta current_col
@loop:
	cpy #0
	beq @end
	jsr cells_ptr_down
	inc current_line
	dey
	jmp @loop
@end:
convert_x:
@loop:
	cpx #0
	beq @end
	jsr cells_ptr_right
	inc current_col
	dex
	jmp @loop
@end:
	
		
; Finally, this routine checks if the random position is already a mine. If it
;	is, a new random position is generated. If it is not, the cell is set to
;	a mine, the number of adjacent mines is set to zero, the variable
;	storing the number of mines already placed is incremented, and the
;	for_all_surrounding subroutine is called with inc_mine_count in the
;	subroutine pointer to increment the adjacent mine counts of the cells
;	adjacent to the new mine. If all mines have been placed, board
;	initialiation is finished.
	
check_mine:
	ldy #0
	lda (cells_ptr),y
	and #$80
	bne @go_back
	lda (cells_ptr),y
	ora #$80
	and #$F0
	sta (cells_ptr),y
	inc mines_placed
	jsr for_all_surrounding
	lda mines_placed
	cmp #MINES
	beq @end
@go_back:
	jmp get_randoms
@end:
	rts
	

; Called from for_all_surrounding. If the cell is not a mine, increment its
;	count of adjacent mines. If it is a mine, do nothing.
	
inc_mine_count:
	lda (cells_ptr), y
	and #$80
	bne @end
	lda (cells_ptr), y
	clc
	adc #1
	sta (cells_ptr),y
@end:
	rts
	

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
	jsr draw_board_cell
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
	

; Draws one board cell, using the pointers and variables set above.
	
draw_board_cell:
	ldy #0
	lda (cells_ptr), y
	and #$EF
	sta (cells_ptr), y
	jsr identify_cell
	jsr draw_one_graphics_cell
	jsr bitmap_ptr_right
	jsr color_ptr_right
	jsr graphics_ptr_right
	jsr draw_one_graphics_cell
	jsr bitmap_ptr_down
	jsr color_ptr_down
	jsr graphics_ptr_down
	jsr draw_one_graphics_cell
	jsr bitmap_ptr_left
	jsr color_ptr_left
	jsr graphics_ptr_left
	jsr draw_one_graphics_cell
	jsr bitmap_ptr_up
	jsr color_ptr_up
	jsr graphics_ptr_up
	rts
	
	
; Draws one individual 8x8 graphics cell, using the pointers and variables set
;	above.
	
draw_one_graphics_cell:
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
	lda #LIGHT_GRAY
	and #$0F
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
	lda #LIGHT_GRAY
	and #$0F
	jmp @after_color
@false_flag:
	lda #DARK_RED
	and #$0F
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
	lda #MID_GRAY
	and #$0F
	jmp @after
@exploded:
	lda #DARK_RED
	and #$0F
@after:
	sta current_color
	rts
@not_mine:
	lda (cells_ptr), y
	and #$0F
	bne @not_zero
	lda #<revealed_0
	sta graphics_ptr
	lda #>revealed_0
	sta graphics_ptr+1
	lda #MID_GRAY
	and #$0F
	sta current_color
	rts
@not_zero:
	cmp #1
	bne @not_one
	lda #<revealed_1
	sta graphics_ptr
	lda #>revealed_1
	sta graphics_ptr+1
	lda #LIGHT_BLUE
	and #$0F
	sta current_color
	rts
@not_one:
	cmp #2
	bne @not_two
	lda #<revealed_2
	sta graphics_ptr
	lda #>revealed_2
	sta graphics_ptr+1
	lda #GREEN
	and #$0F
	sta current_color
	rts
@not_two:
	cmp #3
	bne @not_three
	lda #<revealed_3
	sta graphics_ptr
	lda #>revealed_3
	sta graphics_ptr+1
	lda #LIGHT_RED
	and #$0F
	sta current_color
	rts
@not_three:
	cmp #4
	bne @not_four
	lda #<revealed_4
	sta graphics_ptr
	lda #>revealed_4
	sta graphics_ptr+1
	lda #DARK_BLUE
	and #$0F
	sta current_color
	rts
@not_four:
	cmp #5
	bne @not_five
	lda #<revealed_5
	sta graphics_ptr
	lda #>revealed_5
	sta graphics_ptr+1
	lda #DARK_RED
	and #$0F
	sta current_color
	rts
@not_five:
	cmp #6
	bne @not_six
	lda #<revealed_6
	sta graphics_ptr
	lda #>revealed_6
	sta graphics_ptr+1
	lda #CYAN
	and #$0F
	sta current_color
	rts
@not_six:
	cmp #7
	bne @not_seven
	lda #<revealed_7
	sta graphics_ptr
	lda #>revealed_7
	sta graphics_ptr+1
	lda #ORANGE
	and #$0F
	sta current_color
	rts
@not_seven:
	lda #<revealed_8
	sta graphics_ptr
	lda #>revealed_8
	sta graphics_ptr+1
	lda #BROWN
	and #$0F
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

after_graphics:

