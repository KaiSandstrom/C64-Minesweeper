.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


; Jump to the location of initial program execution
	jmp start


;*******************************************************************************
;*  Constants                                                                  *
;*******************************************************************************


; C64 graphics addresses and built-in routines, as well as some program-defined
;	locations. Some are only used during initial startup, but are defined
;	here for the sake of readability.


; Keyboard I/O
CHROUT = $FFE4


; Interrupt-handling
IRQ_VECTOR     = $0314
IRQ_PER_SECOND = 60


; SID chip addresses used for pseudorandom number generation
SID_CTRL_3      = $D412
SID_FREQ_3_LOW  = $D40E
SID_FREQ_3_HIGH = $D40F
RANDOM          = $D41B


; Video mode and video memory constants
FRAME_COLOR        = $D020
BACKGROUND_COLOR   = $D021
VIC_BANK_SELECT    = $DD00
VIC_MEM_CTRL       = $D018
VIC_SCREEN_CTRL    = $D011
CHAR_ROM_START     = $D000
COLOR              = $D800
CHAR_CUSTOM_SYMBS  = $4000
CHAR_CUSTOM_GRAPH  = $4200
SCREEN_BOARD       = $4800
SCREEN_SPLASH      = $4C00
SCREEN_GAMESTATS   = $5000
SCREEN_HOWTO_1     = $5400
SCREEN_HOWTO_2     = $5800
SCREEN_HOWTO_3     = $5C00
BOARD_COLOR_BCKUP  = $7800


; Color value constants
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
OUTER_SPRITE_LOCATION = $4440
INNER_SPRITE_POINTER  = $4BF9
OUTER_SPRITE_POINTER  = $4BF8
INNER_SPRITE_COLOR    = $D027
OUTER_SPRITE_COLOR    = $D028
SHOW_SPRITES_REG      = $D015


; Status screen counter addresses
SECONDS_CLOCK = SCREEN_GAMESTATS+624
MINES_LEFT    = SCREEN_GAMESTATS+504


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
scratch       = $03
mines_placed  = scratch
board_updated = scratch
line_of_three = scratch+1
current_color = scratch
num_flags     = scratch


; Stores the position of the cursor on-screen, in board tiles. 
cursor_x = $05
cursor_y = $06


; These store line and column indexes for iterating through the board. 
;	These are used instead of indirect indexing when graphics are being
;	manipulated and when a cell's neighbors need to be processed.
current_line = $9B
current_col  = $9C


; Pointers into various memory locations used in the representation of cells.
cells_ptr       = $FB
color_ptr       = $FD
g_dest_ptr      = $F7
g_src_ptr       = $F9
stack_queue_ptr = $BB


; Stores an address to be jumped to for a specific operation, used for looping
;	through adjacent cells performing an abstract task.
subroutine_ptr = $C1


; Stores the value of the IRQ vector $0314-5 when the program is first loaded
interrupt_service_prev = $57


; Initialized to IRQ_PER_SECOND at the start of a game. At each interrupt, if
;	the game is active, the clock is decremented. When it reaches 0,
;	meaning that one second has elapsed, it is reset to IRQ_PER_SECOND and
;	the characters at SECONDS_CLOCK are updated.
interrupts_clock = $52

; ******************************************************************************
; * Cells Array                                                                *
; ******************************************************************************


; The cell bytes array is located near the end of program memory, after the
;	graphics. It is 240 bytes long, the same as the number of cells in the
;	20x12 board. It is explained here instead of at the end of the file for
;	the sake of readability.

; The functions of the bits in a state byte are as follows:
;	Bit 7: Set if the cell is a mine.
;	Bit 6: Set if the cell is revealed.
;	Bit 5: Set if the cell is flagged.
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
;	necessary.

; This structure is implemented as a LIFO stack. It is described as a 
;	"stack-queue" because its function is to store the address and
;	coordinates of cells that are waiting to be expanded, and every valid
;	adjacent cell is pushed to the stack-queue before any one of them is
;	expanded, unlike with a recursive stack. The only reason it was
;	implemented as a stack instead of a queue was convenience -- a stack
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
;	array. Each cell is represented by one byte as explained above.

cells_ptr_right:
	inc cells_ptr
	bne @end
	inc cells_ptr+1
@end:
	rts
	
cells_ptr_left:
	lda cells_ptr
	bne @dec_l
	dec cells_ptr+1
@dec_l:
	dec cells_ptr
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


; Graphics pointer manipulation routines: Adjust the position of a pointer
;	into text screen memory by cell line and column. These are only used
;	when populating the game board screen with graphics characters.

g_dest_ptr_right:
	inc g_dest_ptr
	bne @end
	inc g_dest_ptr+1
@end:
	rts
	
g_dest_ptr_left:
	lda g_dest_ptr
	bne @dec_l
	dec g_dest_ptr+1
@dec_l:
	dec g_dest_ptr
	rts
	
	
g_dest_ptr_down:
	lda g_dest_ptr
	clc
	adc #(X_RANGE*2)
	sta g_dest_ptr
	lda g_dest_ptr+1
	adc #0
	sta g_dest_ptr+1
	rts
	
g_dest_ptr_up:
	lda g_dest_ptr
	sec
	sbc #(X_RANGE*2)
	sta g_dest_ptr
	lda g_dest_ptr+1
	sbc #0
	sta g_dest_ptr+1
	rts
	
