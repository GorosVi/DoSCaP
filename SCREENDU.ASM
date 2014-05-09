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
	push AX
	push DX
	lea DX,	adr
	mov AH,	09h
	; Print	string - DOS 09h
	; DS:DX	- ASCII	input string
	; OUT ----------------------
	; NONE
	int 21h
	pop DX
	pop AX
ENDM

START:	mov AX,	CS
	mov DS,	AX
	mov ES,	AX
FileCreate:
	mov AH,	3Ch
	lea DX,	fname
	xor CX,	CX
	; Create file -	DOS 3Ch
	; DS:DX	: filename - ASCII string
	; CX : file attributes
	; OUT ----------------------
	; AX : error code if CF	== 1
	int 21h
	mov fhdl, AX
	; Error	when CF	== 1
	jnc FileCreated
	PRINT generr
	jmp EmergExit
FileCreated:

WriteScreenToFile:
	; At this time only first 4 video modes	are used

	mov AH,0Fh
	; Read current video mode
	; NONE
	; OUT ----------------------
	; AL : Current video mode ID
	; AH : Row length in symbols
	; BH : Active page number
	int 10h

	cmp AL,01h
	jbe vMode01
	cmp AL,03h
	jbe vMode23
	; Unknown video	mode
	PRINT generr
	jmp vMode23

vMode01:; 40x25	@ 16 text mode
	mov AX,40*25*2
	jmp vModeEndCase

vMode23:; 80x25	@ 16 text mode
	mov AX,80*25*2
	;jmp vModeEndCase

vModeEndCase:
	mov CX,AX ; CX - frame length
	mov BL,BH ; AX - frame offset
	xor BH,BH
	mul BX

WriteToFile:
	mov BX,	fhdl

	mov DX,	AX     ; Video page offset
	push DS
	push 0B800h    ; Video memory segment
	pop DS
		       ; Page size contains in CX
	mov AH,	40h
	; Write	to file	- DOS 40h
	; BX : file handle
	; CX : bytes to	write
	; DS:DX	: read buffer
	; OUT ----------------------
	; AL : writed bytes count
	; AX : error code if CF	== 1
	int 21h
	pop DS
	; Error	when CF	== 1 or	CX != AX - written symbols count
	jc  EmergExit
	cmp AX,CX
	jne EmergExit
FileClose:
	mov AH,	3Eh
	mov BX,	fhdl
	; Close	file - DOS 3Eh
	; BX : file handle
	; OUT ----------------------
	; AX : error code if CF	== 1
	int 21h
	; Error	when CF	== 1
	jnc FileClosed
	PRINT generr
	jmp EmergExit
FileClosed:
	; Return to DOS
	mov AX,	4C00h
	int 21h
EmergExit:
	PRINT emex
	mov AX,	4C01h
	int 21h
msg	DB 'Message! $'
emex	DB 'Process terminated. $'
generr	DB 'Generic Error! $'
;tmp	 DB 513	dup (0DBh)
CODE ENDS
END START
