/*------------------------------------------------------------------------------

	"garlic_system.h" : definiciones de las variables globales, funciones y
						rutinas del sistema operativo GARLIC (versiï¿½n 1.0)

	Analista-programador: santiago.romani@urv.cat
	Programador P: xxx.xxx@estudiants.urv.cat
	Programador M: ruben.lopezm@estudiants.urv.cat
	Programador G: zzz.zzz@estudiants.urv.cat
	Programador T: uuu.uuu@estudiants.urv.cat

------------------------------------------------------------------------------*/
#ifndef _GARLIC_SYSTEM_h
#define _GARLIC_SYSTEM_h


//------------------------------------------------------------------------------
//	Variables globales del sistema (garlic_dtcm.s)
//------------------------------------------------------------------------------

extern int _gd_pidz;		// Identificador de proceso (PID) + zï¿½calo
							// (PID en 28 bits altos, zï¿½calo en 4 bits bajos,
							// cero si se trata del propio sistema operativo)

extern int _gd_pidCount;	// Contador de PIDs: se incrementa cada vez que
							// se crea un nuevo proceso (max. 2^28)

extern int _gd_tickCount;	// Contador de tics: se incrementa cada IRQ_VBL, y
							// permite contabilizar el paso del tiempo

extern int _gd_sincMain;	// Sincronismos con programa principal:
							// bit 0 = 1 indica si se ha acabado de calcular el
							// 				el uso de la CPU,
							// bits 1-15 = 1 indica si el proceso del zócalo
							//

extern int _gd_seed;		// Semilla para generaciï¿½n de nï¿½meros aleatorios
							// (tiene que ser diferente de cero)


extern int _gd_nReady;		// Nï¿½mero de procesos en cola de READY (de 0 a 15)

extern char _gd_qReady[16];	// Cola de READY (procesos preparados) : vector
							// ordenado con _gd_nReady entradas, conteniendo
							// los identificadores (0-15) de los zï¿½calos de los
							// procesos (mï¿½x. 15 procesos + sistema operativo)

extern int _gd_nDelay;		// Número de procesos en cola de DELAY (de 0 a 15)

extern int _gd_qDelay[16];	// Cola de DELAY (procesos retardados) : vector
							// con _gd_nDelay entradas, conteniendo los
							// identificadores de los zócalos (8 bits altos)
							// más el número de tics restantes (16 bits bajos)
							// para desbloquear el proceso

extern int _gd_quantumCount; //cola de cuantums de los procesos

extern int _gd_quantumTotal; //cuantums totales de los procesos
typedef struct				// Estructura del bloque de control de un proceso
{							// (PCB: Process Control Block)
	int PID;				//	identificador del proceso (Process IDentifier)
	int PC;					//	contador de programa (Program Counter)
	int SP;					//	puntero al top de pila (Stack Pointer)
	int Status;				//	estado del procesador (CPSR)
	int keyName;			//	nombre en clave del proceso (cuatro chars)
	int workTicks;			//	contador de ciclos de trabajo (24 bits bajos)
	int quantum;
							//		8 bits altos: uso de CPU (%)
} PACKED garlicPCB;

extern garlicPCB _gd_pcbs[16];	// vector con los PCBs de los procesos activos

typedef struct				// Estructura del buffer de una ventana
{							// (WBUF: Window BUFfer)
	int pControl;			//	control de escritura en ventana
							//		16 bits altos: nï¿½mero de lï¿½nea (0-23)
							//		16 bits bajos: caracteres pendientes (0-32)
	char pChars[32];		//	vector de 32 caracteres pendientes de escritura
							//		indicando el cï¿½digo ASCII de cada posiciï¿½n
} PACKED garlicWBUF;

extern garlicWBUF _gd_wbfs[4];	// vector con los buffers de 4 ventanas


extern int _gd_stacks[15*128];	// vector con las pilas de los procesos activos


extern int _gm_primeraPosMem;	// contindrà la primera posició de memòria lliure 

extern int quo;
extern int mod;




//------------------------------------------------------------------------------
//	Rutinas de gestiï¿½n de procesos (garlic_itcm_proc.s)
//------------------------------------------------------------------------------

/* intFunc:		nuevo tipo de dato para representar puntero a funciï¿½n que
				devuelve un int, concretamente, el puntero a la funciï¿½n de
				inicio de los procesos cargados en memoria */
typedef int (* intFunc)(int);

/* _gp_WaitForVBlank:	sustituto de swiWaitForVBlank para procesos de Garlic */
extern void _gp_WaitForVBlank();


