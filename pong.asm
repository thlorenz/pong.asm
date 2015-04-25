; vim: ft=nasm

; summary:  http://ascii-table.com/ansi-escape-sequences.php
; elaborate: http://ascii-table.com/ansi-escape-sequences-vt-100.php

%include "./lib/signals.mac"
;%include "./lib/log.mac"

extern ansi_cursor_hide
extern ansi_cursor_position
extern ansi_cursor_show
extern ansi_term_clear

extern sys_nanosleep
extern sys_signal
extern sys_write_stdout

; DRAW is turned off by default to allow debugging.
; To draw do:   rm -f pong pong.o && PONG_DRAW=1 make && ./pong
; To debug do:  rm -f pong pong.o && make && gdb pong
%ifenv PONG_DRAW
%define DRAW
%endif

%define ms        1000000
%define idle_ms   30
%define wall_ms   1
%define ratio     2
%define width     64 * ratio
%define height    40
%define left_x    5
%define top_y     5
%define right_x   left_x + width
%define bottom_y  top_y + height

section .text

cleanup:
  call  ansi_cursor_show
exit:
  mov   eax, 1
  mov   ebx, 0
  int   80H

idle:
  push  ecx
  xor   ecx, ecx      ; slow down the loop a bit
  call  sys_nanosleep
  pop   ecx
  ret


; draw_walls
; draws bottom and top row walls
; it does so with slight delay for that true arcade style ;)
section .data
  hitleft: db "Hit left wall"
    .len:  equ $-hitleft
  hitright: db "Hit right wall"
    .len:  equ $-hitright
  hittop: db "Hit top wall"
    .len:  equ $-hittop
  hitbottom: db "Hit bottom wall"
    .len:  equ $-hitbottom
section .text

section .data
  horizontal_top_brick   : db '▄'
    .len                   equ $-horizontal_top_brick
  horizontal_bottom_brick: db '▀'
    .len                   equ $-horizontal_bottom_brick
section .text
draw_walls:
  xor   eax, eax
  mov   ah, left_x - 1                 ; top row
  mov   al, top_y - 1

.draw_row_left_to_right:
  mov   edx, wall_ms * ms
  call  idle

  inc   ah
  call  ansi_cursor_position
  mov   ecx, horizontal_top_brick
  mov   edx, horizontal_top_brick.len
  call  sys_write_stdout

  cmp   ah, right_x
  jne   .draw_row_left_to_right


  mov   al, bottom_y + 1               ; bottom row

.draw_row_right_to_left:
  mov   edx, wall_ms * ms
  call  idle

  dec   ah
  call  ansi_cursor_position
  mov   ecx, horizontal_bottom_brick
  mov   edx, horizontal_bottom_brick.len
  call  sys_write_stdout

  cmp   ah, left_x
  jne   .draw_row_right_to_left

  ret

; draws left/right paddle around the given center
; center of paddle in ah:al = x:y
; modifies: ecx
section .data
  paddle_block: db '▓'
    .len        equ $-paddle_block
section .text
draw_left_paddle:
  xor   eax, eax          ; load current position
  mov   esi, left_paddle
  lodsw
  jmp   draw_paddle

draw_right_paddle:
  xor   eax, eax          ; load current position
  mov   esi, right_paddle
  lodsw

draw_paddle:
  mov   edx, paddle_block.len
  mov   ecx, paddle_block 
  xor   ebx, ebx
  mov   bl, al            ; bl marks lower paddle end 
  add   bl, 3
  sub   al, 2             ; start drawing at top of paddle
.loop:
  call  ansi_cursor_position
  call  sys_write_stdout
  inc   al
  cmp   bl, al
  jne   .loop

  ret


; Determines which labels to jmp to next time ball's speed is applied to its position.
; Stores the appropriate function pointer in ball_dir.x and ball_dir.y respectively.
; This is then used to jmp in @see position_ball.
; modifies eax, ebx, esi
adjust_direction:
  xor   eax, eax                                  ; load current position
  mov   esi, ball_pos
  lodsw
  mov   ebx, eax                                  ; and copy into ebx

.hit_left_wall?:                                  ; if we hit left wall fly to the right
  cmp   bh, left_x
  jne   .hit_right_wall?

  mov   eax, position_ball.right
  mov   edi, ball_dir.x
  stosd
  jmp   .hit_bottom_wall?