; ------------------------------------------------


; Simply increment the graphics source pointer. Like the earlier set of
;	routines, this is only used when drawing cells on the board screen, and
;	and due to the way the set of character screen codes for each cell is
;	stored, no other manipulation is needed.

g_src_ptr_advance:
	inc g_src_ptr
	bne @end
	inc g_src_ptr+1
@end:
	rts
	
; ------------------------------------------------

; Color pointer manipulation routines: Adjust a pointer into color memory for
;	text mode. Used when drawing cells on the board.
	
color_ptr_right:
	inc color_ptr
	bne @end
	inc color_ptr+1
@end:
	rts
	
color_ptr_left:
	lda color_ptr
	bne @dec_l
	dec color_ptr+1
@dec_l:
	dec color_ptr
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


; Cursor adjustment routines: These not only adjust the cursor index variables,
;	but also adjust the location of the cursor sprites accordingly.
	
cursor_left:
	lda cursor_x
	beq @return
	dec cursor_x
	lda OUTER_SPRITE_X
	sec
	sbc #16
	sta OUTER_SPRITE_X
	lda INNER_SPRITE_X
	sec
	sbc #16
	sta INNER_SPRITE_X
	bcs @return
	lda #$00
	sta SPRITES_X_MSB
@return:
	rts
	
	
cursor_right:
	lda cursor_x
	cmp #(X_RANGE-1)
	beq @return
	inc cursor_x
	lda OUTER_SPRITE_X
	clc
	adc #16
	sta OUTER_SPRITE_X
	lda INNER_SPRITE_X
	clc
	adc #16
	sta INNER_SPRITE_X
	bcc @return
	lda #$03
	sta SPRITES_X_MSB
@return:
	rts
	
cursor_up:
	lda cursor_y
	beq @return
	dec cursor_y
	lda OUTER_SPRITE_Y
	sec
	sbc #16
	sta OUTER_SPRITE_Y
	lda INNER_SPRITE_Y
	sec
	sbc #16
	sta INNER_SPRITE_Y
@return:
	rts
	
	
cursor_down:
	lda cursor_y
	cmp #(Y_RANGE-1)
	beq @return
	inc cursor_y
	lda OUTER_SPRITE_Y
	clc
	adc #16
	sta OUTER_SPRITE_Y
	lda INNER_SPRITE_Y
	clc
	adc #16
	sta INNER_SPRITE_Y
@return:
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

; The cells array pointer is returned to the center after each cell in a row is
;	processed. This is inefficient, but was done in order to handle
;	potential collisions with the edge of the board. This routine may
;	eventually be rewritten with a less clunky solution.

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
;	the point in for_all_surrounding from which do_task was called.

do_task:
	jmp (subroutine_ptr)
	

; *********** Other Common Subroutines ***********


; This routine is tacked onto the beginning of the existing interupt service
;	routine, which fires 60 times per second on an NTSC machine. Its purpose
;	is to update the timer that keeps track of the number of seconds since
;	the start of the current game -- If the game is in-progress, a counter
;	is incremented, and when it hits 60, the timer display is updated. If
;	the timer reaches 999, it stops updating.

interrupt_service_extension:
	lda game_over
	cmp #1
	bne @to_prev_irq
	dec interrupts_clock
	bne @to_prev_irq
	lda #IRQ_PER_SECOND
	sta interrupts_clock
	lda SECONDS_CLOCK
	cmp #$39
	bne @update_seconds_clock
	lda SECONDS_CLOCK+1
	cmp #$39
	bne @update_seconds_clock
	lda SECONDS_CLOCK+2
	cmp #$39
	beq @to_prev_irq
@update_seconds_clock:
	inc SECONDS_CLOCK+2
	lda #$3A
	cmp SECONDS_CLOCK+2
	bne @to_prev_irq
	lda #$30
	sta SECONDS_CLOCK+2
	inc SECONDS_CLOCK+1
	lda #$3A
	cmp SECONDS_CLOCK+1
	bne @to_prev_irq
	lda #$30
	sta SECONDS_CLOCK+1
	inc SECONDS_CLOCK
@to_prev_irq:
	jmp (interrupt_service_prev)
	

; These two routines show and hide the two sprites that make up the cursor,
;	respectively.

show_sprites:
	lda SHOW_SPRITES_REG
	ora #$03
	sta SHOW_SPRITES_REG
	rts


hide_sprites:
	lda SHOW_SPRITES_REG
	and #$FC
	sta SHOW_SPRITES_REG
	rts
	

; These two routines show and hide the screen. Used when updating the color RAM
;	when screens are switched, in order to avoid briefly showing incorrect
;	colors.

show_screen:
	lda VIC_SCREEN_CTRL
	ora #$10
	sta VIC_SCREEN_CTRL
	rts
	
	
hide_screen:
	lda VIC_SCREEN_CTRL
	and #$EF
	sta VIC_SCREEN_CTRL
	rts
	
	
; Simply wait for any key to be pressed.

await_input:
	jsr CHROUT
	beq await_input
	rts
	
	
; Since the game board only uses 24 out of 25 rows, the final row of the screen
;	is filled in with full-block characters. This routine sets the color
;	RAM of these characters to match the frame color, which is stored in
;	current_color.
	
draw_last_strip:
	lda #>COLOR
	clc
	adc #3
	sta color_ptr+1
	lda #<COLOR
	adc #192
	sta color_ptr
	lda current_color
	ldy #(X_RANGE*2)
