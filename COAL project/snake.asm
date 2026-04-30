.386
.model flat, stdcall
option casemap:none

include Irvine32.inc
includelib Irvine32.lib

BOARD_W  EQU 30
BOARD_H  EQU 20
MAXLEN   EQU 200

.data
snakeX      BYTE MAXLEN DUP(0)
snakeY      BYTE MAXLEN DUP(0)
snakeLen    DWORD 3
snakeDir    BYTE 1
nextDir     BYTE 1
foodX       BYTE 0
foodY       BYTE 0
score       DWORD 0
gameOver    BYTE 0
tailX       BYTE 0
tailY       BYTE 0
oldLen      DWORD 0
msgGameOver  BYTE "Game Over. Press any key to exit.",0
msgWon       BYTE "You Won! Press any key to exit.",0
msgScore     BYTE "Score: ",0

.code
main PROC
    call Randomize
    call InitGame

main_loop:
    call ReadInput
    cmp BYTE PTR [gameOver], 0
    jne quit_game

    call UpdateSnake
    cmp BYTE PTR [gameOver], 0
    jne quit_game

    cmp DWORD PTR [score], 100
    jl not_won
    mov gameOver, 1

not_won:
    call DrawFrame
    mov eax, 200
    call Delay
    jmp main_loop

quit_game:
    call Clrscr
    cmp DWORD PTR [score], 100
    jl show_game_over
    mov edx, OFFSET msgWon
    jmp show_message

show_game_over:
    mov edx, OFFSET msgGameOver

show_message:
    call WriteString
    call Crlf
    call ReadChar
    invoke ExitProcess, 0
main ENDP

InitGame PROC
    push esi

    call Clrscr

    mov eax, BOARD_W / 2
    mov BYTE PTR [snakeX], al
    mov eax, BOARD_W / 2 - 1
    mov BYTE PTR [snakeX + 1], al
    mov eax, BOARD_W / 2 - 2
    mov BYTE PTR [snakeX + 2], al

    mov eax, BOARD_H / 2
    mov BYTE PTR [snakeY], al
    mov BYTE PTR [snakeY + 1], al
    mov BYTE PTR [snakeY + 2], al

    mov snakeLen, 3
    mov snakeDir, 1
    mov nextDir, 1
    mov score, 0
    mov gameOver, 0

    call SpawnFood
    call DrawFrame

    pop esi
    ret
InitGame ENDP

ReadInput PROC
    push eax
    push ebx

    call ReadKey
    jz input_done

    mov bl, al
    mov bh, ah

    cmp bl, 'q'
    je input_quit
    cmp bl, 'Q'
    je input_quit

    cmp bl, 'w'
    je try_up
    cmp bl, 'W'
    je try_up
    cmp bh, 48h
    je try_up

    cmp bl, 's'
    je try_down
    cmp bl, 'S'
    je try_down
    cmp bh, 50h
    je try_down

    cmp bl, 'a'
    je try_left
    cmp bl, 'A'
    je try_left
    cmp bh, 4Bh
    je try_left

    cmp bl, 'd'
    je try_right
    cmp bl, 'D'
    je try_right
    cmp bh, 4Dh
    je try_right

    jmp input_done

try_up:
    cmp snakeDir, 2
    je input_done
    mov nextDir, 0
    jmp input_done

try_down:
    cmp snakeDir, 0
    je input_done
    mov nextDir, 2
    jmp input_done

try_left:
    cmp snakeDir, 1
    je input_done
    mov nextDir, 3
    jmp input_done

try_right:
    cmp snakeDir, 3
    je input_done
    mov nextDir, 1
    jmp input_done

input_quit:
    mov gameOver, 1

input_done:
    pop ebx
    pop eax
    ret
ReadInput ENDP

UpdateSnake PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov eax, DWORD PTR [snakeLen]
    mov oldLen, eax

    mov ecx, eax
    dec ecx
    mov esi, ecx
    mov al, [snakeX + esi]
    mov tailX, al
    mov al, [snakeY + esi]
    mov tailY, al

shift_loop:
    cmp ecx, 0
    jle move_head
    mov esi, ecx
    dec esi
    mov al, [snakeX + esi]
    mov [snakeX + ecx], al
    mov al, [snakeY + esi]
    mov [snakeY + ecx], al
    dec ecx
    jmp shift_loop

move_head:
    mov al, nextDir
    mov snakeDir, al

    mov al, [snakeX]
    mov bl, [snakeY]

    cmp snakeDir, 0
    jne not_up
    dec bl
    jmp head_done
not_up:
    cmp snakeDir, 2
    jne not_down
    inc bl
    jmp head_done
not_down:
    cmp snakeDir, 3
    jne not_left
    dec al
    jmp head_done
not_left:
    inc al

