@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	c�digo de las funciones de control de procesos (2.0)
@;						(ver "garlic_system.h" para descripci�n de funciones)
@;
@;==============================================================================

.bss
	.align 2
	cociente: 	.space 4
	resto: 		.space 4
	string: 	.space 4


.section .itcm,"ax",%progbits

	.arm
	.align 2
	
	.global _gp_WaitForVBlank
	@; rutina para pausar el procesador mientras no se produzca una interrupci�n
	@; de retrazado vertical (VBL); es un sustituto de la "swi #5", que evita
	@; la necesidad de cambiar a modo supervisor en los procesos GARLIC
_gp_WaitForVBlank:
	push {r0-r1, lr}
	ldr r0, =__irq_flags
.Lwait_espera:
	mcr p15, 0, lr, c7, c0, 4	@; HALT (suspender hasta nueva interrupción)
	ldr r1, [r0]			@; R1 = [__irq_flags]
	tst r1, #1				@; comprobar flag IRQ_VBL
	beq .Lwait_espera		@; repetir bucle mientras no exista IRQ_VBL
	bic r1, #1
	str r1, [r0]			@; poner a cero el flag IRQ_VBL
	pop {r0-r1, pc}


	.global _gp_IntrMain
	@; Manejador principal de interrupciones del sistema Garlic