.hit_right_wall?:                                 ; if we hit right wall fly to the left
  cmp   bh, right_x
  jne   .hit_bottom_wall?

  mov   eax, position_ball.left
  mov   edi, ball_dir.x
  stosd
  mov   dword [ ball_dir.x ], position_ball.left  ; hit right

.hit_bottom_wall?:                                ; if we hit bottom wall fly up
  cmp   bl, bottom_y
  jne   .hit_top_wall?

  mov   eax, position_ball.up
  mov   edi, ball_dir.y
  stosd
  jmp   .done

.hit_top_wall?:                                   ; if we hit top wall fly down
  cmp   bl, top_y
  jne   .done

  mov   eax, position_ball.down
  mov   edi, ball_dir.y
  stosd

.done:
  ret

section .data
  positioning: db "Positioning Ball",0
section .text

; Applies ball speed vector (ball_speed) to its position (ball_pos).
; Either adds or substracts the magnitudes of the speed vector depending on
; which jmp address was stored in ball_dir by adjust_direction.
; Thus this simulates the direction of the vector's magnitude in an
; unsigned number world.
; modifies: ebx, esi, edi
position_ball:
  cld
  xor   eax, eax          ; load current position
  mov   esi, ball_pos
  lodsw                   ; ball_speed is right after ball_pos in memory, so esi now points at it

  mov   ebx, eax          ; load current speed
  lodsw
  xchg  eax, ebx

  jmp   [ ball_dir.x ]    ; move ball right or left depending on its direction
.right:
  add   ah, bh
  jmp   .x_done
.left:
  sub   ah, bh

.x_done:
  jmp   [ ball_dir.y ]    ; move ball up or down depending on its direction
.down:
  add   al, bl
  jmp   .done
.up:
  sub   al, bl

.done:
  mov   edi, ball_pos
  stosw

  ret

global _start
_start:
  nop

  mov   ecx, cleanup      ; ensure we get our cursor back
  mov   ebx, SIGINT       ; no matter how we exit
  call  sys_signal
  mov   ebx, SIGTERM
  call  sys_signal
  mov   ebx, SIGHUP
  call  sys_signal

%ifdef DRAW
  call  ansi_cursor_hide
  call  ansi_term_clear
  call  draw_walls
%else
section .data
  msg: db "Running in debug mode, please run: 'rm -f pong pong.o && PONG_DRAW=1 make && ./pong', in order to see the ball ;)", 10
  .len equ $-msg
section .text
  mov   ecx, msg
  mov   edx, msg.len
  call  sys_write_stdout
%endif

  cld
  mov   edi, ball_dir             ; initial ball direction right x down
  mov   eax, position_ball.down
  stosd
  mov   eax, position_ball.right
  stosd

%ifdef DRAW
  call  draw_left_paddle
  call  draw_right_paddle
%endif

game_loop:
  call  adjust_direction
  call  position_ball
%ifdef DRAW
  ; draw ball
  call  ansi_cursor_position

  mov   ecx, ball
  mov   edx, ball.len
  call  sys_write_stdout
  mov   edx, idle_ms * ms
  call  idle

  ; clear ball
  call  ansi_cursor_position

  mov   ecx, space
  mov   edx, space.len
  call  sys_write_stdout

%endif
  jmp   game_loop


section .data
;  log_text
  ball: db "•"
  .len  equ $-ball
%ifenv PONG_TRAIL   ; optionally follow the ball by a trail
  space: db '.'
%else
  space: db ' '
%endif
  .len  equ $-space

section .data
  ball_pos:                         ; little endian, allow loading into ax in one shot
        .y: db top_y + (height / 2) ; al
        .x: db left_x + (width / 2) ; ah
  ball_speed:
        .y: db 1
        .x: db 1
  left_paddle:                      ; paddle positions
        .y: db top_y + (height / 2) ; al
        .x: db left_x - 1           ; ah
  right_paddle:
        .y: db top_y + (height / 2 ); al
        .x: db right_x + 1          ; ah
section .bss
  ball_dir:         ; addresses of labels to jmp to when applying speed vector to position
        .y: resd 1  ; position_ball.up   or position_ball.down
        .x: resd 1  ; position_ball.left or position_ball.right
section .text