@loop:
	sta (color_ptr), y
	dey
	bpl @loop
@end:
	rts
	

; Sets up color RAM and VIC to display the intro/splash screen and waits for
;	input.
	
show_intro_screen:
	jsr fill_color_white
	lda #MID_GRAY
	sta COLOR+4
	sta COLOR+5
	sta COLOR+34
	sta COLOR+35
	sta COLOR+44
	sta COLOR+45
	sta COLOR+74
	sta COLOR+75
	lda VIC_MEM_CTRL
	and #$01
	ora #$30
	sta VIC_MEM_CTRL
	jsr show_screen
	jsr await_input
	jsr hide_screen
	lda game_over
	beq @keep_sprites_hidden
	jsr show_sprites
@keep_sprites_hidden:
	rts
	
	
; Used when showing the intro/splash screen with the I key. Does additional
;	graphics processing unnecessary when showing this screen for the
;	first time, including showing the board again when dismissed.

show_intro_again:
	lda FRAME_COLOR
	sta current_color
	lda #BLACK
	sta FRAME_COLOR
	jsr hide_sprites
	jsr hide_screen
	jsr backup_board_color
	jsr show_intro_screen
	lda current_color
	sta FRAME_COLOR
	jsr show_board
	rts
	
	
; Shows the three screens of the "how to play" text, one after the other in
;	order, waiting for user input in between.
	
show_howto_screen:
	lda FRAME_COLOR
	sta current_color
	lda #BLACK
	sta FRAME_COLOR
	jsr hide_sprites
	jsr hide_screen
	jsr fill_color_white
	lda VIC_MEM_CTRL
	and #$01
	ora #$50
	sta VIC_MEM_CTRL
	jsr show_screen
	jsr await_input
	lda VIC_MEM_CTRL
	and #$01
	ora #$60
	sta VIC_MEM_CTRL
	jsr await_input
	lda VIC_MEM_CTRL
	and #$01
	ora #$70
	sta VIC_MEM_CTRL
	jsr await_input
	jsr hide_screen
	lda game_over
	beq @keep_sprites_hidden
	jsr show_sprites
@keep_sprites_hidden:
	lda current_color
	sta FRAME_COLOR
	jmp show_board


; Shows the game stats screen, placing the correct characters in the "mines
;	minus flags" line each time it's called.	
	
show_status_screen:
	lda FRAME_COLOR
	sta current_color
	jsr backup_board_color
	lda #BLACK
	sta FRAME_COLOR
	jsr hide_sprites
	jsr hide_screen
	jsr fill_color_white
	lda VIC_MEM_CTRL
	and #$01
	ora #$40
	sta VIC_MEM_CTRL
	jsr set_flags_count
	jsr show_screen
	jsr await_input
	jsr hide_screen
	lda game_over
	beq @keep_sprites_hidden
	jsr show_sprites
@keep_sprites_hidden:
	lda current_color
	sta FRAME_COLOR
	
	
; Switches the VIC to show the game board, retrieving the board's color info
;	from the backup page and placing it in color RAM.
	
show_board:
	lda #<BOARD_COLOR_BCKUP
	sta g_src_ptr
	lda #>BOARD_COLOR_BCKUP
	sta g_src_ptr+1
	lda #<COLOR
	sta g_dest_ptr
	lda #>COLOR
	sta g_dest_ptr+1
	jsr copy_screen_ram
	jsr draw_last_strip
	lda VIC_MEM_CTRL
	and #$01
	ora #$20
	sta VIC_MEM_CTRL
	jsr show_screen
	rts
	

; Copies 1K of memory from the location in g_src_ptr to the location in
;	g_dest_ptr, performing the task at the address stored in subroutine_ptr
;	for each byte.
	
copy_screen_inner:
	ldx #0
	ldy #0
@loop:
	lda (g_src_ptr), y
	jsr do_task
	sta (g_dest_ptr), y
	iny
	bne @loop
	inc g_src_ptr+1
	inc g_dest_ptr+1
	inx
	cpx #4
	bne @loop
	rts
	

; Convert a PETSCII code to a screen RAM code

convert_screen_code:
	cmp #$40
	bcc @no_change
	cmp #$60
	bcs @no_change
	clc
	adc #$C0
@no_change:
	rts
	
	
; Nothing. The purpose of this subroutine is as an empty value in the
;	subroutine pointer as an alternative to convert_screen_code when not
;	copying text.

no_op:
	rts
	
	
; Simply copy the bytes using copy_screen_inner -- place no_op in subroutine_ptr
	
copy_screen_ram:
	lda #<no_op
	sta subroutine_ptr
	lda #>no_op
	sta subroutine_ptr+1
	jmp copy_screen_inner
	
	
; Load convert_screen_code into subroutine_ptr and call copy_screen_inner. This
;	is used to copy a text screen into memory. The text is stored as
;	ASCII/PETSCII for the sake of convenience, so the values must be
;	converted to screen codes.
	
copy_text_screen:
	lda #<convert_screen_code
	sta subroutine_ptr
	lda #>convert_screen_code
	sta subroutine_ptr+1
	jmp copy_screen_inner
	

; Fill color memory with white

fill_color_white:
	lda #<COLOR
	sta g_dest_ptr
	lda #>COLOR
	sta g_dest_ptr+1
	ldx #0
	ldy #0
