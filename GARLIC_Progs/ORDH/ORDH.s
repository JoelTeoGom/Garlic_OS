	.arch armv5te
	.eabi_attribute 23, 1
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 1
	.eabi_attribute 30, 6
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"ordh.c"
	.section	.rodata
	.align	2
.LC0:
	.ascii	"-- Programa ORDH --\012\000"
	.align	2
.LC1:
	.ascii	"-- Llista desordenada --\012\000"
	.align	2
.LC2:
	.ascii	"%d \000"
	.align	2
.LC3:
	.ascii	"\012\000"
	.align	2
.LC4:
	.ascii	"-- Llista ordenada --\012\000"
	.text
	.align	2
	.global	_start
	.syntax unified
	.arm
	.fpu softvfp
	.type	_start, %function
_start:
	@ args = 0, pretend = 0, frame = 32
	@ frame_needed = 1, uses_anonymous_args = 0
	push	{r4, r5, r6, fp, lr}
	add	fp, sp, #16
	sub	sp, sp, #36
	str	r0, [fp, #-48]
	mov	r1, sp
	mov	r6, r1
	ldr	r1, [fp, #-48]
	cmp	r1, #0
	bge	.L2
	mov	r1, #0
	str	r1, [fp, #-48]
	b	.L3
.L2:
	ldr	r1, [fp, #-48]
	cmp	r1, #3
	ble	.L3
	mov	r1, #3
	str	r1, [fp, #-48]
.L3:
	ldr	r1, [fp, #-48]
	add	r1, r1, #1
	lsl	r1, r1, #16
	lsr	r1, r1, #16
	mov	r0, r1	@ movhi
	lsl	r0, r0, #2
	add	r1, r0, r1
	lsl	r1, r1, #1
	lsl	r1, r1, #16
	lsr	r1, r1, #16
	strh	r1, [fp, #-24]	@ movhi
	ldrsh	ip, [fp, #-24]
	mov	r1, ip
	sub	r1, r1, #1
	str	r1, [fp, #-28]
	mov	r1, ip
	mov	r0, r1
	mov	r1, #0
	lsl	r5, r1, #4
	orr	r5, r5, r0, lsr #28
	lsl	r4, r0, #4
	mov	r1, ip
	mov	r0, r1
	mov	r1, #0
	lsl	r3, r1, #4
	orr	r3, r3, r0, lsr #28
	lsl	r2, r0, #4
	mov	r3, ip
	lsl	r3, r3, #1
	add	r3, r3, #1
	add	r3, r3, #7
	lsr	r3, r3, #3
	lsl	r3, r3, #3
	sub	sp, sp, r3
	mov	r3, sp
	add	r3, r3, #1
	lsr	r3, r3, #1
	lsl	r3, r3, #1
	str	r3, [fp, #-32]
	ldr	r0, .L9
	bl	GARLIC_printf
	ldr	r0, .L9+4
	bl	GARLIC_printf
	mov	r3, #0
	strh	r3, [fp, #-22]	@ movhi
	b	.L4
.L5:
	bl	GARLIC_random
	mov	r3, r0
	mov	r0, r3
	sub	r3, fp, #36
	sub	r2, fp, #40
	mov	r1, #1000
	bl	GARLIC_divmod
	ldrsh	r3, [fp, #-22]
	ldr	r2, [fp, #-36]
	lsl	r2, r2, #16
	asr	r2, r2, #16
	ldr	r1, [fp, #-32]
	lsl	r3, r3, #1
	add	r3, r1, r3
	strh	r2, [r3]	@ movhi
	ldrsh	r3, [fp, #-22]
	ldr	r2, [fp, #-32]
	lsl	r3, r3, #1
	add	r3, r2, r3
	ldrsh	r3, [r3]
	mov	r1, r3
	ldr	r0, .L9+8
	bl	GARLIC_printf
	ldrsh	r3, [fp, #-22]
	lsl	r3, r3, #16
	lsr	r3, r3, #16
	add	r3, r3, #1
	lsl	r3, r3, #16
	lsr	r3, r3, #16
	strh	r3, [fp, #-22]	@ movhi
.L4:
	ldrsh	r2, [fp, #-22]
	ldrsh	r3, [fp, #-24]
	cmp	r2, r3
	blt	.L5
	ldr	r0, .L9+12
	bl	GARLIC_printf
	ldr	r3, [fp, #-32]
	ldrsh	r2, [fp, #-24]
	mov	r1, r2
	mov	r0, r3
	bl	heapSort
	ldr	r0, .L9+16
	bl	GARLIC_printf
	mov	r3, #0
	strh	r3, [fp, #-22]	@ movhi
	b	.L6
.L7:
	ldrsh	r3, [fp, #-22]
	ldr	r2, [fp, #-32]
	lsl	r3, r3, #1
	add	r3, r2, r3
	ldrsh	r3, [r3]
	mov	r1, r3
	ldr	r0, .L9+8
	bl	GARLIC_printf
	ldrsh	r3, [fp, #-22]
	lsl	r3, r3, #16
	lsr	r3, r3, #16
	add	r3, r3, #1
	lsl	r3, r3, #16
	lsr	r3, r3, #16
	strh	r3, [fp, #-22]	@ movhi
.L6:
	ldrsh	r2, [fp, #-22]
	ldrsh	r3, [fp, #-24]
	cmp	r2, r3
	blt	.L7
	ldr	r0, .L9+12
	bl	GARLIC_printf
	mov	r3, #0
	mov	sp, r6
	mov	r0, r3
	sub	sp, fp, #16
	@ sp needed
	pop	{r4, r5, r6, fp, pc}
.L10:
	.align	2
.L9:
	.word	.LC0
	.word	.LC1
	.word	.LC2
	.word	.LC3
	.word	.LC4
	.size	_start, .-_start
	.ident	"GCC: (devkitARM release 46) 6.3.0"
