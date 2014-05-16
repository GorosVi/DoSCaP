; Write	framebuffer content to file on a disk
; when CTRL/S pressed. (screen mode - text)
; Exit when CTRL/X pressed.

CODE SEGMENT
ASSUME CS:CODE,	DS:CODE

org 100h


START:	jmp ENTRYPOINT


unkmode	DB 'Unknown video mode, cannot take screenshot! ',0
imgstrd	DB 'Screenshot stored in memory.                ',0
imgsved	DB 'Screenshot succesfully taken.               ',0
bufbusy	DB 'Cannot take screenshot, buffer not empty!   ',0
removed	DB 'TSR succefully unloaded from memory.        ',0
blremov	DB 'Attempt to unload TSR failed, IV changed.   ',0
unremov	DB 'Error in memory unallocation!               ',0
fcrerr	DB 'Error when creating output file!            ',0
fwrerr	DB 'Error when writing to output file!          ',0
fclerr	DB 'Error when closing output file!             ',0

fhdl	DW 0DBDBh ; File handle
fname	DB 'screen_0.dmp', 0

asyncst	DB 000h	; Status flags
flength	DW 000h	; Actual framebuffer size
fbuffer	DB 80*25 dup (0DBh)


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

	; Read keyboard	status byte from memory	- INT 16h @ 02h	data
	xor AX,	AX
	mov DS,	AX

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
	;jmp PipelineToOldHandle


PipelineToOldHandle:
	pop DS AX
	popf
int9h:	DB 0EAh	  ; Jmp	far opcode
i9old	DW 0DBDBh ; BX
	DW 0DBDBh ; ES


SavePicHook:
	push CS
	pop DS
	; Image	stored in memory, but wasn't writed to disk.
	test asyncst,0FFh
	jnz PrevImageNotSaved

	call StoreScreenToMem
	jmp PipelineToOldHandle

PrevImageNotSaved:
	PRINT bufbusy
	jmp PipelineToOldHandle


ExitResidentHook:
	; DS value is 0000h

	mov AX,	CS
	; Check	IV's state - Keyboard Int 9h
	cmp word ptr DS:[09h*2*2], offset KbdHook
	jne IVBlocked
	cmp word ptr DS:[09h*2*2+2], AX
	jne IVBlocked

	; DOS time quantum Int 28h
	cmp word ptr DS:[28h*2*2], offset QuantumHook
	jne IVBlocked
	cmp word ptr DS:[28h*2*2+2], AX
	je  CanUnassignIV

IVBlocked:
	PRINT blremov
	jmp PipelineToOldHandle

CanUnassignIV:
	; DS value is 0000h
	cli

	;RestoreIVs - Keyboard Int 9h
	mov AX,	CS:i9old
	mov word ptr DS:[09h*2*2], AX
	mov AX,	CS:i9old+2
	mov word ptr DS:[09h*2*2+2], AX

	; DOS time quantum Int 28h
	mov AX,	CS:i28old
	mov word ptr DS:[28h*2*2], AX
	mov AX,	CS:i28old+2
	mov word ptr DS:[28h*2*2+2], AX

	push ES
	; Remove Environnement Section
	mov ES,	CS:2Ch ; Pointer in PSP
	mov AH,	49h
	; [RE-ENTERABLE]
	; Release memory block - DOS 49h
	; ES : segment of releasing block
	; OUT ---------------------------
	; AX : Error code when CF == 1
	int 21h
	pushf

	; RemoveCodeSeg:
	push CS
	pop ES
	mov AH,	49h
	; Release memory block - DOS 49h
	int 21h

	sti
	jc RemoveFails
	popf
	pop ES
	sti
	jc RemoveFailsNoFlags
	PRINT removed
	jmp PipelineToOldHandle

RemoveFails:
	popf
	pop ES
RemoveFailsNoFlags:
	PRINT unremov
	jmp PipelineToOldHandle


QuantumHook: ;Int 28h -	DOS Time quantum [UNDOCUMENTED]
	pushf

	test CS:asyncst, 01h
	jz PipelineProcessing

	push AX	BX CX DS
	push CS
	pop DS

FileCreate:
	lea DX,	fname
	xor CX,	CX

	mov AH,	3Ch
	; Create file -	DOS 3Ch
	; DS:DX	: filename - ASCII string
	; CX : file attributes
	; OUT ----------------------
	; AX : error code if CF	== 1
	int 21h
	mov fhdl, AX
	jnc FileCreated

	PRINT fcrerr
	jmp SaveExit