head_done:
    cmp al, 1
    jb dead
    cmp al, BOARD_W
    ja dead
    cmp bl, 1
    jb dead
    cmp bl, BOARD_H
    ja dead

    ; preserve head coordinates in DL/DH to avoid clobbering
    mov edx, 0
    mov dl, al        ; head X
    mov dh, bl        ; head Y

    mov ecx, oldLen
    mov esi, 1
    ; tail index is oldLen-1
    mov ebx, ecx
    dec ebx
self_check:
    cmp esi, ecx
    jge store_head
    mov al, [snakeX + esi]
    cmp al, dl        ; compare segment X with head X
    jne self_next
    mov al, [snakeY + esi]
    cmp al, dh        ; compare segment Y with head Y
    jne self_next
    ; matched a segment - if it's the old tail index, ignore
    cmp esi, ebx
    je self_next
    ; otherwise it's a real self-collision
    mov gameOver, 1
    jmp no_food
self_next:
    inc esi
    jmp self_check

store_head:
    mov [snakeX], dl
    mov [snakeY], dh

    ; Compare preserved head coords (dl/dh) with food
    cmp dl, BYTE PTR [foodX]
    jne no_food
    cmp dh, BYTE PTR [foodY]
    jne no_food

    mov eax, oldLen
    mov ecx, eax
    mov al, tailX
    mov [snakeX + ecx], al
    mov al, tailY
    mov [snakeY + ecx], al
    inc DWORD PTR [snakeLen]
    add DWORD PTR [score], 10
    call SpawnFood

no_food:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

dead:
    mov gameOver, 1
    jmp no_food
UpdateSnake ENDP

SpawnFood PROC
    push eax
    push ecx
    push esi
    push ebx

    xor ebx, ebx

spawn_retry:
    mov eax, BOARD_W
    call RandomRange
    inc eax
    mov foodX, al

    mov eax, BOARD_H
    call RandomRange
    inc eax
    mov foodY, al

    mov ecx, DWORD PTR [snakeLen]
    xor esi, esi
check_overlap:
    cmp esi, ecx
    jge spawn_ok
    mov al, [snakeX + esi]
    cmp al, BYTE PTR [foodX]
    jne next_segment
    mov al, [snakeY + esi]
    cmp al, BYTE PTR [foodY]
    je check_retry_limit
next_segment:
    inc esi
    jmp check_overlap

check_retry_limit:
    inc ebx
    cmp ebx, 50
    jl spawn_retry

spawn_ok:
    pop ebx
    pop esi
    pop ecx
    pop eax
    ret
SpawnFood ENDP

DrawFrame PROC
    call Clrscr
    call DrawBorder
    call DrawFood
    call DrawSnake
    call DrawScore
    ret
DrawFrame ENDP

DrawBorder PROC
    push eax
    push ecx
    push edx

    mov dh, 0
    mov dl, 0
    mov ecx, BOARD_W + 2
border_top:
    call Gotoxy
    mov al, '#'
    call WriteChar
    inc dl
    loop border_top

    mov dh, BOARD_H + 1
    mov dl, 0
    mov ecx, BOARD_W + 2
border_bottom:
    call Gotoxy
    mov al, '#'
    call WriteChar
    inc dl
    loop border_bottom

    mov ecx, BOARD_H
    mov dh, 1
border_sides:
    mov dl, 0
    call Gotoxy
    mov al, '#'
    call WriteChar
    mov dl, BOARD_W + 1
    call Gotoxy
    mov al, '#'
    call WriteChar
    inc dh
    loop border_sides

    pop edx
    pop ecx
    pop eax
    ret
DrawBorder ENDP

DrawFood PROC
    push eax
    push edx

    mov dh, BYTE PTR [foodY]
    mov dl, BYTE PTR [foodX]
    call Gotoxy
    mov al, '*'
    call WriteChar

    pop edx
    pop eax
    ret
DrawFood ENDP

DrawSnake PROC
    push eax
    push ecx
    push edx
    push esi

    mov ecx, DWORD PTR [snakeLen]
    xor esi, esi
snake_draw_loop:
    cmp esi, ecx
    jge snake_draw_done

    mov dh, [snakeY + esi]
    mov dl, [snakeX + esi]
    call Gotoxy

    cmp esi, 0
    jne body_piece
    mov al, 'O'
    jmp print_piece
body_piece:
    mov al, 'o'
print_piece:
    call WriteChar

    inc esi
    jmp snake_draw_loop

snake_draw_done:
    pop esi
    pop edx
    pop ecx
    pop eax
    ret
DrawSnake ENDP

DrawScore PROC
    push eax
    push ecx
    push edx

    ; Position cursor at fixed location - row 22 (below board and borders)
    mov dh, 22              ; Y = 22 (below the board)
    mov dl, 0               ; X = 0 (leftmost column)
    call Gotoxy
    
    ; Display score label
    mov edx, OFFSET msgScore
    call WriteString
    
    ; Display score value
    mov eax, DWORD PTR [score]
    call WriteDec

    pop edx
    pop ecx
    pop eax
    ret
DrawScore ENDP

END main