@loop:
	lda #WHITE
	sta (g_dest_ptr), y
	iny
	bne @loop
	inc g_dest_ptr+1
	inx
	cpx #4
	bne @loop
	rts
	

; Copy color RAM into the 1K section used to store a backup of the board colors.
;	The inverse is performed in show_board.
	
backup_board_color:
	lda #<COLOR
	sta g_src_ptr
	lda #>COLOR
	sta g_src_ptr+1
	lda #<BOARD_COLOR_BCKUP
	sta g_dest_ptr
	lda #>BOARD_COLOR_BCKUP
	sta g_dest_ptr+1
	jsr copy_screen_ram
	rts
	
	
; Update the status screen with the appropriate number for mines minus flags
	
set_flags_count:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	ldy #0
	ldx #0
@loop:
	cpy #TOTAL_CELLS
	beq @end
	lda (cells_ptr), y
	and #$20
	beq @next
	inx
@next:
	iny
	jmp @loop
@end:
	lda #$30
	sta MINES_LEFT
	sta MINES_LEFT+1
	txa
	eor #$FF
	clc
	adc #41
	bmi @fixed_msg
@sub10:
	cmp #10
	bcc @done
	sec
	sbc #10
	inc MINES_LEFT
	jmp @sub10
@done:
	adc #$30
	sta MINES_LEFT+1
	jmp @return
@fixed_msg:
	lda #$3C
	sta MINES_LEFT
	lda #$30
	sta MINES_LEFT+1
@return:
	rts
	
	

	
;******************************************************************************
;*  Game Initial Startup Code                                                 *
;******************************************************************************
	
	
; This section of code is run only once, when the game starts for the first
;	time. The character set and text screens are initialized, and 

start:
	jsr hide_screen
	
	lda #BLACK
	sta BACKGROUND_COLOR
	sta FRAME_COLOR
	
	lda VIC_BANK_SELECT
	and #$FC
	ora #$02
	sta VIC_BANK_SELECT
	

init_interrupt:
	lda IRQ_VECTOR
	sta interrupt_service_prev
	lda IRQ_VECTOR+1
	sta interrupt_service_prev+1
	sei
	lda #<interrupt_service_extension
	sta IRQ_VECTOR
	lda #>interrupt_service_extension
	sta IRQ_VECTOR+1
	cli
	
	
; Initialize SID chip voice 3 -- the output of this voice will be used to
;	generate pseudorandom numbers for use in placing mines on the board.

init_SID_random:
	lda #$FF
	sta SID_FREQ_3_LOW
	sta SID_FREQ_3_HIGH
	lda #$80
	sta SID_CTRL_3
	

init_charset:
copy_text_chars:
	lda #<CHAR_ROM_START
	sta g_src_ptr
	lda #>CHAR_ROM_START
	sta g_src_ptr+1
	lda #<CHAR_CUSTOM_SYMBS
	sta g_dest_ptr
	lda #>CHAR_CUSTOM_SYMBS
	sta g_dest_ptr+1
	
	sei
	lda $01
	and #$FB
	sta $01
	
	ldx #0
	ldy #0
		
@loop:
	lda (g_src_ptr), y
	sta (g_dest_ptr), y
	iny
	bne @loop
	inc g_src_ptr+1
	inc g_dest_ptr+1
	inx
	cpx #2
	bne @loop
	
	lda $01
	ora #$04
	sta $01
	cli
	
	
copy_graphics_chars:
	lda #<custom_chars
	sta g_src_ptr
	lda #>custom_chars
	sta g_src_ptr+1
	lda #<CHAR_CUSTOM_GRAPH
	sta g_dest_ptr
	lda #>CHAR_CUSTOM_GRAPH
	sta g_dest_ptr+1
	
	ldy #0	
@loop1:
	lda (g_src_ptr), y
	sta (g_dest_ptr), y
	iny
	bne @loop1
	
	inc g_src_ptr+1
	inc g_dest_ptr+1
	ldy #97
@loop2:
	lda (g_src_ptr), y
	sta (g_dest_ptr), y
	dey
	bpl @loop2


load_intro_screen:
	lda #<intro_screen
	sta g_src_ptr
	lda #>intro_screen
	sta g_src_ptr+1
	lda #<SCREEN_SPLASH
	sta g_dest_ptr
	lda #>SCREEN_SPLASH
	sta g_dest_ptr+1
	jsr copy_text_screen

	
load_details_one:
	lda #<details_one
	sta g_src_ptr
	lda #>details_one
	sta g_src_ptr+1
	lda #<SCREEN_HOWTO_1
	sta g_dest_ptr
	lda #>SCREEN_HOWTO_1
	sta g_dest_ptr+1
	jsr copy_text_screen
	
	
load_details_two:
	lda #<details_two
	sta g_src_ptr
	lda #>details_two
	sta g_src_ptr+1
	lda #<SCREEN_HOWTO_2
	sta g_dest_ptr
	lda #>SCREEN_HOWTO_2
	sta g_dest_ptr+1
	jsr copy_text_screen
	
	
load_details_three:
	lda #<details_three
	sta g_src_ptr
	lda #>details_three
	sta g_src_ptr+1
	lda #<SCREEN_HOWTO_3
	sta g_dest_ptr
	lda #>SCREEN_HOWTO_3
	sta g_dest_ptr+1
	jsr copy_text_screen
	
	
