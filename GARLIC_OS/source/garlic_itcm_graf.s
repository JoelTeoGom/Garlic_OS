.section .itcm,"ax",%progbits

	NVENT = 4 @; número de ventanas totales
	PPART = 2 @; número de ventanas horizontales o verticales
	@; (particiones de pantalla)
	L2_PPART = 1 @; log base 2 de PPART
	VCOLS = 32 @; columnas y filas de cualquier ventana
	VFILS = 24
	PCOLS = VCOLS * PPART @; número de columnas totales (en pantalla)
	PFILS = VFILS * PPART @; número de filas totales (en pantalla)
	WBUFS_LEN = 36 @; longitud de cada buffer de ventana (32+4)

	.arm
	.align 2

	.global _gg_desplazar
	@; Rutina para desplazar una posición hacia arriba todas las
	@; filas de la ventana (v), y borrar el contenido de última fila
	@;Parámetros:
	@; R0: ventana a desplazar (int v)
_gg_desplazar:
	push {r0-r12, lr}
	ldr r7, =0x6000000
	mov r10,#VCOLS
	bl _gg_desplazamiento
	
	mov r2, #0
	mov r8, #0
	.Lfor2:
	mov r1, #0
	.Lfor1:
	
	mov r3, r2, lsl# 1
	add r8, r3, #2
	
	add r3, r5,r3
	add r8, r5, r8
	
	mul r9, r3, r10
	mul r11, r8, r10
	
	
	
	
	add r9, r1, r9
	add r11, r1, r11
	add r9,r4,r9
	add r11, r4, r11
	mov r9, r9, lsl #1
	mov r11, r11, lsl #1
	ldrh r12, [r7, r11]
	strh r12, [r7, r9]
	
	
	add r1, #1
	cmp r1, #VCOLS
	blt .Lfor1
	add r2, #1		@;recorre matriz
	cmp r2, #VFILS-1
	blt .Lfor2
	mov r1, #0
	.Lfor5:
	mov r3, r2, lsl# 1
	add r3, r5,r3
	mul r9, r3, r10
	add r9, r1, r9
	add r9,r4,r9
	mov r9, r9, lsl #1
	mov r12, #0
	strh r12, [r7, r9]
	add r1, #1
	cmp r1, #VCOLS
	blt .Lfor5
	pop {r0-r12, pc}
	
	
	.global _gg_escribirLinea
	@; Rutina para escribir toda una linea de caracteres almacenada
	@; en el buffer de la ventana especificada;
	@;Parámetros:
	@; R0: ventana a actualizar (int v)
	@; R1: fila actual (int f)
	@; R2: número de caracteres a escribir (int n)
_gg_escribirLinea:

	push {r0-r12, lr}
	bl _gg_desplazamiento
	
	
	ldr r8,=_gd_wbfs 
	mov r3, #WBUFS_LEN
	mul r0, r3
	
	add r0, r0, #4
	ldr r12, =0x6000000
	mov r6,#0
	
	mov r10, #VCOLS
	mov r1, r1,lsl #1
	add r7, r5, r1
	
	mul r10,r7
	add r10, r10,r4
	mov r4, #0

	.Lfor:
	ldrb r11, [r8,r0]
	strb r4, [r8,r0]
	add r0, r0, #1
	sub r11, #32
	
	add r3, r6,r10
	mov r3, r3, lsl #1
	
	strh r11, [r12, r3]
	
	
	add r6, #1
	cmp r6, r2 
	blt .Lfor
	
	
	mul r3, r1, r3	
	add r2, r1			
	mov r2, r2, lsl #1	
	
	pop {r0-r12, pc}
	
	.global _gg_desplazamiento
	@; Rutina para calcular el desplazamiento de fila 
	@; y de columna de la ventana indicada;
	@;Parámetros:
	@; R0: ventana a actualizar (int v)
	@;Resultado
	@; R4: Desplazamiento de columna
	@; R5: Desplazamiento de fila
_gg_desplazamiento:

	push {r0-r2, lr}
	mov r2, #1
	orr r2, r2 , #L2_PPART
	and r4, r0, r2
	
	mov r5,r0, lsr #L2_PPART 
	and r5, r5, r2
	
	
	mov r1,#VCOLS
	mul r4, r1
	
	mov r1,#VFILS
	mov r1, r1, lsl #1
	mul r5, r1 
	pop {r0-r2, pc}
.end