/* _gp_IntrMain:	manejador principal de interrupciones del sistema Garlic */
extern void _gp_IntrMain();

/* _gp_rsiVBL:	manejador de interrupciones VBL (Vertical BLank) de Garlic */
extern void _gp_rsiVBL();


/* _gp_numProc:	devuelve el nï¿½mero de procesos cargados en el sistema,
				incluyendo el proceso en RUN y los procesos en READY */
extern int _gp_numProc();


/* _gp_crearProc:	prepara un proceso para ser ejecutado, creando su entorno
				de ejecución y colocándolo en la cola de READY;
	Parámetros:
		funcion	->	dirección de memoria de entrada al código del proceso
		zocalo	->	identificador del zócalo (0 - 15)
		nombre	->	nombre en clave del programa (4 caracteres ASCII)
		arg		->	argumento del programa
	Resultado:	0 si no hay problema, >0 si no se puede crear el proceso
*/
extern int _gp_crearProc(intFunc funcion, int zocalo, char *nombre, int arg);


/* _gp_retardarProc:	retarda la ejecución del proceso actual durante el
				número de segundos que se especifica por parámetro,
				colocándolo en el vector de DELAY;
	Parámetros:
		nsec ->	número de segundos (max. 600); si se especifica 0, el proceso
				solo se desbanca y el retardo será el tiempo que tarde en ser
				restaurado (depende del número de procesos activos del sistema)
	ATENCIÓN:
				¡el proceso del sistema operativo (PIDz = 0) NO podrá utilizar
				esta función, para evitar que el procesador se pueda quedar sin
				procesos a ejecutar!
*/
extern int _gp_retardarProc(int nsec);


/* _gp_matarProc:	elimina un proceso de las colas de READY o DELAY, según
				donde se encuentre, libera memoria y borra el PID de la
				estructura _gd_pcbs[zocalo] correspondiente al zócalo que se
				pasa por parámetro;
	ATENCIÓN:	Esta función solo la llamará el sistema operativo, por lo tanto,
				no será necesario realizar comprobaciones del parámetro; por
				otro lado, el proceso del sistema operativo (zocalo = 0) ¡NO se
				tendrá que destruir a sí mismo!
*/
extern int _gp_matarProc(int zocalo);



/* _gp_rsiTIMER0:	manejador de interrupciones del TIMER0 de la plataforma NDS,
				que refrescará periódicamente la información de la tabla de
				procesos relativa al tanto por ciento de uso de la CPU */
extern void _gp_rsiTIMER0();




//------------------------------------------------------------------------------
//	Funciones de gestiï¿½n de memoria (garlic_mem.c)
//------------------------------------------------------------------------------

/* _gm_initFS: inicializa el sistema de ficheros, devolviendo un valor booleano
					para indiciar si dicha inicializaciï¿½n ha tenido ï¿½xito;
*/
extern int _gm_initFS();


/* _gm_listaProgs: devuelve una lista con los nombres en clave de todos
				los programas que se encuentran en el directorio "Programas".
				Se considera que un fichero es un programa si su nombre tiene
				8 caracteres y termina con ".elf"; se devuelven solo los
				4 primeros caracteres del nombre del fichero (nombre en clave),
				que por convenio deben estar en mayúsculas.
				El resultado es un vector de strings (paso por referencia) y
				el número de programas detectados */
extern int _gm_listaProgs(char* progs[]);


/* _gm_cargarPrograma: busca un fichero de nombre "(keyName).elf" dentro del
				directorio "/Programas/" del sistema de ficheros, y carga los
				segmentos de programa a partir de una posición de memoria libre,
				efectuando la reubicación de las referencias a los símbolos del
				programa, según el desplazamiento del código y los datos en la
				memoria destino;
	Parámetros:
		zocalo	->	índice del zócalo que indexará el proceso del programa
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
		!= 0	->	dirección de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
extern intFunc _gm_cargarPrograma(char *keyName);


//------------------------------------------------------------------------------
//	Rutinas de soporte a la gestiï¿½n de memoria (garlic_itcm_mem.s)
//------------------------------------------------------------------------------

/* _gm_reubicar: rutina de soporte a _gm_cargarPrograma(), que interpreta los
				'relocs' de un fichero ELF, contenido en un buffer *fileBuf,
				y ajustar las direcciones de memoria correspondientes a las
				referencias de tipo R_ARM_ABS32, a partir de las direcciones
				de memoria destino de código (dest_code) y datos (dest_data),
				y según el valor de las direcciones de las referencias a
				reubicar y de las direcciones de inicio de los segmentos de
				código (pAddr_code) y datos (pAddr_data) */
