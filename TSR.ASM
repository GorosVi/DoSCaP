; Write	framebuffer content to file on a disk
; when CTRL/S pressed. (screen mode - text)
; Exit when CTRL/X pressed.
CODE SEGMENT

ASSUME CS:CODE,	DS:CODE, SS:CODE

fhdl	DW 0DBDBh ; File handle

fname	DB 'screen.dmp', 00h

;fbuffer DB 80*25 dup (0DBh)

msg	DB 'Message!                          ',0
generr	DB 'Generic Error!                    ',0

PRINT MACRO adr
	pushf
	push SI
	lea SI,	adr
	call PrintOuts
	pop SI
	popf
ENDM


PipelineWhenNotCtrl PROC ; use near call!
	mov AH,	02h
	; Get Keyboard Flags - BIOS int	16h @ 02h
	; NONE
	; OUT -----------------------------------
	; AL : keyboard	flags state
	int 16h
	mov AH,AL
	test AL, 04h ; 1 when CTRL was held
	;jz CancelExecution
	test AH, 0Ch ; 0 when ALT & Shift's was released
	;jnz CancelExecution
	; Continue when	only CTRL is pressed
	ret
CancelExecution:
	inc SP ; return	address	clear
	inc SP
	jmp PipelineToOldHandle
ENDP

sig	DW 0F3F2h ; Signature
KbdHook:;Int 9h	- key press
	print generr
	jmp PipelineToOldHandle
	push AX	DS
	in  AL,	60h

	cmp AL,	1Fh ; 'S'
	je  SavePicHook
	cmp AL,	2Dh ; 'X'
	je  ExitResidentHook
	pop DS AX
	jmp PipelineToOldHandle

SavePicHook:
	;call PipelineWhenNotCtrl


	jmp BreakExecution

ExitResidentHook:
	;call PipelineWhenNotCtrl


	;jmp BreakExecution

BreakExecution:
	pop DS AX
	;print MSG
	iret



PipelineToOldHandle:
int9h:	DB 0EAh	  ; Jmp	far opcode
i9old	DW 0DBDBh ; BX
	DW 0DBDBh ; ES

	cli
	hlt

PrintOuts PROC
	; SI - address of ASCII	string
	push AX	ES DI DS
	; lods : AX <= [DS:SI]
	push CODE
	pop DS
	; stos : AX => [ES:DI]
	push 0B800h
	xor DI,	DI
	pop ES
	mov AH,	0Ch
	; Write	to 0 page of video memory
PrintRepeat:
	lodsb
	cmp AL,	00h
	je  PrintBreak
	stosw
	jmp PrintRepeat
PrintBreak:
	;xor AX, AX
	; Wait key - BIOS Int 16h @ 00h
	; NONE
	; OUT -------------------------
	; AL : ASCII keycode
	; AH : scancode, EASCII	when AL	== 0
	;int 16h
	pop DS DI ES AX
	ret
ENDP

DOSPRINT MACRO adr
	push DX	DS
	push CODE
	pop DS
	lea DX,	adr
	mov AX,	0900h
	int 21h
	pop DS DX
ENDM

START:	mov AX,	CS
	mov DS,	AX
	;mov ES, AX

	cli
	;push ES
	mov AH,	35h
	mov AL,	09h
	; Get  IV address - DOS	35h
	; AL : IV number
	; OUT ---------------------
	; ES:BX	: IV address
	int 21h
	; Exit when already loaded
	mov AX,	ES:[BX-2]
	;cmp AX, CS:sig
	jmp ContinLoad
	;pop ES
	jmp EmergExit
 ContinLoad:
	mov i9old,   BX
	mov i9old+2, ES
	;pop ES

	lea DX,	KbdHook
	mov AH,	25h
	mov AL,	09h
	; Set  IV address - DOS	25h
	; AL : IV number
	; DS:DX	: Interrupt handler
	; OUT ---------------------
	; NONE
	int 21h
	sti


	lea BX,	START
	; Terminate and	stay resident -	DOS int	27h
	; DX : 1 + offset of last TSR byte
	; OUT ----------------------------
	; NONE
	int 27h

EmergExit:
	DOSPRINT emex
	mov AX,	4C01h
	int 21h
emex	DB 'Fatal error, process terminated. $',0

EndCode:
CODE ENDS
END START