load_status:
	lda #<status_screen
	sta g_src_ptr
	lda #>status_screen
	sta g_src_ptr+1
	lda #<SCREEN_GAMESTATS
	sta g_dest_ptr
	lda #>SCREEN_GAMESTATS
	sta g_dest_ptr+1
	jsr copy_text_screen
	

last_strip_chars:
	ldx #0
@loop:
	cpx #40
	beq @end
	lda #$42
	sta SCREEN_BOARD+960, x
	inx
	jmp @loop
@end:


	
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
	lda #16
	sta INNER_SPRITE_POINTER
	lda #17
	sta OUTER_SPRITE_POINTER
	
	lda #DARK_RED
	sta INNER_SPRITE_COLOR
	lda #WHITE
	sta OUTER_SPRITE_COLOR
	
	
	jsr show_intro_screen
	

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
	lda #$30
	sta SECONDS_CLOCK
	sta SECONDS_CLOCK+1
	sta SECONDS_CLOCK+2
	

; Initialize the board backup with the color of an unrevealed cell, as this
;	backup will be loaded by draw_board

	lda #<BOARD_COLOR_BCKUP
	sta g_dest_ptr
	lda #>BOARD_COLOR_BCKUP
	sta g_dest_ptr+1
	ldx #0
	ldy #0
@loop:
	lda #LIGHT_GRAY
	sta (g_dest_ptr), y
	iny
	bne @loop
	inc g_dest_ptr+1
	inx
	cpx #4
	bne @loop
	

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
;	X starting position 167 = 23 for col 0 + 9x16 for col 9
;	Y starting position 129 = 49 for col 0 + 5x15 for row 5

pos_sprites:	
	lda #167
	sta INNER_SPRITE_X
	sta OUTER_SPRITE_X
	
	lda #129
	sta INNER_SPRITE_Y
	sta OUTER_SPRITE_Y
	
	lda #0
	sta SPRITES_X_MSB

	jsr show_sprites

	
; Set the frame color to dark gray and show the board.

	lda #DARK_GRAY
	sta FRAME_COLOR
	jsr show_board
	


; ******************************************************************************
; * Inner Game Loop                                                            *
; ******************************************************************************


; This code runs continuously until a new game is started when the player
;	presses the N key. Consists of this single get_input routine, which
;	jumps to other routines depending on the player's selection. Game logic
;	itself is defined in a later section.
	
get_input:
	jsr CHROUT
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
	bne @check_howto
	jsr show_intro_again
	jmp get_input
@check_howto:
	tax
	cmp #$48
	bne @check_status
	jsr show_howto_screen
	jmp get_input
@check_status:
	tax
	cmp #$47
	bne @check_game_over
	jsr show_status_screen
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
	jmp get_input
@check_space:
	txa
	cmp #$20
	bne @to_get_input
	lda game_over
	cmp #2
	bne @after_first_click
	lda #1
	sta game_over
	jsr initialize_mines
	lda #IRQ_PER_SECOND
	sta interrupts_clock
@after_first_click:
	jsr left_click_cell
@to_get_input:
	jmp get_input
	

; ******************************************************************************
; * Game Logic                                                                 *
; ******************************************************************************


; These routines manipulate the board and game state according to the operation
;	the player has selected.

; ------------------------------------------------


; ************* Board Initialization *************

; Called after the first left click is made. These next several routines flow
;	from one to another and run as a loop until the correct number of 
;	mines have been placed. After this code is run, the board will be 
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
	lda #MINES
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
	cpy #0
	beq @end
@loop:
	jsr cells_ptr_down
	inc current_line
	dey
	beq @end
	jmp @loop
@end:
convert_x:
	cpx #0
	beq @end
@loop:
	jsr cells_ptr_right
	inc current_col
	dex
	beq @end
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
	dec mines_placed
	jsr for_all_surrounding
	lda mines_placed
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

; -----------------------------------------------


; ************** Utility Routines ***************


; These are either called from the inner game loop (check_state), or used in
;	the left-click and/or right-click routines for a purpose unrelated to
;	the main click operation itself. They are defined here for the sake of
;	readability, to keep them separate from the main logic of the click
;	operations.


; Checks for a win or loss, and updates the frame color (and 25th bitmap row)
;	accordingly: red for loss, green for win.
; When checking for a win, one of the zeropage scratch variables is used to
;	count flagged cells. Every cell is checked, and if it is flagged, this
;	counter is incremented. If any unflagged, unrevealed cell is found, 
;	the routine immediately returns, as this means the game is not yet won.
;	If no unrevealed unflagged cells are found, the number of flagged cells
;	is compared to the number of mines. If they are equal, the game is won.
;	The game_over variable is set accordingly, the cursor is hidden, and
;	the frame is changed to green.

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
	sta num_flags
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
	beq @return
	iny
	jmp @loop
@flagged:
	inc num_flags
	iny
	jmp @loop
@end:
	lda num_flags
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
	cpx #0
	beq @end
@y_loop:
	jsr cells_ptr_down
	dex
	beq @end
	jmp @y_loop
@end:
	ldx cursor_x
	stx current_col
	cpx #0
	beq @done
@x_loop:
	jsr cells_ptr_right
	dex
	beq @done
	jmp @x_loop
@done:
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


; ********* Left-Click and Right-Click **********


; Both the left-click and right-click routines will draw the board and check the
;	game state if and only if the board has been udpated.