extern void _gm_reubicar(char *fileBuf, unsigned int pAddr, unsigned int *dest);


/* _gm_reservarMem: rutina para reservar un conjunto de franjas de memoria 
				libres consecutivas que proporcionen un espacio suficiente para
				albergar el tamaño de un segmento de código o datos del proceso
				(según indique tipo_seg), asignado al número de zócalo que se
				pasa por parámetro;
				la rutina devuelve la primera dirección del espacio reservado; 
				en el caso de que no quede un espacio de memoria consecutivo del
				tamaño requerido, devuelve cero */
extern void * _gm_reservarMem(int z, int tam, unsigned char tipo_seg);


/* _gm_liberarMem: rutina para liberar todas las franjas de memoria asignadas
				al proceso del zócalo indicado por parámetro */
extern void _gm_liberarMem(int z);


/* _gm_pintarFranjas: rutina para pintar las líneas verticales correspondientes
				a un conjunto de franjas consecutivas de memoria asignadas a un
				segmento (de código o datos) del zócalo indicado por parámetro.
	Parámetros:
		zocalo		->	el zócalo que reserva la memoria (0 para borrar)
		index_ini	->	el índice inicial de las franjas
		num_franjas	->	el número de franjas a pintar
		tipo_seg	->	el tipo de segmento reservado (0 -> código, 1 -> datos)
*/
extern void _gm_pintarFranjas(unsigned char zocalo, unsigned short index_ini,
							unsigned short num_franjas, unsigned char tipo_seg);


/* _gm_rsiTIMER1:	manejador de interrupciones del TIMER1 de la plataforma NDS,
				que refrescará periódicamente la información de la tabla de
				procesos relativa al uso de la pila y el estado del proceso */
extern void _gm_rsiTIMER1();



//------------------------------------------------------------------------------
//	Funciones de gestiï¿½n de grï¿½ficos (garlic_graf.c)
//------------------------------------------------------------------------------

/* _gg_iniGraf: inicializa el procesador gráfico A para GARLIC 1.0 */
extern void _gg_iniGrafA();


/* _gg_generarMarco: dibuja el marco de la ventana que se indica por parámetro,
												con el color correspondiente */
extern void _gg_generarMarco(int v);


/* _gg_escribirCar: escribe un carácter (baldosa) en la posición de la ventana
				indicada, con un color concreto;
	Parámetros:
		vx		->	coordenada x de ventana (0..31)
		vy		->	coordenada y de ventana (0..23)
		caracter->	código del caràcter, como número de baldosa (0..127)
		color	->	número de color del texto (de 0 a 3)
		ventana	->	número de ventana (de 0 a 15)
*/
extern void _gg_escribirCar(int vx, int vy, char c, int color, int ventana);


//------------------------------------------------------------------------------
//	Rutinas de soporte a la gestión de gráficos (garlic_itcm_graf.s)
//------------------------------------------------------------------------------

/* _gg_escribirLinea: rutina de soporte a _gg_escribir(), para escribir sobre la
					fila (f) de la ventana (v) los caracters pendientes (n) del
					buffer de ventana correspondiente.
*/
extern void _gg_escribirLinea(int v, int f, int n);


/* desplazar: rutina de soporte a _gg_escribir(), para desplazar una posición
					hacia arriba todas las filas de la ventana (v), y borrar el
					contenido de la última fila.
*/
extern void _gg_desplazar(int v);


/* _gg_escribirCar: escribe un carácter (baldosa) en la posición de la ventana
				indicada, con un color concreto;
	Parámetros:
		vx		->	coordenada x de ventana (0..31)
		vy		->	coordenada y de ventana (0..23)
		caracter->	código del caràcter, como número de baldosa (0..127)
		color	->	número de color del texto (de 0 a 3)
		ventana	->	número de ventana (de 0 a 15)
*/
extern void _gg_escribirCar(int vx, int vy, char c, int color, int ventana);


/* _gg_escribirMat: escribe una matriz de 8x8 carácteres a partir de una
				posición de la ventana indicada, con un color concreto;
	Parámetros:
		vx		->	coordenada x inicial de ventana (0..31)
		vy		->	coordenada y inicial de ventana (0..23)
		m		->	matriz 8x8 de códigos ASCII
		color	->	número de color del texto (de 0 a 3)
		ventana	->	número de ventana (de 0 a 15)
*/
extern void _gg_escribirMat(int vx, int vy, char m[][8], int color, int ventana);


