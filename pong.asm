; vim: ft=nasm

; summary:  http://ascii-table.com/ansi-escape-sequences.php
; elaborate: http://ascii-table.com/ansi-escape-sequences-vt-100.php

%include "./lib/signals.mac"
%include "./lib/log.mac"

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

%define ms 1000000
%define ratio 2
%define width 64 * ratio
%define height 40

section .text

cleanup:
  call  ansi_cursor_show
exit:
  mov   eax, 1
  mov   ebx, 0
  int   80H

idle:
  push  ecx
  push  edx
  xor   ecx, ecx      ; slow down the loop a bit
  mov   edx, 40 * ms
  call  sys_nanosleep
  pop   edx
  pop   ecx
  ret


; Determines which labels to jmp to next time ball's speed is applied to its position.
; Stores the appropriate function pointer in ball_dir.x and ball_dir.y respectively.
; This is then used to jmp in @see position_ball.
section .data
  hitleft: db "Hit left wall"
    .len:  equ $- hitleft
  hitright: db "Hit right wall"
    .len:  equ $- hitright
  hittop: db "Hit top wall"
    .len:  equ $- hittop
  hitbottom: db "Hit bottom wall"
    .len:  equ $- hitbottom
section .text
adjust_direction:
  push  eax
  push  ebx

  xor   eax, eax          ; load current position
  mov   ax, [ ball_pos ]

  mov   bx, ax

.hit_left_wall?:                                  ; if we hit left wall fly to the right
  cmp   al, 0
  jne   .hit_right_wall?
  mov   dword [ ball_dir.x ], position_ball.right ; hit left
  log_debug hitleft, hitleft.len
  log_eax_dec
  jmp   .hit_bottom_wall?

.hit_right_wall?:                                 ; if we hit right wall fly to the left
  cmp   bl, width
  jne   .hit_bottom_wall?
  log_debug hitright, hitright.len
  log_eax_dec
  mov   dword [ ball_dir.x ], position_ball.left  ; hit right

.hit_bottom_wall?:                                ; if we hit bottom wall fly up
  cmp   ah, height
  jne   .hit_top_wall?
  log_debug hitbottom, hitbottom.len
  log_eax_dec
  mov   dword [ ball_dir.y ], position_ball.up    ; hit bottom
  jmp   .done

.hit_top_wall?:                                   ; if we hit top wall fly down
  cmp   bh, 0
  jne   .done
  log_debug hittop, hittop.len
  log_eax_dec
  mov   dword [ ball_dir.y ], position_ball.down  ; hit top

.done:
  pop ebx
  pop eax
  ret


section .data
  positioning: db "Positioning Ball",0
section .text

; Applies ball speed vector (ball_speed) to its position (ball_pos).
; Either adds or substracts the magnitudes of the speed vector depending on
; which jmp address was stored in ball_dir by adjust_direction.
; Thus this simulates the direction of the vector's magnitude in an
; unsigned number world.
position_ball:
  push   ebx
  push   ecx

  xor   eax, eax          ; load current position
  mov   ax, [ ball_pos ]

  xor   ebx, ebx          ; load current speed
  mov   bx, [ ball_speed ]

  jmp   [ ball_dir.x ]    ; move ball right or left depending on its direction
.right:
  add   al, bl
  jmp   .x_done
.left:
  sub   al, bl

.x_done:
  jmp   [ ball_dir.y ]    ; move ball up or down depending on its direction
.down:
  add   ah, bh
  jmp   .done
.up:
  sub   ah, bh

.done:
  mov   word [ ball_pos ], ax

  pop   ecx
  pop   ebx
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
%else
section .data
  msg: db "Running in debug mode, please run: 'rm -f pong pong.o && PONG_DRAW=1 make && ./pong', in order to see the ball ;)", 10
  .len equ $-msg
section .text
  mov   ecx, msg
  mov   edx, msg.len
  call  sys_write_stdout
%endif


  mov  byte [ ball_pos.x ], width / 2               ; initial ball position
  mov  byte [ ball_pos.y ], height / 2
  mov  byte [ ball_speed.x ], 1                     ; initial ball speed
  mov  byte [ ball_speed.y ], 1
  mov  dword [ ball_dir.x ], position_ball.right    ; initial ball direction
  mov  dword [ ball_dir.y ], position_ball.down

game_loop:
  call  adjust_direction
  call  position_ball
%ifdef DRAW
  ; draw ball
  call  ansi_cursor_position

  mov   ecx, ball
  mov   edx, ball.len
  call  sys_write_stdout
  call  idle

  ; clear ball
  call  ansi_cursor_position

  mov   ecx, space
  mov   edx, space.len
  call  sys_write_stdout


%endif
  jmp   game_loop


section .data
  log_text
  ball: db "•"
  .len  equ $-ball
%ifenv PONG_TRAIL   ; optionally follow the ball by a trail
  space: db '.'
%else
  space: db ' '
%endif
  .len  equ $-space



section .bss

  ball_pos:
        .x: resb 1
        .y: resb 1
  ball_speed:
        .x: resb 1
        .y: resb 1
  ball_dir:         ; addresses of labels to jmp to when applying speed vector to position
        .x: resd 1  ; position_ball.left or position_ball.right
        .y: resd 1  ; position_ball.up   or position_ball.down

section .text
