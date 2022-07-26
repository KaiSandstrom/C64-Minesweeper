.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

X_RANGE = 20
Y_RANGE = 12
TOTAL_CELLS = (X_RANGE*Y_RANGE)

GETCHAR = $FFE4
PUTCHAR = $FFD2

RANDOM = $D41B
COLOR = $4000
BITMAP = $6000

INNER_SPRITE_X = $D000
INNER_SPRITE_Y = $D001
OUTER_SPRITE_X = $D002
OUTER_SPRITE_Y = $D003
SPRITES_X_MSB = $D010

MINES = 40

cells_ptr = $FB
color_ptr = $FD
bitmap_ptr = $F7
graphics_ptr = $F9

	jmp show_intro_screen
	
temp:
.byte 0, 0
	
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

cursor_x:
.byte 9

cursor_y:
.byte 5

current_line:
.byte 0
current_col:
.byte 0

game_over:
.byte 0

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
	
show_intro_screen:
	ldx #0
	stx $D021
	stx $D020
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

await_input:
	jsr GETCHAR
	cmp #0
	beq await_input

init_SID_random:
	lda #$FF
	sta $D40E
	sta $D40F
	lda #$80
	sta $D412
	
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
	sta temp
	ldy #0
@bitmap_loop:
	lda #0
	sta (bitmap_ptr), y
	iny
	cpy #0
	bne @bitmap_loop
	inc temp
	inc bitmap_ptr+1
	lda temp
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
	sta temp
	ldy #0
@color_loop:
	lda #0
	sta (color_ptr), y
	iny
	cpy #0
	bne @color_loop
	inc temp
	inc color_ptr+1
	lda temp
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
	sta $D020
	sta $D021
	
	lda $D011
	ora #$20
	sta $D011
	
	lda $DD02
	ora #$03
	sta $DD02
	
	lda $DD00
	and #$FC
	ora #$02
	sta $DD00
	
	lda #08
	sta $D018
	
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
	
new_game:
	lda #5
	sta cursor_y
	lda #9
	sta cursor_x
	lda #0
	sta game_over
	sta mines_placed
	lda #$0B
	sta $D020
	sta $D021
	
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

clear_chunks:
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


pos_sprites:	
	lda #23
	sta $D000
	sta $D002
	
	lda #49
	sta $D001
	sta $D003
	
	lda #0
	sta $D010
	
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

get_input_first:
	jsr GETCHAR
	tax
	cmp #$49
	bne @not_i
	jsr show_intro_again
	jmp get_input_first
@not_i:
	txa
	cmp #$57
	bne @not_w
	jsr cursor_up
	jmp get_input_first
@not_w:
	txa
	cmp #$41
	bne @not_a
	jsr cursor_left
	jmp get_input_first
@not_a:
	txa
	cmp #$53
	bne @not_s
	jsr cursor_down
	jmp get_input_first
@not_s:
	txa
	cmp #$44
	bne @not_d
	jsr cursor_right
	jmp get_input_first
@not_d:
	txa
	cmp #$20
	bne get_input_first
	jsr randomize_board
	jsr count_adjacent
	jsr left_click_cell
	jsr draw_board
	
get_input:
	jsr GETCHAR
	tax
	cmp #$4E
	bne @not_n
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
	jsr right_click_cell
	jsr draw_board
	jsr check_state
	jmp get_input
@not_e:
	txa
	cmp #$20
	bne get_input
	jsr left_click_cell
	jsr draw_board
	jsr check_state
	jmp get_input
	
show_intro_again:
	lda $D015
	and #$FC
	sta $D015
	lda $D020
	pha
	lda #0
	sta $D020
	sta $D021
	lda #$14
	sta $D018
	lda $D011
	and #$DF
	sta $D011
	lda $DD00
	and #$FC
	ora #$03
	sta $DD00
@await_input:
	jsr GETCHAR
	cmp #0
	beq @await_input
	pla
	sta $D020
	sta $D021
	lda #$08
	sta $D018
	lda $D011
	ora #$20
	sta $D011
	lda $DD00
	and #$FC
	ora #$02
	sta $DD00
	lda $D015
	ora #$03
	sta $D015
	rts

check_state:
	lda game_over
	beq not_loss
	lda #$22
	sta $D020
	sta $D021
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
	sta temp
	sta temp+1
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
	inc temp
	iny
	jmp @loop
@unrevealed:
	inc temp+1
	iny
	jmp @loop
@end:
	lda temp+1
	cmp #0
	bne @return
	lda temp
	cmp #MINES
	bne @return
	lda #1
	sta game_over
	lda $D015
	and #$FC
	sta $D015
	lda #$55
	sta $D020
	sta $D021
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

inf:	
	nop
	jmp inf
	
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

left_click_cell:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr), y
	and #$40
	beq left_click_cell_recursive
	jsr click_surrounding
	
left_click_cell_recursive:
	jsr set_cells_ptr_to_cursor
	ldy #0
	lda (cells_ptr), y
	and #$40
	beq @unrevealed
	rts
@unrevealed:
click_all_surrounding:
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
	jsr left_click_cell_recursive
	pla
	sta line_of_three
	inc cursor_x
@middle_col:
	lda line_of_three
	pha
	jsr left_click_cell_recursive
	pla
	sta line_of_three
	lda cursor_x
	cmp #(X_RANGE-1)
	beq @after_last_col
	inc cursor_x
	lda line_of_three
	pha
	jsr left_click_cell_recursive
	pla
	sta line_of_three
	dec cursor_x
@after_last_col:
	inc cursor_y
	inc line_of_three
	jmp @check_row
	
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
	
click_surrounding:
	lda #0
	sta temp
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
	cmp temp
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
	jsr left_click_cell_recursive
	pla
	sta line_of_three
	inc cursor_x
@middle_col:
	lda line_of_three
	pha
	jsr left_click_cell_recursive
	pla
	sta line_of_three
	lda cursor_x
	cmp #(X_RANGE-1)
	beq @after_last_col
	inc cursor_x
	lda line_of_three
	pha
	jsr left_click_cell_recursive
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
	cmp temp
	bne @return
	jsr click_all_surrounding
@return:
	rts
	
check_flag:
	ldy #0
	lda (cells_ptr), y
	and #$20
	bne @flagged
	rts
@flagged:
	inc temp
	rts

mines_placed: 
.byte 0

randomize_board:
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
	jmp randomize_board
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
	stx temp
	lda cells_ptr
	clc
	adc temp
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
	jmp randomize_board
	
	
inc_mine_count:
	lda (cells_ptr),y
	tax
	inx
	txa
	sta (cells_ptr),y
	rts
	
line_of_three:
.byte 0
count_adjacent:
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
	
	
current_color:
.byte 0

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

cells_array:
