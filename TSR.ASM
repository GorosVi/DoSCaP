; Write	framebuffer content to file on a disk
; when CTRL/S pressed. (screen mode - text)
; Exit when CTRL/X pressed.
CODE SEGMENT

ASSUME CS:CODE,	DS:CODE, SS:CODE

fhdl	DW 0DBDBh ; File handle

fname	DB 'screen.dmp', 00h

;fbuffer DB 80*25 dup (0DBh)

msg	DB 'Message!                          ',0
generr	DB 'G  ',0,'eneric Error!             ',0

PRINT MACRO adr
	pushf
	push SI
	lea SI,	adr
	call PrintOuts
	pop SI
	popf
ENDM

sig	DW 0F3F2h ; Signature
KbdHook:;Int 9h	- key press
	push AX	DS

	;mov AH, 02h
	; Get Keyboard Flags - BIOS int	16h @ 02h
	; NONE
	; OUT -----------------------------------
	; AL : keyboard	flags state
	;int 16h

	xor AX,	AX
	mov DS,	AX
	; Read keyboard	status byte from memory
	test byte ptr DS:[0417h], 04h ;	1 when CTRL was	held
	jz  PipelineToOldHandle
	test byte ptr DS:[0417h], 0Bh ;	0 when ALT & Shift's was released
	jnz PipelineToOldHandle
	; Continue when	only CTRL is pressed

	in  AL,	60h
	cmp AL,	1Fh ; 'S'
	je  SavePicHook
	cmp AL,	2Dh ; 'X'
	je  ExitResidentHook
	jmp PipelineToOldHandle

SavePicHook:
	print MSG
	jmp PipelineToOldHandle

ExitResidentHook:
	print GENERR
	;jmp PipelineToOldHandle

PipelineToOldHandle:
	pop DS AX
int9h:	DB 0EAh	  ; Jmp	far opcode
i9old	DW 0DBDBh ; BX
	DW 0DBDBh ; ES

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
	mov AH,	09h
	int 21h
	pop DS DX
ENDM

START:	mov AX,	CS
	mov DS,	AX

	cli
	;mov AH, 35h
	;mov AL, 09h
	; Get  IV address - DOS	35h
	; AL : IV number
	; OUT ---------------------
	; ES:BX	: IV address
	;int 21h

	xor AX,AX
	mov ES,AX
	; Direct read IV from table
	mov BX,ES:[9*2*2]
	mov ES,ES:[9*2*2+2]

	; Exit when already loaded
	mov AX,	ES:[BX-2]
	cmp AX,	CS:[sig]

	jne ContinLoad
	sti
	jmp EmergExit

 ContinLoad:
	mov i9old,   BX
	mov i9old+2, ES

	;lea DX, KbdHook
	;mov AH, 25h
	;mov AL, 09h
	; Set  IV address - DOS	25h
	; AL : IV number
	; DS:DX	: Interrupt handler
	; OUT ---------------------
	; NONE
	;int 21h

	xor AX,	AX
	mov ES,	AX
	; Direct write IV to table
	lea AX,	KbdHook
	mov ES:[9*2*2],	AX
	mov AX,	CODE
	mov ES:[9*2*2+2], AX

	sti

	DOSPRINT wasinst

	lea BX,	START
	; Terminate and	stay resident -	DOS int	27h
	; DX : 1 + offset of last TSR byte
	; OUT ----------------------------
	; NONE
	int 27h

EmergExit:
	nop
	nop
	nop
	DOSPRINT emex
	mov AX,	4C01h
	int 21h
emex	DB 'Fatal error, process terminated. $',0
wasinst	DB 'Installed in memory. $',0
notinst	DB 'Error, not installed in memory. $',0
EndCode:
CODE ENDS
END START