/* _gg_escribirLineaTabla: escribe los campos básicos de una linea de la tabla
				de procesos, correspondiente al número de zócalo que se pasa por
				parámetro con el color especificado; los campos a escribir son:
					número de zócalo, PID y nombre en clave del proceso (keyName)
*/
extern void _gg_escribirLineaTabla(int z, int color);


/* _gg_rsiTIMER2:	manejador de interrupciones del TIMER2 de la plataforma NDS,
				que refrescará periódicamente la información de la tabla de
				procesos relativa a la dirección actual de ejecución */
extern void _gg_rsiTIMER2();



//------------------------------------------------------------------------------
//	Rutinas de soporte al sistema (garlic_itcm_sys.s)
//------------------------------------------------------------------------------

/* _gs_num2str_dec: convierte el número pasado por valor en el parámetro num
					a una representación en códigos ASCII de los dígitos
					decimales correspondientes, escritos dentro del vector de
					caracteres numstr, que se pasa por referencia; el parámetro
					length indicará la longitud del vector; la rutina coloca un
					caracter centinela (cero) en la última posición del vector
					(numstr[length-1]) y, a partir de la penúltima posición,
					empieza a colocar los códigos ASCII correspondientes a las
					unidades, decenas, centenas, etc.; en el caso que después de
					trancribir todo el número queden posiciones libres en el
					vector, la rutina rellenará dichas posiciones con espacios
					en blanco, y devolverá un cero; en el caso que NO hayan
					suficientes posiciones para transcribir todo el número, la
					función abandonará el proceso y devolverá un valor diferente
					de cero.
		ATENCIóN:	solo procesa números naturales de 32 bits SIN signo. */
extern int _gs_num2str_dec(char * numstr, unsigned int length, unsigned int num);


/* _gs_num2str_hex:	convierte el parámetro num en una representación en códigos
					ASCII sobre el vector de caracteres numstr, en base 16
					(hexa), siguiendo las mismas reglas de gestión del espacio
					del string que _gs_num2str_dec, salvo que las posiciones de
					más peso vacías se rellenarán con ceros, no con espacios en
					blanco */
extern int _gs_num2str_hex(char * numstr, unsigned int length, unsigned int num);


/* _gs_copiaMem: copia un bloque de numBytes bytes, desde una posición de
				memoria inicial (*source) a partir de otra posición de memoria
				destino (*dest), teniendo en cuenta que ambas posiciones de
				memoria deben estar alineadas a word */
extern void _gs_copiaMem(const void *source, void *dest, unsigned int numBytes);


/* _gs_borrarVentana: borra el contenido de la ventana que se pasa por parámetro,
				así como el campo de control del buffer de ventana
				_gd_wbfs[ventana].pControl; la rutina puede operar en una
				configuración de 4 o 16 ventanas, según el parámetro de modo;
	Parámetros:
		ventana ->	número de ventana
		modo 	->	(0 -> 4 ventanas, 1 -> 16 ventanas)
*/
extern void _gs_borrarVentana(int zocalo, int modo);


/* _gs_iniGrafB: inicializa el procesador gráfico B para GARLIC 2.0 */
extern void _gs_iniGrafB();


/* _gs_escribirStringSub: escribe un string (terminado con centinela cero) a
				partir de la posición indicada por parámetros (fil, col), con el
				color especificado, en la pantalla secundaria */
extern void _gs_escribirStringSub(char *string, int fil, int col, int color);


/* _gs_dibujarTabla: dibujar la tabla de procesos */
extern void _gs_dibujarTabla();



//------------------------------------------------------------------------------
//	Rutinas de soporte a la interficie de usuario (garlic_itcm_ui.s)
//------------------------------------------------------------------------------
extern int _gi_za;				// zócalo seleccionado actualmente


/* _gi_movimientoVentanas:	actualiza el desplazamiento y escalado de los
				fondos 2 y 3 del procesador gráfico A, para efectuar los
				movimientos de las ventanas según el comportamiento
				requerido de la interficie de usuario */
extern void _gi_movimientoVentanas();


/* _gi_redibujarZocalo: rutina para actualizar la tabla de zócalos en función
				del zócalo actual (_gi_za) y del parámetro (seleccionar):
					si seleccionar == 0, dibuja la línea de _gi_za según el
											color asociado al estado del zócalo
											(blanco -> activo, salmón -> libre);
					sino, 				dibuja la línea en magenta
*/
extern void _gi_redibujarZocalo(int seleccionar);


/* _gi_controlInterfaz: rutina para gestionar la interfaz del usuario a partir
				del código de tecla que se pasa por parámetro */
extern void _gi_controlInterfaz(int key);



#endif // _GARLIC_SYSTEM_h