/*------------------------------------------------------------------------------

	"FACL.c" : primer programa de prueba para el sistema operativo GARLIC 1.0;

	Lista de factoriales i*(arg+1)! desde i=0 hasta el valor que i*arg+1! quepa en 64 bits.

------------------------------------------------------------------------------*/

#include <GARLIC_API.h>			/* definición de las funciones API de GARLIC */
#include "heapsort.h"


int _start(int arg) {
    unsigned long long r;
	if (arg < 0) arg = 0; // limitar valor máximo y
	else if (arg > 3) arg = 3; // mínimo del argumento
	arg++;
	GARLIC_printf("-- Programa FACL – PID (%d) --\n", GARLIC_pid());
	for (int i=0;(arg*i)<21; i++){

		r=factorial(arg*i);

		GARLIC_printf("Factorial de %d: ",arg*i);
		GARLIC_printf("%L\n", (unsigned int)&r);
	}

    return 0;
}