; ------------------------------------------------
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
;	the abstract for_all_surrounding subroutine is called with 
;	reveal_put_valid_cell loaded into the subroutine pointer. After this is
;	complete, execution jumps back to the start of the chain-click loop, and
;	this loop continues executing until the stack-queue is empty.

left_click_cell:
	jsr set_cells_ptr_to_cursor
	ldy #0
	sta board_updated
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
	lda board_updated
	beq @dont_update
	jsr draw_board
	jsr check_state
@dont_update:
	rts
@get_next_cell:
click_adjacent_cells:
	jsr stack_queue_get
	jsr for_all_surrounding
	jmp chain_click_loop


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
	lda #1
	sta board_updated
	lda (cells_ptr), y
	ora #$50
	sta (cells_ptr), y
	and #$0F
	bne @dont_put
	jsr stack_queue_put
@dont_put:
	rts	
	
	
; This routine is invoked from left_click_cell if it is called on a revealed
;	cell. The routine first counts the number of adjacent flags using the
;	abstract looping subroutine for_all_surrounding with the subroutine_ptr
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
	sta num_flags
	lda #<check_flags_surrounding
	sta subroutine_ptr
	lda #>check_flags_surrounding
	sta subroutine_ptr+1
	jsr for_all_surrounding
	ldy #0
	lda (cells_ptr), y
	and #$0F
	cmp num_flags
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
	inc num_flags
@end:
	rts
	
; ------------------------------------------------
; "Right-clicks" a cell, flagging any unflagged unrevealed cell and unflagging
;	any flagged unrevealed cell. Revealed cells are unaffected. 

right_click_cell:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr),y
	and #$40
	beq @unrevealed
	jmp @return
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
	jmp @update_and_return
@not_flagged:
	lda (cells_ptr), y
	ora #$20
	sta (cells_ptr), y
@update_and_return:
	jsr draw_board
	jsr check_state
@return:
	rts
	

; ******************************************************************************
; * Graphics Routines                                                          *
; ******************************************************************************
	
	
; These routines are used to draw the board in screen memory according to the
;	state of each cell.
	

; This routine draws the board in bitmap memory, only updating cells with the
;	update bit set for the sake of efficiency. This routine itself is mostly
;	pointer manipulation -- The first part executes once and initializes all
;	pointers and variables used. The main loop simply loads a byte from the
;	cells array, clears the update bit, and calls the draw_board_cell
;	subroutine. The code in @advance sets up the pointers for the next
;	cell.
	
draw_board:
	lda #<cells_array
	sta cells_ptr
	lda #>cells_array
	sta cells_ptr+1
	lda #<COLOR
	sta color_ptr
	lda #>COLOR
	sta color_ptr+1
	lda #<SCREEN_BOARD
	sta g_dest_ptr
	lda #>SCREEN_BOARD
	sta g_dest_ptr+1
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
	jsr g_dest_ptr_right
	jsr g_dest_ptr_right
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
	jsr g_dest_ptr_down
	jsr color_ptr_down
	jmp @loop
@end:
	rts
	

; Draws one board cell, using the pointers and variables set above. Each board
;	cell consists of four separate graphics cells.
	
draw_board_cell:
	ldy #0
	lda (cells_ptr), y
	and #$EF
	sta (cells_ptr), y
	jsr identify_cell
	jsr draw_one_graphics_cell
	jsr g_dest_ptr_right
	jsr g_src_ptr_advance
	jsr color_ptr_right
	jsr draw_one_graphics_cell
	jsr g_dest_ptr_down
	jsr g_src_ptr_advance
	jsr color_ptr_down
	jsr draw_one_graphics_cell
	jsr g_dest_ptr_left
	jsr g_src_ptr_advance
	jsr color_ptr_left
	jsr draw_one_graphics_cell
	jsr g_dest_ptr_up
	jsr g_src_ptr_advance
	jsr color_ptr_up
	rts
	
	
; Draws one individual 8x8 graphics cell, using the pointers and variables set
;	above.
	
draw_one_graphics_cell:
	lda current_color
	sta (color_ptr), y
	lda (g_src_ptr), y
	sta (g_dest_ptr), y
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
	sta g_src_ptr
	lda #>unrevealed
	sta g_src_ptr+1
	lda #LIGHT_GRAY
	and #$0F
	sta current_color
	rts
@flagged:
	lda #<flag
	sta g_src_ptr
	lda #>flag
	sta g_src_ptr+1
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
	sta g_src_ptr
	lda #>mine
	sta g_src_ptr+1
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
	sta g_src_ptr
	lda #>revealed_0
	sta g_src_ptr+1
	lda #MID_GRAY
	and #$0F
	sta current_color
	rts
@not_zero:
	cmp #1
	bne @not_one
	lda #<revealed_1
	sta g_src_ptr
	lda #>revealed_1
	sta g_src_ptr+1
	lda #LIGHT_BLUE
	and #$0F
	sta current_color
	rts
@not_one:
	cmp #2
	bne @not_two
	lda #<revealed_2
	sta g_src_ptr
	lda #>revealed_2
	sta g_src_ptr+1
	lda #GREEN
	and #$0F
	sta current_color
	rts
@not_two:
	cmp #3
	bne @not_three
	lda #<revealed_3
	sta g_src_ptr
	lda #>revealed_3
	sta g_src_ptr+1
	lda #LIGHT_RED
	and #$0F
	sta current_color
	rts