_gp_IntrMain:
	mov	r12, #0x4000000
	add	r12, r12, #0x208	@; R12 = base registros de control de interrupciones	
	ldr	r2, [r12, #0x08]	@; R2 = REG_IE (m�scara de bits con int. permitidas)
	ldr	r1, [r12, #0x0C]	@; R1 = REG_IF (m�scara de bits con int. activas)
	and r1, r1, r2			@; filtrar int. activas con int. permitidas
	ldr	r2, =irqTable
.Lintr_find:				@; buscar manejadores de interrupciones espec�ficos
	ldr r0, [r2, #4]		@; R0 = m�scara de int. del manejador indexado
	cmp	r0, #0				@; si m�scara = cero, fin de vector de manejadores
	beq	.Lintr_setflags		@; (abandonar bucle de b�squeda de manejador)
	ands r0, r0, r1			@; determinar si el manejador indexado atiende a una
	beq	.Lintr_cont1		@; de las interrupciones activas
	ldr	r3, [r2]			@; R3 = direcci�n de salto del manejador indexado
	cmp	r3, #0
	beq	.Lintr_ret			@; abandonar si direcci�n = 0
	mov r2, lr				@; guardar direcci�n de retorno
	blx	r3					@; invocar el manejador indexado
	mov lr, r2				@; recuperar direcci�n de retorno
	b .Lintr_ret			@; salir del bucle de b�squeda
.Lintr_cont1:	
	add	r2, r2, #8			@; pasar al siguiente �ndice del vector de
	b	.Lintr_find			@; manejadores de interrupciones espec�ficas
.Lintr_ret:
	mov r1, r0				@; indica qu� interrupci�n se ha servido
.Lintr_setflags:
	str	r1, [r12, #0x0C]	@; REG_IF = R1 (comunica interrupci�n servida)
	ldr	r0, =__irq_flags	@; R0 = direcci�n flags IRQ para gesti�n IntrWait
	ldr	r3, [r0]
	orr	r3, r3, r1			@; activar el flag correspondiente a la interrupci�n
	str	r3, [r0]			@; servida (todas si no se ha encontrado el maneja-
							@; dor correspondiente)
	mov	pc,lr				@; retornar al gestor de la excepci�n IRQ de la BIOS


	.global _gp_rsiVBL
	@; Manejador de interrupciones VBL (Vertical BLank) de Garlic:
	@; se encarga de actualizar los tics, intercambiar procesos, etc.

_gp_rsiVBL:
	@; incrementar el contador de tics general _gd_tickCount,

	push {r4-r7, lr}

	@;actualizar cola de procesos retardados, poniendo en cola de READY aquellos cuyo n�mero de tics de retardo sea 0
	bl _gp_actualizarDelay

	@;aumentar numero de ticks
	ldr r4, =_gd_tickCount	@;cargamos la direccion de _gd_tickCount
	ldr r5, [r4]		
	add r5, #1			@;incrementamos el contador de ticks
	str r5, [r4]		@;guardamos el nuevo valor de _gd_tickCount

	@;comprobar si hay procesos en ready
	ldr r4, =_gd_nReady		@;cargamos la direccion de _gd_nReady
	ldr r5, [r4]
	cmp r5, #0				@;comprobamos si hay procesos en ready
	beq .LrsiVBL_fin		@;si no hay procesos en ready salimos de la rsi

	@;comprobar si el proceso actual es el del sistema operativo
	ldr r4, =_gd_pidz	@;cargamos la direccion de _gd_pidz
	ldr r5, [r4]
	cmp r5, #0			@;si pid = 0 y zocalo = 0  ==> _gd_pidz = 0 es el SO
	beq .LrsiVBL_comprobarQuantumProc	@;comprobamos el quantum del proceso

	@;comprobar si el proceso actual es un proceso de programa que ha terminado
	bic r5, r5, #0xf @;bit clear de los 4 bits menos significativos
	cmp r5, #0		@;si pid = 0 y zocalo != 0 ==> _gd_pidz = 0 es un proceso
	beq .LrsiVBL_restaurarProc	@;si es un proceso restauramos el contexto del proceso


@; si es SO o Proceso inacabado comprobamos el quantum del proceso
.LrsiVBL_comprobarQuantumProc:

	@;comprobar si el quantum ha terminado
	ldr r6, =_gd_quantumTotal	@;cargamos la direccion de _gd_quantumTotal
	ldr r7, [r6]		@;cargamos el valor de _gd_quantumTotal
	cmp r7, #0			@;comprobamos si el quantum ha terminado
	beq .LQuantumReset	@;si el quantum ha terminado lo reseteamos

	ldr r4, =_gd_quantumCount	@;cargamos la direccion de _gd_quantumCount
	ldr r5, [r4]		@;cargamos el valor de _gd_quantumCount
	cmp r5, #0			@;comprobamos si el quantum del proceso ha terminado
	bne .LrsiQuantum	@;si el quantum no ha terminado saltamos a la etiqueta del final

	@;si el quantum ha terminado salvamos el contexto del proceso
.LrsiVBL_salvarProc:
	ldr r4, =_gd_nReady 	@; R4: direcci�n _gd_nReady
	ldr r5, [r4]			@; R5: n�mero de procesos en READY
	ldr r6, =_gd_pidz		@; R6: direcci�n _gd_pidz
	bl _gp_salvarProc

.LrsiVBL_restaurarProc:
	@; R4: direcci�n _gd_nReady
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
	@; !TENEMOS QUE CARGAR LOS PARAMETROS OTRA VEZ PORQUE NO SIEMPRE ENTRAREMOS EN LA
	@; ETIQUETA DE .LrsiVBL_salvarProc:
	ldr r4, =_gd_nReady 	@; R4: direcci�n _gd_nReady
	ldr r5, [r4]			@; R5: n�mero de procesos en READY
	ldr r6, =_gd_pidz		@; R6: direcci�n _gd_pidz
	bl _gp_restaurarProc
	b .LrsiVBL_workticks


@;si el quantum ha terminado lo reseteamos
.LQuantumReset:
	ldr r4, =_gd_pcbs		@;cargamos la direccion de pcbs	
	mov r5, #0			@; R5: contador de procesos 
.Lbucle:
	cmp r5, #16
	beq .LQuantumReset_end
	ldr r6, [r4, #24] 	@; R6: quantum del proceso
	ldr r7, =_gd_quantumTotal	@;cargamos la direccion de _gd_quantumTotal
	ldr r7, [r7]		@;cargamos el valor de _gd_quantumTotal
	add r7, r6 				@; R7: quantumTotal + quantum
	ldr r6, =_gd_quantumTotal	@;cargamos la direccion de _gd_quantumTotal
	str r7, [r6]		@;guardamos el nuevo valor de _gd_quantumTotal
	add r5, #1
	add r4, #28
	b .Lbucle
	
.LQuantumReset_end: 
	@;si el quantum ha terminado salvamos y restauramos el contexto del proceso
	b .LrsiVBL_salvarProc	@;salvamos el contexto del proceso

.LrsiQuantum:
	ldr r4, =_gd_quantumCount	@;cargamos la direccion de _gd_quantumCount
	ldr r5, [r4]		@;cargamos el valor de _gd_quantumCount
	sub r5, #1			@;decrementamos el contador de quantum
	str r5, [r4]		@;guardamos el nuevo valor de _gd_quantumCount
	ldr r4, =_gd_quantumTotal	@;cargamos la direccion de _gd_quantumTotal
	ldr r5, [r4]		@;cargamos el valor de _gd_quantumTotal
	sub r5, #1			@;decrementamos el contador de quantumTotal
	str r5, [r4]		@;guardamos el nuevo valor de _gd_quantumTotal

.LrsiVBL_workticks:
	@;incrementar el workticks del proceso que entra en ejecucion
	ldr r4, =_gd_pidz	@;cargamos la direccion de _gd_pidz
	ldr r5, [r4]		@;cargamos el valor de _gd_pidz
	and r5, r5, #0xf	@; R5: z�calo del proceso
	ldr r4, =_gd_pcbs	@;cargamos la direccion de _gd_pcbs
	mov r6, #28
	mla r4, r5, r6, r4	@; R4: direcci�n _gd_pcbs[z�calo]
	ldr r5, [r4, #20]	@; R5: workTicks del proceso
	add r5, #1			@; incrementamos el contador de workTicks
	str r5, [r4, #20]	@; guardamos el nuevo valor de _gd_pcbs[z�calo].workTicks


.LrsiVBL_fin:
	
	pop {r4-r7, pc}


	@; Rutina para salvar el estado del proceso interrumpido en la entrada
	@; correspondiente del vector _gd_pcbs
	@;Par�metros
	@; R4: direcci�n _gd_nReady
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
	@;Resultado
	@; R5: nuevo n�mero de procesos en READY (+1)
_gp_salvarProc:
	push {r8-r11, lr}

	@;comprobar si el primer bit esta a 1
	ldr r8, [r6]
	and r10, r8, #0xf	@; R8 = z?calo del proceso desbancado
	mov r8, r8, lsr #31	@; bit 31 a r8
	cmp r8, #1			@; si el bit 31 es 1 es uno no se añade en READY
	beq .Ldelay_enable	@; si el bit 31 es 0 es cero se añade en READY

	@;guardar el zocalo en la última posición de _gd_ready
	ldr r9, =_gd_qReady	@; R9 = direcci?n _gd_ready
	add r9, r5			@; R9 = direcci?n _gd_ready[nReady]
	strb r10, [r9]		@; guardar el z?calo en _gd_ready[nReady]

	@;incrementar el numero de procesos en ready
	add r5, #1			@; incrementamos el contador de procesos en ready
	str r5, [r4]		@; guardamos el nuevo valor de _gd_nReady

.Ldelay_enable:
	@;copiar SPSR la estructura garlicPCB
	mov r8, r10 		@; R8: z?calo del proceso
	ldr r9, =_gd_pcbs	@; R9: direcci�n _gd_pcbs
	mov r10, #28		@; R10: tama�o de la estructura PCB
	mla r9, r8, r10, r9	@; R9: direcci�n _gd_pcbs[z�calo]
	mrs r10, SPSR		@; R10: SPSR actual
	str r10, [r9, #12] 	@; guardar SPSR en _gd_pcbs[z�calo].status


	
	@;modo system
	mov r10, r13		@; R10: SP_irq lo guardamos antes de cambiar
	mrs r11, CPSR		@; R8: estado actual del procesador
	bic r11, r11, #0x1F	@; R8: modo usuario
	orr r11, r11, #0x1F	@; R8: modo system
	msr CPSR, r11	@; guardamos el nuevo estado del procesador

	@;R9 = _gd_pcbs[zocalo]
	@;R10 CONTIENE EL SP_IRQ

	@;guardar R0-R12 (El push ya se encarga de -4 a sp x cada registro en la 
	@;lista de registros a guardar)

	push {lr}	@;R14 

	ldr r8, [r10, #56]
	push {r8}	@;R12

	ldr r8, [r10, #12]
	push {r8}	@;R11

	ldr r8, [r10, #8]
	push {r8}	@;R10

	ldr r8, [r10, #4]
	push {r8}	@;R9

	ldr r8, [r10]
	push {r8}	@;R8

	ldr r8, [r10, #32]
	push {r8}	@;R7

	ldr r8, [r10, #28]
	push {r8}	@;R6

	ldr r8, [r10, #24]
	push {r8}	@;R5

	ldr r8, [r10, #20]
	push {r8}	@;R4

	ldr r8, [r10, #52]
	push {r8}	@;R3

	ldr r8, [r10, #48]
	push {r8}	@;R2

	ldr r8, [r10, #44]
	push {r8}	@;R1

	ldr r8, [r10, #40]
	push {r8}	@;R0

	@;guardar R13 y R15
	str r13, [r9, #8]	@;guardar R13 en _gd_pcbs[zocalo].sp
	ldr r8, [r10, #60] 	@;R8 = PC_irq + 60 = lr
	str r8, [r9, #4]	@;guardar R14 en _gd_pcbs[zocalo].pc

	@; volvemos a modo irq
	mrs r8, CPSR		@; R8: estado actual del procesador
	bic r8, r8, #0x1F	@; bit clear de modo
	orr r8, r8, #0x12	@; R8: modo IRQ
	msr CPSR, r8		@; guardamos el nuevo estado del procesador


	pop {r8-r11, pc}


	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Par�metros
	@; R4: direcci�n _gd_nReady
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}

	@; decrementar el contador de procesos en READY
	sub r5, #1			@; decrementamos el contador de procesos en ready
	str r5, [r4]		@; guardamos el nuevo valor de _gd_nReady

	@;guardar en la variable gd_pidz el PID+zocalo del proceso a restaurar
	ldr r8, =_gd_qReady	
	ldrb r9, [r8]		@;obtenemos el zocalo del primer proceso en ready
	ldr r10, =_gd_pcbs	
	mov r11, #28		@; R11: tama�o de la estructura PCB
	mla r10, r9, r11, r10	@; R10: direcci�n _gd_pcbs[z�calo]
	ldr r11, [r10]		@; R11: PID del proceso
	mov r11, r11, lsl #4	@; 4 bits a la izquierda para dejar los 4 bits bajos
	orr r11, r11, r9	@; R11: PID + z�calo del proceso
	str r11, [r6]		@; guardar PID + z�calo del proceso en _gd_pidz

	@;cargar el nuevo quantum en _gd_quantumCount
	ldr r8, [r10, #24]	@; R8: quantum del proceso
	ldr r9, =_gd_quantumCount	@; R9: direcci�n _gd_quantumCount
	str r8, [r9]		@; guardar el quantum en _gd_quantumCount

	@; restaurar el r15 del proceso a restaurar y recuperar CPSR
	ldr r8, [r10, #4]	@; R8: PC del proceso
	str r8, [r13, #60]	@; guardar PC en irq_stack
	ldr r8, [r10, #12]	@; R8: status del proceso
	msr SPSR, r8		@; restaurar CPSR

	@;pasamos a modo SYSTEM
	mov r9, r13			@; R9: SP_irq lo guardamos antes de cambiar
	mrs r11, CPSR		@; R8: estado actual del procesador
	bic r11, r11, #0x1F	@; bit clear de modo
	orr r11, r11, #0x1F	@; R8: modo SYstem
	msr CPSR, r11		@; guardamos el nuevo estado del procesador

	@;r9 = sp_irq
	@;r10 = _gd_pcbs[zocalo]
	@;Desapilar R0-R12 (El pop ya se encarga de +4 a sp x cada registro en la
	@;lista de registros a desapilar)

	ldr r13, [r10, #8]	@; R11: SP del proceso

	pop {r11}
	str r11, [r9, #40] @; r0

	pop {r11}
	str r11, [r9, #44] @; r1

	pop {r11}
	str r11, [r9, #48] @; r2

	pop {r11}
	str r11, [r9, #52] @; r3

	pop {r11}
	str r11, [r9, #20] @; r4

	pop {r11}
	str r11, [r9, #24] @; r5

	pop {r11}
	str r11, [r9, #28] @; r6

	pop {r11}
	str r11, [r9, #32] @; r7

	pop {r11}
	str r11, [r9] @; r8

	pop {r11}
	str r11, [r9, #4] @; r9

	pop {r11}
	str r11, [r9, #8] @; r10

	pop {r11}
	str r11, [r9, #12] @; r11

	pop {r11}
	str r11, [r9, #56] @; r12

	pop {r14}	@;R14
	
	@;pasamos a modo IRQ
	mrs r11, CPSR		@; R8: estado actual del procesador
	bic r11, r11, #0x1F	@; bit clear de modo
	orr r11, r11, #0x12	@; R8: modo IRQ
	msr CPSR, r11		@; guardamos el nuevo estado del procesador

	@;cola de ready hay que controlarla
	ldr r8, =_gd_qReady	@; R8: direcci�n _gd_qReady
	mov r9, #0		@; R9: contador de procesos en ready
.Loop:
	cmp r9, r5		@; comparamos con el numero de procesos en ready
	beq .Loop_end	@; si es igual salimos del bucle
	add r11, r9, #1	@; R11: contador + 1 = posicion del siguiente
	ldrb r10, [r8, r11] 	@; R10: zocalo del siguiente indice	
	strb r10, [r8, r9]	@; guardamos el zocalo en la posicion actual
	add r9, #1		@; incrementamos el contador
	b .Loop
.Loop_end:

	pop {r8-r11, pc}


	@; Rutina para actualizar la cola de procesos retardados, poniendo en
	@; cola de READY aquellos cuyo n�mero de tics de retardo sea 0
_gp_actualizarDelay:
	push {r0-r9, lr}

	@;comprobar si hay en la cola de delay
	ldr r0, =_gd_nDelay	@; R0: direcci�n _gd_nDelay
	ldr r1, [r0]		@; R1: n�mero de procesos en DELAY
	cmp r1, #0			@; si no hay procesos en DELAY, salir
	beq .LactDelay_fin

	@;comprobar si hay procesos en la cola de delay con tics de retardo = 0
	ldr r2, =_gd_qDelay	@; R2: direcci�n _gd_qDelay
	mov r3, #0			@; R3: contador de procesos en DELAY
.LactDelay_loop:
	cmp r3, r1			@; si hemos recorrido todos los procesos en DELAY, salir
	beq .LactDelay_fin	
	ldr r4, [r2, r3, lsl #2]	@; cargamos el valor de _gd_qDelay[contador*4]
	sub r4, #1			@; R4: decrementamos el contador de tics de retardo
	mov r5, r4 			@; R5: copia del contador de tics de retardo
	ldr r6, =0xffff
	and r4, r4, r6	@; R4: contador de tics de retardo (16 bits)
	cmp r4, #0			@; si contador de tics de retardo = 0, el proceso	
	bne .LactDelay_NEXT	@; debe pasar a READY

	@;actualizar cola de ready y nready 
	ldr r6, =_gd_nReady	@; R6: direcci�n _gd_nReady
	ldr r7, [r6]		@; R7: n�mero de procesos en READY
	ldr r8, =_gd_qReady	@; R8: direcci�n _gd_qReady
	mov r5, r5, lsr #24	@; R5: z�calo del proceso	
	strb r5, [r8, r7]	@; guardar el z�calo en _gd_ready[nReady]
	add r7, #1			@; incrementar el contador de procesos en READY
	str r7, [r6]		@; guardar el nuevo valor de _gd_nReady

	@;actualizar cola de delay y ndelay
	sub r1, #1			@; decrementar el contador de procesos en DELAY
	str r1, [r0]		@; guardar el nuevo valor de _gd_nDelay

	mov r6, r3
.Ldelay_update:
	cmp r6, r1			@; si hemos recorrido todos los procesos en DELAY, salir
	beq .LactDelay_fin	
	add r7, r6, #1		@; R7: contador + 1 = posicion del siguiente
	ldr r9, [r2, r7, lsl #2]	@; R9: cargamos el valor de _gd_qDelay[(contador+1) *4]
	str r9, [r2, r6, lsl #2]	@; guardar el nuevo valor de _gd_qDelay[contador*4]
	add r6, #1			@; incrementar el contador
	b .Ldelay_update

	b .LactDelay_loop

.LactDelay_NEXT:
	str r5, [r2, r3, lsl #2]	@; guardar el nuevo valor de _gd_qDelay[contador*4]
	add r3, #1			@; incrementar el contador
	b .LactDelay_loop

.LactDelay_fin:

	pop {r0-r9, pc}



	.global _gp_numProc
	@;Resultado
	@; R0: n�mero de procesos total
_gp_numProc:
	push {r1-r2, lr}
	mov r0, #1				@; contar siempre 1 proceso en RUN
	ldr r1, =_gd_nReady
	ldr r2, [r1]			@; R2 = n�mero de procesos en cola de READY
	add r0, r2				@; a�adir procesos en READY
	ldr r1, =_gd_nDelay
	ldr r2, [r1]			@; R2 = n�mero de procesos en cola de DELAY
	add r0, r2				@; a�adir procesos retardados
	pop {r1-r2, pc}


	.global _gp_crearProc
	@; prepara un proceso para ser ejecutado, creando su entorno de ejecuci�n y
	@; coloc�ndolo en la cola de READY
	@;Par�metros
	@; R0: intFunc funcion,
	@; R1: int zocalo,
	@; R2: char *nombre
	@; R3: int arg
	@;Resultado
	@; R0: 0 si no hay problema, >0 si no se puede crear el proceso
_gp_crearProc:
	push {r4-r9,lr}
	
	@; comprobar si no es el sistema operativo
	cmp r1, #0		@; comprobar que el zocalo es valido
	beq .LcrearProc_err

	@; comprobar si el zocalo esta libre
	ldr r4, =_gd_pcbs	@; direccion inicial R4 = _gd_pcbs
	mov r5, #28 	@; tamaño de la estructura PCB
	mla r4, r1, r5, r4	@; zocalo correcto R4 = _gd_pcbs[zocalo]
	ldr r5, [r4]		@; cargamos el primer entero R5 = _gd_pcbs[zocalo].pid
	cmp r5, #0			@; comprobamos que el zocalo esta libre
	bne .LcrearProc_err


	ldr r5, =_gd_pidCount	@; cargamos la direccion de _gd_pidCount
	ldr r6, [r5]	@; cargamos el primer entero R6 = _gd_pidCount
	add r6, #1		@; incrementamos el contador de procesos
	str r6, [r5]	@; guardamos el nuevo valor de _gd_pidCount

	bl _gp_inhibirIRQs @; deshabilitamos las interrupciones	

	str r6, [r4]	@; guardamos el nuevo valor de _gd_pcbs[zocalo].pid
	add r4, #4		@; nos colocamos en r4 = _gd_pcbs[zocalo].pc
	add r0, #4		@; sumamos 4 al pc para compensar el decremento
	str r0, [r4]	@; guardamos el pc
	add r4, #12		@; nos colocamos en r4 = _gd_pcbs[zocalo].keyname


	ldr r7, [r2]
	str r7, [r4]	@; con el ldr guardamos los 4 primeros bytes del nombre

	@;guardar el sp del proceso
	ldr r6, =_gd_stacks	@; cargamos la direccion de _gd_stacks
	mov r7, #512 
	mla r6, r1, r7, r6	@; r6 = _gd_stacks[indice]

	mov r7, r13		@; r7 = sp salvams el sp actual
	mov r13, r6		@; r13 = sp	ponemos el sp del stack del proceso
	
	ldr r8, =_gp_terminarProc	@; r14 = direccion de terminarProc
 
	push {r8}

	mov r8, #0
	mov r9, #0
.Lfor:
	cmp r8, #12
	beq .Lfor_end
	add r8, #1
	push {r9}
	b .Lfor
.Lfor_end:
	push {r3} 
	
	sub r4, #8		@; nos colocamos en r4 = _gd_pcbs[zocalo].sp
	str r13, [r4]	@; guardamos el sp
	mov r13, r7		@; r13 = sp recuperamos el sp
	
	add r4, #4		@; nos colocamos en r4 = _gd_pcbs[zocalo].status
	mov r5, #0x1F	@; r5 = 0x1F  => 0011 1111 (bits 0-5 a 1 modo system)
	str r5, [r4]	@; guardamos el status

	add r4, #8		@; nos colocamos en r4 = _gd_pcbs[zocalo].workTicks
	mov r5, #0		@; r5 = 0 inicializamos workticks
	str r5, [r4]	@; guardamos el workticks

	ldr r5, =_gd_nReady	@; cargamos la direccion de _gd_nReady
	ldr r6, =_gd_qReady	@; cargamos la direccion de _gd_ready
	ldr r7, [r5]	@; cargamos el primer entero R7 = _gd_nReady
	strb r1, [r6, r7]	@; guardamos el zocalo en _gd_ready[nReady]
	add r7, #1		@; incrementamos el contador de procesos en ready
	str r7, [r5]	@; guardamos el nuevo valor de _gd_nReady


	@;aumentar el quantumTotal en 1
	ldr r5, =_gd_quantumTotal	@; cargamos la direccion de _gd_quantumTotal
	ldr r6, [r5]	@; cargamos el primer entero R6 = _gd_quantumTotal
	add r6, #1		@; incrementamos el quantumTotal
	str r6, [r5]	@; guardamos el nuevo valor de _gd_quantumTotal

	@;guardar el quantum default(1) en el pcb
	ldr r5, =_gd_pcbs
	mov r6, #28
	mla r5, r1, r6, r5	@; R5: direcci�n _gd_pcbs[z�calo]
	mov r7, #1
	str r7, [r5, #24]	@; R7: quantum del proceso el guardem a r5

	bl _gp_desinhibirIRQs @; habilitamos las interrupciones

	mov r0, #0	@; r0 = 0 no hay error
	b .Lfi
.LcrearProc_err:
	mov r0, #1 @; r0 = 1 hay error
.Lfi:
	pop {r4-r9, pc}



	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del z�calo actual, para indicar que esa
	@; entrada del vector _gd_pcbs est� libre; tambi�n pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el n�mero de z�calo), para que el c�digo
	@; de multiplexaci�n de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + z�calo
	and r1, r1, #0xf		@; R1 = z�calo del proceso desbancado
	bl _gp_inhibirIRQs
	str r1, [r0]			@; guardar z�calo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #28
	mul r11, r1, r10
	add r2, r11				@; R2 = direcci�n base _gd_pcbs[zocalo]
	mov r3, #0

	@;modificamos el cuantum del proceso a 0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
	str r3, [r2, #24]		@; R3 = quantum del proceso = 0

	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
	str r3, [r2, #20]		@; borrar porcentaje de USO de la CPU
	
	
	ldr r0, =_gd_sincMain
	ldr r2, [r0]			@; R2 = valor actual de la variable de sincronismo
	mov r3, #1
	mov r3, r3, lsl r1		@; R3 = m�scara con bit correspondiente al z�calo
	orr r2, r3
	str r2, [r0]			@; actualizar variable de sincronismo
	bl _gp_desinhibirIRQs
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto



	.global _gp_matarProc
	@; Rutina para destruir un proceso de usuario:
	@; borra el PID del PCB del z�calo referenciado por par�metro, para indicar
	@; que esa entrada del vector _gd_pcbs est� libre; elimina el �ndice de
	@; z�calo de la cola de READY o de la cola de DELAY, est� donde est�;
	@; Par�metros:
	@;	R0:	z�calo del proceso a matar (entre 1 y 15).
_gp_matarProc:
	push {r1-r8,lr} 

	bl _gp_inhibirIRQs

	@;comprobar si el zocalo es el SO
	cmp r0, #0
	beq .LmatarProc_err

	@;Borrar el PID del PCB del z�calo referenciado por par�metro
	ldr r1, =_gd_pcbs
	mov r2, #28
	mla r1, r0, r2, r1	@; R1: direcci�n _gd_pcbs[z�calo]
	mov r2, #0
	str r2, [r1]		@; pone a 0 el campo PID del PCB del proceso
	
	@;HAY QUE BORRAR EL PORCENTAJE DE USO SINO SIGUE PRINTANDO EL PORCENTAJE ANTIGUO
	str r2, [r1, #20]	@; borrar porcentaje de USO de la CPU PARA ARREGLAR EL BUG
	str r2, [r1, #24]	@; borrar quantum del proceso PARA ARREGLAR EL BUG

	@;BUSCAR el �ndice de z�calo de la cola de READY 
	ldr r2, =_gd_nReady	@; R2: direcci�n _gd_nReady
	ldr r3, [r2]		@; R3: n�mero de procesos en READY
	ldr r4, =_gd_qReady	@; R4: direcci�n _gd_ready
	mov r5, #0			@; R5: contador de procesos en READY

.LmatarProc_ready_loop:
	cmp r5, r3			@; si hemos recorrido todos los procesos en READY, mirar en delay
	beq .LmatarProc_delay	@; miramos en delay
	ldrb r6, [r4, r5]	@; R6: z�calo del proceso en _gd_ready[nReady]
	cmp r6, r0			@; si el z�calo del proceso es el que buscamos, salir
	beq .LmatarProc_ready_update	@; si el z�calo del proceso es el que buscamos reordenamos y actualizamos nready
	add r5, #1			@; incrementar el contador
	b .LmatarProc_ready_loop

.LmatarProc_delay:
	@;BUSCAR el �ndice de z�calo de la cola de DELAY 
	ldr r2, =_gd_nDelay	@; R2: direcci�n _gd_nDelay
	ldr r3, [r2]		@; R3: n�mero de procesos en DELAY
	ldr r4, =_gd_qDelay	@; R4: direcci�n _gd_delay
	mov r5, #0			@; R5: contador de procesos en DELAY
.LmatarProc_delay_loop:
	cmp r5, r3			@; si hemos recorrido todos los procesos en DELAY, salir
	beq .LmatarProc_err	@; si hemos recorrido todos los procesos en DELAY, salir
	ldr r6, [r4, r5, lsl #2]	@; R6: cargamos el valor de _gd_delay[contador*4]
	mov r7, r6, lsr #24	@; R7: z�calo del proceso en _gd_delay[contador*4]
	cmp r7, r0			@; si el z�calo del proceso es el que buscamos, salir
	beq .LmatarProc_delay_update	@; si el z�calo del proceso es el que buscamos reordenamos y actualizamos ndelay
	add r5, #1			@; incrementar el contador
	b .LmatarProc_delay_loop

.LmatarProc_delay_update:
	@;actualizar cola de delay y ndelay
	sub r3, #1			@; decrementar el contador de procesos en DELAY
	str r3, [r2]		@; guardar el nuevo valor de _gd_nDelay
	@;reordenar delay
	mov r6, r5			@;indice del proceso a eliminar
.LmatarProc_delay_update_loop:
	cmp r6, r3			@; si hemos recorrido todos los procesos en DELAY, salir
	beq .LmatarProc_err	@; salir al final
	add r7, r6, #1		@; R7: contador + 1 = posicion del siguiente
	ldr r8, [r4, r7, lsl #2]	@; R8: cargamos el valor de _gd_delay[(contador+1)*4]
	str r8, [r4, r6, lsl #2]	@; guardar el nuevo valor de _gd_delay[contador*4]
	add r6, #1			@; incrementar el contador
	b .LmatarProc_delay_update_loop


.LmatarProc_ready_update:
	@;actualizar cola de ready y nready
	sub r3, #1			@; decrementar el contador de procesos en READY
	str r3, [r2]		@; guardar el nuevo valor de _gd_nReady
	@;reordenar ready
	mov r6, r5			@;indice del proceso a eliminar
.LmatarProc_ready_update_loop:
	cmp r6, r3			@; si hemos recorrido todos los procesos en READY, salir
	beq .LmatarProc_err	@; si hemos recorrido todos los procesos en READY, salir
	add r7, r6, #1		@; R7: contador + 1 = posicion del siguiente
	ldrb r8, [r4, r7]	@; R8: cargamos el valor de _gd_ready[contador+1]
	strb r8, [r4, r6]	@; guardar el nuevo valor de _gd_ready[contador]
	add r6, #1			@; incrementar el contador
	b .LmatarProc_ready_update_loop

.LmatarProc_err:
	bl _gp_desinhibirIRQs
	pop {r1-r8,pc}

	
	.global _gp_retardarProc
	@; retarda la ejecuci�n de un proceso durante cierto n�mero de segundos,
	@; coloc�ndolo en la cola de DELAY
	@;Par�metros
	@; R0: int nsec
_gp_retardarProc:
	push {r0-r5, lr}
	@;calcular numero tics
	mov r1, #60
	mul r0, r1, r0 		@; R0 = nsec * 60

	ldr r5, =_gd_pidz	
	ldr r1, [r5]		@; R1 = valor actual de PID + z�calo

	@;mirar si es el SO
	cmp r1, #0
	beq .LretardarProc_fi	@; si es el SO no hacemos nada

	@;constuir word 8 bits altos = zocalo 16 bits bajos = tics
	and r1, r1, #0xf	@; R1 = z�calo del proceso desbancado
	mov r1, r1, lsl #24	@; R1 = 8 bits m�s altos de z�calo
	orr r0, r0, r1		@; R0 = word con z�calo y n�mero de tics

	@;guardar el numero de tics en la cola de DELAY
	ldr r1, =_gd_qDelay	@; R1 = direcci�n _gd_delay
	ldr r2, =_gd_nDelay	@; R2 = direcci�n _gd_nDelay
	ldr r3, [r2]		@; R3 = n�mero de procesos en cola de DELAY
	mov r4, #4
	mla r1, r3, r4, r1	@; R1 = direcci�n _gd_delay[nDelay]

	bl _gp_inhibirIRQs

	str r0, [r1]		@; guardar el n�mero de tics en _gd_delay[nDelay]

	@;incrementar el numero de procesos en DELAY
	add r3, #1			@; incrementar el contador de procesos en DELAY
	str r3, [r2]		@; guardar el nuevo valor de _gd_nDelay

	@;fijar el bit mas alto de la variable pidz en 1
	ldr r1, [r5]	@; R1 = valor actual de PID + z�calo
	orr r1, r1, #0x80000000	@; R1 = PID + z�calo con bit m�s alto a 1
	str r1, [r5]	@; guardar PID + z�calo con bit m�s alto a 1

	bl _gp_desinhibirIRQs
	@;forzar el cambio de contexto
	bl _gp_WaitForVBlank	@; pausar procesador

.LretardarProc_fi:
	pop {r0-r5, pc}


	.global _gp_inihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 0, para inhibir todas
	@; las IRQs y evitar as� posibles problemas debidos al cambio de contexto
_gp_inhibirIRQs:
	push {r0-r1, lr}
	ldr r0, =0x4000208	@; R0: direcci�n del registro REG_IME
	ldr r1, [r0]		@; R1: valor actual del registro REG_IME
	bic r1, r1, #1		@; poner a 0 el bit IME (Interrupt Master Enable)
	str r1, [r0]		@; guardar el valor actual del registro REG_IME
	pop {r0-r1, pc}


	.global _gp_desinihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 1, para desinhibir todas
	@; las IRQs
_gp_desinhibirIRQs:
	push {r0-r1,lr}
	ldr r0, =0x4000208	@; R0: direcci�n del registro REG_IME
	ldr r1, [r0]		@; R1: valor actual del registro REG_IME
	orr r1, r1, #1 		@; poner a 1 el bit IME (Interrupt Master Enable)
	str r1, [r0]		@; guardar el valor actual del registro REG_IME
	pop {r0-r1,pc}


	.global _gp_rsiTIMER0
	@; Rutina de Servicio de Interrupci�n (RSI) para contabilizar los tics
	@; de trabajo de cada proceso: suma los tics de todos los procesos y calcula
	@; el porcentaje de uso de la CPU, que se guarda en los 8 bits altos de la
	@; entrada _gd_pcbs[z].workTicks de cada proceso (z) y, si el procesador
	@; gr�fico secundario est� correctamente configurado, se imprime en la
	@; columna correspondiente de la tabla de procesos.
_gp_rsiTIMER0:
	push {r0-r9, lr}

	@;miramos si se ha pulsado la tecla select
	ldr r0, =0x04000130	@; R0: direcci�n del registro de las KEYS_INPUT
	ldrh r1, [r0] @;leer 16 bits de REG_KEYINPUT en R1
	
	@;sumar todos los workticks de cada proceso
	ldr r4, =_gd_pcbs	@; R4: direcci�n _gd_pcbs
	mov r5, #28			@; R5: tama�o de la estructura PCB
	mov r6, #0			@; R6: contador de procesos
	mov r7, #0			@; R7: workticks total
	
	tst r1, #0x0004 	@;testear bit 6 (SELECT) de REG_KEYINPUT
	beq .LselectLoop	@; si se ha pulsado el select, no se muestran los cuantums de cada proceso

.LrsiTIMER0_loop:
	cmp r6, #16		@; si hemos recorrido todos los procesos, salir
	beq .LrsiTIMER0_end
	mla r8, r6, r5, r4		@; R8: direcci�n _gd_pcbs[z�calo]
	ldr r9, [r8, #20]	 	@; R9: workticks del proceso
	and r9, r9, #0x00FFFFFF	@; R9: workticks del proceso (24 bits bajos)
	add r7, r7, r9			@; R7: workticks total
	add r6, #1			@; incrementar el contador
	b .LrsiTIMER0_loop
.LrsiTIMER0_end:

	@;calcular el porcentaje de uso de la CPU x proceso
	mov r6, #0		@; R6: contador de procesos
.LrsiTIMER0_loop2:
	cmp r6, #16		@; si hemos recorrido todos los procesos, salir
	beq .LrsiTIMER0_end2
	mla r8, r6, r5, r4	@; R8: direcci�n _gd_pcbs[z�calo]
	ldr r9, [r8]		@; R9: PID del proceso
	cmp r6, #0			@; si es el proceso 0 (SO) NO ES NECESARIO MIRAR PID = 0
	beq .LrsiTIMER0_SO
	cmp r9, #0			@; si el proceso no existe, salir
	beq	.LrsiTIMER0_NEXT
	
.LrsiTIMER0_SO:
	ldr r9, [r8, #20]	@; R9: workticks del proceso
	and r9, r9, #0x00FFFFFF		@; R9: workticks del proceso (24 bits bajos)
	mov r0, #100
	mul r9, r0, r9		@; R9: workticks del proceso * 100

	@; dividir por el total de workticks
	mov r0, r9	@; R0: dividendo (workticks * 100)
	mov r1, r7  @; R1: divisor (workticks total)
	ldr r2, =cociente @; R2: direcci�n de la variable cociente
	ldr r3, =resto 		@; R3: direcci�n de la variable resto
	bl _ga_divmod	@; R0: num, R1: den, R2: quo, R3: mod

	@; guardar el porcentaje de uso de la CPU en _gd_pcbs[z�calo].workTicks y poner a 0 el resto
	ldr r0, =cociente 		@; R0: direcci�n de la variable cociente
	ldr r9, [r0]	@; R9: cociente (porcentaje de uso de la CPU x proceso)
	mov r9, r9, lsl #24		@; R9: workticks del proceso (8 bits altos)
	str r9, [r8, #20]		@; guardar el porcentaje de uso de la CPU en _gd_pcbs[z�calo].workTicks

	@; convertir ese % en string y escribirlo en la columna correspondiente de la tabla de procesos
	ldr r2, [r0]	@; R2: cociente (porcentaje de uso de la CPU)
	ldr r0, =string 		@; R0: direcci�n del string
	mov r1, #4 				@; R1: tamaño del string
	bl _gs_num2str_dec		@; _gs_num2str_dec(string, 4, cociente (porcentaje de uso de la CPU));

	@; escribir este string % en la columna correspondiente de la tabla de procesos
	ldr r0, =string 		@; R0: direcci�n del string
	add r1, r6, #4 				@; R1: fila 4
	mov r2, #28				@; R2: columna 28
	mov r3, #0 				@; r3: color blanco
	bl _gs_escribirStringSub	@; _gs_escribirStringSub(string, 4, 28, 0);

.LrsiTIMER0_NEXT:
	add r6, #1			@; incrementar el contador
	b .LrsiTIMER0_loop2


@;si se ha pulsado el select se muestran los cuantums de cada proceso	
.LselectLoop:
	cmp r6, #16		@; si hemos recorrido todos los procesos, salir
	beq .LrsiTIMER0_end2
	mla r7, r6, r5, r4	@; R8: direcci�n _gd_pcbs[z�calo]
	ldr r8, [r7]		@; R9: PID del proceso
	cmp r6, #0			@; si es el proceso 0 (SO) NO ES NECESARIO MIRAR PID = 0
	beq .LrsiTIMER0_select_SO
	cmp r8, #0			@; si el proceso no existe, salir
	beq	.LrsiTIMER0_select_NEXT

.LrsiTIMER0_select_SO:
	@; convertir ese % en string y escribirlo en la columna correspondiente de la tabla de procesos
	ldr r2, [r7, #24]	@; R2: quantum del proceso
	ldr r0, =string 		@; R0: direcci�n del string
	mov r1, #4 				@; R1: tamaño del string
	bl _gs_num2str_dec		@; _gs_num2str_dec(string, 4, quantum del proceso);

	@; escribir este string en la columna correspondiente de la tabla de procesos
	ldr r0, =string 		@; R0: direcci�n del string
	add r1, r6, #4 				@; R1: fila 4
	mov r2, #28				@; R2: columna 28
	mov r3, #0 				@; r3: color blanco
	bl _gs_escribirStringSub	@; _gs_escribirStringSub(string, 4, 28, 0);
	
.LrsiTIMER0_select_NEXT:
	add r6, #1			@; incrementar el contador
	b .LselectLoop

.LrsiTIMER0_end2:
	
	@;poner a 1 el bit 0 de a variable global _gd_sincMain
	ldr r0, =_gd_sincMain
	ldr r1, [r0]		@; R1 = valor actual de la variable de sincronismo
	orr r1, #1
	str r1, [r0]		@; actualizar variable de sincronismo

	pop {r0-r9, pc}

.end

