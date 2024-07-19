#include <GARLIC_API.h>            /* definición de las funciones API de GARLIC */

int _start(int arg)                /* función de inicio : no se usa 'main' */
{
    if (arg < 0) arg = 0;
    else if (arg > 3) arg = 3;

    GARLIC_clear();


    GARLIC_printf("-- Programa CIFRAR - PID (%d) --\n", GARLIC_pid());

    // Realizar cifrado XOR en código ASCII y aplicar la fórmula
    char mensaje[] = "esto es un texto cifrado";
    GARLIC_printf("Mensaje a cifrar: %s\n", mensaje);
    int i;
    char cifrado[100];
    for (i = 0; mensaje[i] != '\0'; i++) {
        cifrado[i] = mensaje[i] ^ 5;    // XOR con clave 5
        cifrado[i] += arg * 10;         // sumado arg * 10
    }
    cifrado[i] = '\0';  // Terminar la cadena cifrada con el carácter nulo
    GARLIC_printf("Mensaje cifrado: %s\n", cifrado);
    
    char descifrado[100];
    // Realizar descifrado XOR en código ASCII y aplicar la fórmula
    for (i = 0; cifrado[i] != '\0'; i++) {
        descifrado[i] = cifrado[i] - arg * 10;
        descifrado[i] ^= 5;
    }
    descifrado[i] = '\0';  // Terminar la cadena descifrada con el carácter nulo
    GARLIC_printf("Mensaje descifrar: %s\n", descifrado);

    return 0;
}