@not_three:
	cmp #4
	bne @not_four
	lda #<revealed_4
	sta g_src_ptr
	lda #>revealed_4
	sta g_src_ptr+1
	lda #DARK_BLUE
	and #$0F
	sta current_color
	rts
@not_four:
	cmp #5
	bne @not_five
	lda #<revealed_5
	sta g_src_ptr
	lda #>revealed_5
	sta g_src_ptr+1
	lda #DARK_RED
	and #$0F
	sta current_color
	rts
@not_five:
	cmp #6
	bne @not_six
	lda #<revealed_6
	sta g_src_ptr
	lda #>revealed_6
	sta g_src_ptr+1
	lda #CYAN
	and #$0F
	sta current_color
	rts
@not_six:
	cmp #7
	bne @not_seven
	lda #<revealed_7
	sta g_src_ptr
	lda #>revealed_7
	sta g_src_ptr+1
	lda #ORANGE
	and #$0F
	sta current_color
	rts
@not_seven:
	lda #<revealed_8
	sta g_src_ptr
	lda #>revealed_8
	sta g_src_ptr+1
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
.byte "    ", $64, $65, "        minesweeper     "
.byte "    ", $64, $65, "    "
.byte "    ", $67, $66, "    for the commodore 64"
.byte "    ", $67, $66, "    "
.byte "                                        "
.byte "    written in 2022 by kai sandstrom    "
.byte "  programmed entirely in 6502 assembly  "
.byte "                                        "
.byte "                                        "
.byte "               controls:                "
.byte "                                        "
.byte "wasd:  move cursor                      "
.byte "                                        "
.byte "space: clear mine                       "
.byte "                                        "
.byte "e:     flag/unflag mine                 "
.byte "                                        "
.byte "n:     start new game                   "
.byte "                                        "
.byte "h:     how to play/detailed instructions"
.byte "                                        "
.byte "g:     show game status screen          "
.byte "                                        "
.byte "i:     show this screen again           "
.byte "                                        "
.byte "                                        "
.byte "       press any key to continue.       "

details_one:
.byte "the goal of minesweeper is to flag all  "
.byte "mines and clear all non-mine cells. a   "
.byte "fixed number of mines are distributed   "
.byte "randomly on the board. all cells start  "
.byte "out hidden.                             "
.byte "                                        "
.byte "press space to clear the cell indicated "
.byte "by the cursor. if the cell is a mine,   "
.byte "the game is lost.                       "
.byte "                                        "
.byte "clearing a cell will show how many mines"
.byte "are adjacent to the newly-cleared cell, "
.byte "indicated by a number. if a cell has no "
.byte "adjacent mines, it will appear blank    "
.byte "like a hidden cell, but will show a     "
.byte "a darker shade of gray.                 "
.byte "                                        "
.byte "when a cell with no adjacent mines is   "
.byte "cleared, all mines adjacent to it are   "
.byte "cleared as well. this operation chains  "
.byte "until the entire contiguous area with   "
.byte "no adjacent mines is revealed.          "
.byte "                                        "
.byte "                                        "
.byte "      press any key to continue.        "

details_two:

.byte "your first reveal operation is always   "
.byte "guaranteed to reveal more than one cell:"
.byte "no mines will be placed adjacent to the "
.byte "location of your first clear operation. "
.byte "                                        "
.byte "use the e key to flag a hidden cell or  "
.byte "unflag a flagged cell. a cleared cell   "
.byte "cannot be flagged, and a flagged cell   "
.byte "cannot be cleared.                      "
.byte "                                        "
.byte "a flag indicates that a cell is known   "
.byte "to be a mine. flag cells that you are   "
.byte "certain are mines, and use the number   "
.byte "and placement of flags to determine     "
.byte "which other cells are mines.            "
.byte "                                        "
.byte "in most circumstances, attempting to    "
.byte "clear an already-revealed cell will     "
.byte "have no effect; however, if a cleared   "
.byte "cell has the same number of flags       "
.byte "adjacent to it as its number of adjacent"
.byte "mines, pressing space on this cell will "
.byte "clear all adjacent hidden cells.        "
.byte "                                        "
.byte "      press any key to continue.        "

details_three:
.byte "                                        "
.byte "if the adjacent flags were placed       "
.byte "incorrectly and a mine is revealed by   "
.byte "this operation, the game is lost.       "
.byte "                                        "
.byte "press g to show the game status screen. "
.byte "                                        "
.byte "the ", $22, "mines minus flags", $22 
.byte " field displays  "
.byte "the number of flags on the field        "
.byte "subtracted from the total number of     "
.byte "mines displayed on the previous line.   "
.byte "when all flags are placed correctly,    "
.byte "this number represents the number of    "
.byte "unflagged mines remaining on the board. "
.byte "                                        "
.byte "the timer is activated when the first   "
.byte "clear operation is performed. it freezes"
.byte "when a game is won or lost, and is reset"
.byte "to zero when the n key is pressed. keep "
.byte "track of your shortest times and compete"
.byte "for the fastest win!                    "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "  press any key to return to the game.  "


status_screen:
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "    total mines:        40              "
.byte "                                        "
.byte "                                        "
.byte "    mines minus flags:  40              "
.byte "                                        "
.byte "                                        "
.byte "    current game timer: 000 seconds     "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "
.byte "                                        "

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
	
	
	
