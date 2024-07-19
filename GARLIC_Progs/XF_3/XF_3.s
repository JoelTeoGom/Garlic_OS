	.arch armv5te
	.eabi_attribute 23, 1
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 1
	.eabi_attribute 30, 6
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"XF_3.c"
	.section	.rodata
	.align	2
.LC0:
	.ascii	"-- Programa CIFRAR - PID (%d) --\012\000"
	.align	2
.LC2:
	.ascii	"Mensaje a cifrar: %s\012\000"
	.align	2
.LC3:
	.ascii	"Mensaje cifrado: %s\012\000"
	.align	2
.LC4:
	.ascii	"Mensaje descifrar: %s\012\000"
	.align	2
.LC1:
	.ascii	"esto es un texto cifrado\000"
	.text
	.align	2
	.global	_start
	.syntax unified
	.arm
	.fpu softvfp
	.type	_start, %function
_start:
	@ args = 0, pretend = 0, frame = 240
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #244
	str	r0, [sp, #4]
	ldr	r3, [sp, #4]
	cmp	r3, #0
	bge	.L2
	mov	r3, #0
	str	r3, [sp, #4]
	b	.L3
.L2:
	ldr	r3, [sp, #4]
	cmp	r3, #3
	ble	.L3
	mov	r3, #3
	str	r3, [sp, #4]
.L3:
	bl	GARLIC_clear
	bl	GARLIC_pid
	mov	r3, r0
	mov	r1, r3
	ldr	r0, .L9
	bl	GARLIC_printf
	ldr	r3, .L9+4
	add	ip, sp, #208
	mov	lr, r3
	ldmia	lr!, {r0, r1, r2, r3}
	stmia	ip!, {r0, r1, r2, r3}
	ldm	lr, {r0, r1, r2}
	stmia	ip!, {r0, r1}
	strb	r2, [ip]
	add	r3, sp, #208
	mov	r1, r3
	ldr	r0, .L9+8
	bl	GARLIC_printf
	mov	r3, #0
	str	r3, [sp, #236]
	b	.L4
.L5:
	add	r2, sp, #208
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	eor	r3, r3, #5
	and	r1, r3, #255
	add	r2, sp, #108
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	mov	r2, r1
	strb	r2, [r3]
	add	r2, sp, #108
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	ldrb	r2, [r3]	@ zero_extendqisi2
	ldr	r3, [sp, #4]
	and	r3, r3, #255
	mov	r1, r3
	lsl	r1, r1, #2
	add	r3, r1, r3
	lsl	r3, r3, #1
	and	r3, r3, #255
	add	r3, r2, r3
	and	r1, r3, #255
	add	r2, sp, #108
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	mov	r2, r1
	strb	r2, [r3]
	ldr	r3, [sp, #236]
	add	r3, r3, #1
	str	r3, [sp, #236]
.L4:
	add	r2, sp, #208
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	cmp	r3, #0
	bne	.L5
	add	r2, sp, #108
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	mov	r2, #0
	strb	r2, [r3]
	add	r3, sp, #108
	mov	r1, r3
	ldr	r0, .L9+12
	bl	GARLIC_printf
	mov	r3, #0
	str	r3, [sp, #236]
	b	.L6
.L7:
	add	r2, sp, #108
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	ldrb	r2, [r3]	@ zero_extendqisi2
	ldr	r3, [sp, #4]
	and	r3, r3, #255
	mov	r1, r3
	lsl	r1, r1, #5
	sub	r1, r1, r3
	lsl	r1, r1, #2
	sub	r3, r1, r3
	lsl	r3, r3, #1
	and	r3, r3, #255
	add	r3, r2, r3
	and	r1, r3, #255
	add	r2, sp, #8
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	mov	r2, r1
	strb	r2, [r3]
	add	r2, sp, #8
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	eor	r3, r3, #5
	and	r1, r3, #255
	add	r2, sp, #8
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	mov	r2, r1
	strb	r2, [r3]
	ldr	r3, [sp, #236]
	add	r3, r3, #1
	str	r3, [sp, #236]
.L6:
	add	r2, sp, #108
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	cmp	r3, #0
	bne	.L7
	add	r2, sp, #8
	ldr	r3, [sp, #236]
	add	r3, r2, r3
	mov	r2, #0
	strb	r2, [r3]
	add	r3, sp, #8
	mov	r1, r3
	ldr	r0, .L9+16
	bl	GARLIC_printf
	mov	r3, #0
	mov	r0, r3
	add	sp, sp, #244
	@ sp needed
	ldr	pc, [sp], #4
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
