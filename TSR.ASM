; Write	framebuffer content to file on a disk
; when CTRL/S pressed. (screen mode - text)
; Exit when CTRL/X pressed.
CODE SEGMENT

ASSUME CS:CODE,	DS:CODE

firstbyte:

fhdl	DW 0DBDBh ; File handle

fname	DB 'screen.dmp', 0

asyncst	DB 000h
;fbuffer DB 80*25 dup (0DBh)
fbuffer	DB 000h

msg	DB 'Message!                                    ',0
generr	DB 'Generic Error!                              ',0

unkmode	DB 'Unknown video mode, cannot take screenshot! ',0
imgsved	DB 'Screenshot succesfully taken.               ',0
bufbusy	DB 'Cannot take screenshot, buffer not empty!   ',0
removed	DB 'TSR succefully unloaded from memory.        ',0
blremov	DB 'Attempt to unload TSR failed!               ',0
unremov	DB 'Error in memory unallocation!               ',0

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
	pushf
	push AX	DS

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

PipelineToOldHandle:
	pop DS AX
	popf
int9h:	DB 0EAh	  ; Jmp	far opcode
i9old	DW 0DBDBh ; BX
	DW 0DBDBh ; ES

SavePicHook:
	;call StoreScreenToMem
	jmp PipelineToOldHandle


ExitResidentHook:
	push ES

	push CODE
	pop DS
	xor AX,AX
	mov ES,AX

	cmp word ptr ES:[9*2*2], offset	KbdHook
	jne IVBlocked
	cmp word ptr ES:[9*2*2+2], CODE
	je  CanUnassignIV
IVBlocked:
	pop ES
	PRINT blremov
	jmp PipelineToOldHandle

CanUnassignIV:
	cli
	;RestoreIVs
	mov AX,	i9old
	mov word ptr ES:[9*2*2], AX
	mov AX,	i9old+2
	mov word ptr ES:[9*2*2+2], AX
	sti

	;cli
	;clc
	;RemoveEnvSeg
	;mov ES, CS:2Ch	; environment seg
	;mov AH, 49h
	; [RE-ENTERABLE]
	; Release memory block - DOS 49h
	; ES : segment of releasing block
	; OUT ---------------------------
	; AX : Error code when CF == 1
	;int 21h
	;pushf

	;cli
	; RemoveCodeSeg:

	push CS
	pop ES

	mov AH,	49h
	; Release memory block - DOS 49h
	int 21h

	;sti
	;cli
	;mov ax,cs:[2ch]
	;dec ax
	;mov ES,AX
	;mov ES:1, word	ptr 0

	;mov AX,CS
	;dec AX
	;mov ES,AX
	;mov ES:1, word	ptr 0

	;sti

	pop ES
	;popf
	jc RemoveFails
	;popf
	;jc RemoveFails
	PRINT removed
	jmp PipelineToOldHandle

RemoveFails:
	PRINT unremov
	jmp PipelineToOldHandle


StoreScreenToMem PROC
	; At this time only 03h	video mode allowed
	push AX	BX

	mov AH,0Fh
	; Read current video mode
	; NONE
	; OUT ----------------------
	; AL : Current video mode ID
	; AH : Row length in symbols
	; BH : Active page number
	int 10h

	cmp AL,03h
	je vMode03
	; Unknown video	mode
	PRINT unkmode
	jmp ExitStorePic

vMode03:; 80x25	@ 16 text mode
	mov AX,80*25
	;jmp vModeEndCase

vModeEndCase:
	push CX	DI SI DS ES

	mov CX,AX ; CX - frame length
	mov BL,BH ; BH - active	page number
	xor BH,BH ; AX - frame offset
	mul BX

	; lods : AX <= [DS:SI]
	push 0B800h    ; Video memory segment
	pop DS
	mov SI,	AX     ; Page offset

	; stos : AX => [ES:DI]
	push CODE      ; Buffer	offset
	pop ES
	lea DI,	fbuffer

	; add saving picture size
StoreRepeat:
	lodsw
	stosb
	loop StoreRepeat
StoreBreak:
	pop ES DS SI DI	CX
	PRINT imgsved
ExitStorePic:
	pop BX AX
	ret
ENDP

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
	xor AX,AX
	mov ES,AX
	; Direct read IV from table
	mov BX,	word ptr ES:[9*2*2]
	mov ES,	word ptr ES:[9*2*2+2]

	; Exit when already loaded
	mov AX,	ES:[BX-2]
	cmp AX,	CS:[sig]
	jne ContinLoad

	sti
	DOSPRINT notinst
	jmp EmergExit


	; INDOS	state -	DOS 34h	[UNDOCUMENTED!]
	; NONE
	; OUT ---------------------------------
	; ES:BX	: address of DOS activity flag


 ContinLoad:
	mov i9old,   BX
	mov i9old+2, ES

	xor AX,	AX
	mov ES,	AX
	; Direct write IV to table
	mov word ptr ES:[9*2*2], offset	KbdHook
	mov word ptr ES:[9*2*2+2], CODE
	sti

	DOSPRINT wasinst

	;lea BX, START
	; Terminate and	stay resident -	DOS int	27h
	; DX : 1 + offset of last TSR byte
	; OUT ----------------------------
	; NONE
	;int 27h

	mov AX,	3100h
	mov DX,	(START - firstbyte + 10Fh)/16
	int 21h

EmergExit:
	mov AX,	4C01h
	int 21h

emex	DB 'Fatal error, process terminated. $',0

wasinst	DB 'TSR installed in memory. $',0
notinst	DB 'Error, TSR already loaded! $',0

EndCode:
CODE ENDS
END START
