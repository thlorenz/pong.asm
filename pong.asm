; vim: ft=nasm
global _start

extern hex2decimal

section .text

sys_write_stdout:
  push  eax
  push  ebx

  mov   eax, 4
  mov   ebx, 1
  int   80h

  pop   ebx
  pop   eax
  ret

; --------------------------------------------------------------
; ansi_clear_term
;     clears the terminal
;
; CALLS: sys_write_stdout
; --------------------------------------------------------------
section .data
  ansi_clear: db 27,'[2J'
  ansi_clear_len equ $-ansi_clear

ansi_clear_term:

  mov   ecx, ansi_clear
  mov   edx, ansi_clear_len
  call sys_write_stdout
  ret

; --------------------------------------------------------------
; ansi_position_cursor
;     moves cursor to given position
;
; ARGS:
;   ah: row
;   al: column
; CALLS: sys_write_stdout
; --------------------------------------------------------------
section .data
  ansi         : db 27,"["
  cursor_x     : db '000;'
  cursor_y     : db '000H'
  ansi_len     equ $-ansi

ansi_position_cursor:
  ; poke coordinates into positions
  push  ebx
  push  edx

  push  esi

  mov esi, ansi

  ; clear high part of positions
  mov   word [ cursor_x ], '00'
  mov   word [ cursor_y ], '00'

  mov   ebx, eax
  shr   eax, 8              ; isolate ah

  mov esi, cursor_x + 3     ; hex2decimal stores right before esi
  call hex2decimal

  mov   eax, ebx
  and   eax, 00ffh          ; isolate al

  mov esi, cursor_y + 3
  call hex2decimal

  mov esi, ansi

  ; sys_write to stdout
  mov   ecx, ansi
  mov   edx, ansi_len
  call sys_write_stdout

  pop   esi
  pop   edx
  pop   ebx
  ret


_start:
  nop

  call ansi_clear_term

  mov ah, 10
  mov al, 30

  call ansi_position_cursor

  mov   ecx, x
  mov   edx, x_len
  call sys_write_stdout


.exit:
  mov eax, 1
  mov ebx, 0
  int 80H

section .data
  x:    db 'x'
  x_len equ $-x