; Custom graphics characters: The following 44 sets of 8 bytes are custom
;	graphics characters that are loaded into character memory at the start
;	of program execution. Each board tile is made up of four characters,
;	listed in the order top-left, top-right, bottom-right, bottom-left.

custom_chars:


; revealed 0 / unrevealed

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01111111  
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111

.byte %00000000
.byte %11111111
.byte %11111111
.byte %11111111  
.byte %11111111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %11111111
.byte %11111111
.byte %11111111
.byte %11111111 
.byte %11111111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111  
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 1

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111110
.byte %01111100
.byte %01111000
.byte %01111110

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00111111
.byte %00111111
.byte %00111111
.byte %00111111
.byte %00111111

.byte %00111111
.byte %00111111
.byte %00111111
.byte %00001111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01111110
.byte %01111110
.byte %01111110
.byte %01111000
.byte %01111000
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 2

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01110000
.byte %01100000
.byte %01100011
.byte %01111111
.byte %01111111

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00001111
.byte %00000111
.byte %11000111
.byte %11000111
.byte %00001111

.byte %00011111
.byte %01111111
.byte %11111111
.byte %00000111
.byte %00000111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01111100
.byte %01110000
.byte %01100001
.byte %01100000
.byte %01100000
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 3

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01100000
.byte %01100000
.byte %01111111
.byte %01111111
.byte %01111100

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00001111
.byte %00000111
.byte %11000111
.byte %11000111
.byte %00001111

.byte %00001111
.byte %11000111
.byte %11000111
.byte %00000111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01111100
.byte %01111111
.byte %01111111
.byte %01100000
.byte %01100000
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 4

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01111000
.byte %01111000
.byte %01110001
.byte %01110001
.byte %01100000

.byte %00000000
.byte %11111111
.byte %11111111
.byte %10001111
.byte %10001111
.byte %10001111
.byte %10001111
.byte %00000111

.byte %00000111
.byte %10001111
.byte %10001111
.byte %10001111
.byte %10001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01100000
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 5

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01100000
.byte %01100000
.byte %01100011
.byte %01100011
.byte %01100000

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00000111
.byte %00000111
.byte %11111111
.byte %11111111
.byte %00001111

.byte %00000111
.byte %11000111
.byte %11000111
.byte %00000111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01100000
.byte %01111111
.byte %01111111
.byte %01100000
.byte %01100000
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 6

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01110000
.byte %01100000
.byte %01100011
.byte %01100011
.byte %01100000

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00001111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %00001111

.byte %00000111
.byte %11000111
.byte %11000111
.byte %00000111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01100000
.byte %01100011
.byte %01100011
.byte %01100000
.byte %01110000
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 7

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01100000
.byte %01100000
.byte %01111111
.byte %01111111
.byte %01111111

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00000111
.byte %00000111
.byte %11000111
.byte %11000111
.byte %10001111

.byte %10001111
.byte %00011111
.byte %00011111
.byte %00111111
.byte %00111111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111110
.byte %01111110
.byte %01111111
.byte %01111111
.byte %01111111



; revealed 8

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01110000
.byte %01100000
.byte %01100011
.byte %01100011
.byte %01110000

.byte %00000000
.byte %11111111
.byte %11111111
.byte %00001111
.byte %00000111
.byte %11000111
.byte %11000111
.byte %00001111

.byte %00001111
.byte %11000111
.byte %11000111
.byte %00000111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01110000
.byte %01100011
.byte %01100011
.byte %01100000
.byte %01110000
.byte %01111111
.byte %01111111
.byte %01111111



; mine

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01110100
.byte %01111000
.byte %01110011
.byte %01110011

.byte %00000000
.byte %11111111
.byte %01111111
.byte %01111111
.byte %00010111
.byte %00001111
.byte %00000111
.byte %00000111

.byte %00000001
.byte %00000111
.byte %00000111
.byte %00001111
.byte %00010111
.byte %01111111
.byte %01111111
.byte %11111111

.byte %01000000
.byte %01110000
.byte %01110000
.byte %01111000
.byte %01110100
.byte %01111111
.byte %01111111
.byte %01111111



; flag

.byte %00000000
.byte %01111111
.byte %01111111
.byte %01111110
.byte %01111000
.byte %01110000
.byte %01111000
.byte %01111110

.byte %00000000
.byte %11111111
.byte %11111111
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111
.byte %01111111

.byte %01111111
.byte %01111111
.byte %00111111
.byte %00001111
.byte %00001111
.byte %11111111
.byte %11111111
.byte %11111111

.byte %01111111
.byte %01111111
.byte %01111100
.byte %01110000
.byte %01110000
.byte %01111111
.byte %01111111
.byte %01111111


; Custom character screen codes: This data section lists the screen codes of
;	the four custom graphics characters that make up each tile type on the
;	board.

revealed_0:
unrevealed:
.byte $40, $41, $42, $43

revealed_1:
.byte $44, $45, $46, $47

revealed_2:
.byte $48, $49, $4A, $4B

revealed_3:
.byte $4C, $4D, $4E, $4F

revealed_4:
.byte $50, $51, $52, $53

revealed_5:
.byte $54, $55, $56, $57

revealed_6:
.byte $58, $59, $5A, $5B

revealed_7:
.byte $5C, $5D, $5E, $5F

revealed_8:
.byte $60, $61, $62, $63

mine:
.byte $64, $65, $66, $67

flag:
.byte $68, $69, $6A, $6B


after_graphics:

