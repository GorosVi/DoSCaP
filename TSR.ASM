; Write	framebuffer content to file on a disk
; when CTRL/S pressed. (screen mode - text)
; Exit when CTRL/X pressed.
CODE SEGMENT

ASSUME CS:CODE,	DS:CODE, SS:CODE
;org 100h

sig	DQ 0F30F88AC7D4842F2h ;Signature

fhdl	DW 0DBDBh

fname	DB 'screen.dmp', 00h

PRINT MACRO adr
LOCAL PrintRepeat, PrintBreak
	pushf
	push ES	DI SI AX
	; lods : AX <= [DS:SI]
	lea SI,adr
	; stos : AX => [ES:DI]
	push 0B800h
	xor DI,DI
	pop ES
	mov AH,0Ch
	; Write	to 0 page of video memory
PrintRepeat:
	lodsb
	cmp AL,00h
	je  PrintBreak
	stosw
	jmp PrintRepeat
PrintBreak:
	xor AX,AX
	; Wait key - BIOS Int 16h @ 00h
	; NONE
	; OUT -------------------------
	; AL : ASCII keycode
	; AH : scancode, EASCII	when AL	== 0
	int 16h
	pop AX SI DI ES
	popf
ENDM

KbdHook:
	nop
	nop
	jmp KbdHook


START:	mov AX,	CS
	mov DS,	AX
	mov ES,	AX

	print msg


	; Execution termiating
	mov AX,	4C00h
	int 21h

EmergExit:
	PRINT emex
	mov AX,	4C01h
	int 21h

msg	DB 'Message!                          ',0
emex	DB 'Fatal error, process terminated.  ',0
generr	DB 'Generic Error!                    ',0

CODE ENDS
END START