FileCreated:
WriteToFile:
	mov BX,	fhdl
	mov CX,	flength	; Actual frame size
	lea DX,	fbuffer	; Buffer offset

	mov AH,	40h
	; Write	to file	- DOS 40h
	; BX : file handle
	; CX : bytes to	write
	; DS:DX	: read buffer
	; OUT ----------------------
	; AX : writed bytes count
	; AX : error code if CF	== 1
	int 21h
	jnc  WriteEnd

WritingError:
	PRINT fwrerr
	jmp SaveExit

WriteEnd:; Error when CX != AX - written symbols count
	cmp AX,	CX
	jne WritingError

FileClose:
	mov BX,	fhdl

	mov AH,	3Eh
	; Close	file - DOS 3Eh
	; BX : file handle
	; OUT ----------------------
	; AX : error code if CF	== 1
	int 21h
	jnc FileClosed

	PRINT fclerr
	jmp SaveExit

FileClosed:
	and asyncst, 0FEh ; Clear busy flag
	PRINT imgsved

	; Filename scalng
	inc fname[7]
	cmp fname[7], '9'
	jng SaveExit
	mov fname[7], '0'

SaveExit:
	pop DS CX BX AX


PipelineProcessing:
	popf
int28h:	DB 0EAh	  ; Jmp	far opcode
i28old	DW 0DBDBh ; BX
	DW 0DBDBh ; ES


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
	mov flength, AX
	push CX	DI SI DS ES

	mov CX,	AX ; CX	- frame	length
	mov BL,	BH ; BH	- active page number
	xor BH,	BH ; AX	- frame	offset
	mul BX

	; Lods : AX <= [DS:SI]
	push 0B800h	; Video	memory segment
	pop DS
	mov SI,	AX	; Page offset

	; Stos : AX => [ES:DI]
	push CS
	pop ES
	lea DI,	fbuffer	; Buffer offset

StoreRepeat:
	lodsw
	stosb
	loop StoreRepeat

StoreBreak:
	pop ES DS SI DI	CX
	or CS:asyncst, 001h ; Set busy flag
	PRINT imgstrd

ExitStorePic:
	pop BX AX
	ret
ENDP


PrintOuts PROC
	; INPUT: SI - address of ASCII string
	push AX	ES DI DS

	; Lods : AX <= [DS:SI]
	push CS
	pop DS

	; Stos : AX => [ES:DI]
	push 0B800h
	pop ES
	xor DI,	DI ; Always write to 0 page of video memory

	mov AH,	0Ch ; Red on black color

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
	push AX	DX DS
	push CS
	pop DS
	lea DX,	adr
	mov AH,	09h
	int 21h
	pop DS DX AX
ENDM


ENTRYPOINT: ; Installing IV callbacks
	cli
	xor AX,	AX
	mov ES,	AX

	; Direct read IV from table
	mov BX,	word ptr ES:[09h*2*2]
	mov DS,	word ptr ES:[09h*2*2+2]

	; Exit when signature found
	mov CX,	CS:[sig]
	cmp CX,	DS:[BX-2]
	jne ContinLoad

	sti
	DOSPRINT notinst
	jmp EmergExit

ContinLoad:
	mov CS:i9old,	BX
	mov CS:i9old+2,	DS
	; Direct write IV to table
	mov word ptr ES:[09h*2*2], offset KbdHook
	mov word ptr ES:[09h*2*2+2], CS

	mov AX,	word ptr ES:[28h*2*2]
	mov BX,	word ptr ES:[28h*2*2+2]
	mov CS:i28old,	 AX
	mov CS:i28old+2, BX
	; Direct write IV to table
	mov word ptr ES:[28h*2*2], offset QuantumHook
	mov word ptr ES:[28h*2*2+2], CS
	sti

	DOSPRINT wasinst

	mov AX,	3100h
	mov DX,	(ENTRYPOINT - START + 10Fh)/16
	; Terminate and	stay resident -	DOS 31h
	; DX - resident	size in	paragraphs
	; OUT ---------------------------------
	; NONE
	int 21h

EmergExit:
	mov AX,	4C01h
	int 21h


wasinst	DB 'TSR installed in memory. $',0
notinst	DB 'Error, TSR already loaded! $',0


CODE ENDS
END START
