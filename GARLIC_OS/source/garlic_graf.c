
#include <nds.h>
#include <garlic_font.h>
#include <garlic_system.h>
#include <GARLIC_API.h>
/* definiciones para realizar cÃ¡lculos relativos a la posiciÃ³n de los
caracteres dentro de las ventanas grÃ¡ficas, que pueden ser 4 o 16 */
#define NVENT 4 // nÃºmero de ventanas totales
#define PPART 2 // nÃºmero de ventanas horizontales o verticales
// (particiones de pantalla)
#define VCOLS 32 // columnas y filas de cualquier ventana
#define VFILS 24
#define PCOLS VCOLS *PPART // nÃºmero de columnas totales
#define PFILS VFILS *PPART // nÃºmero de filas totales

int bg2, bg3;
/* _gg_iniGraf: inicializa el procesador grÃ¡fico A para GARLIC  */
void _gg_iniGrafA()
{

	videoSetMode(MODE_5_2D);
	vramSetBankA(VRAM_A_MAIN_BG_0x06000000);

	bg2 = bgInit(2, BgType_ExRotation, BgSize_ER_512x512, 0, 4);
	bg3 = bgInit(3, BgType_ExRotation, BgSize_ER_512x512, 16, 4); // Inicializar fondos graficos 2 y 3

	bgSetPriority(bg3, 1); // Fijar prioridades
	bgSetPriority(bg2, 2);

	decompress(garlic_fontTiles, bgGetGfxPtr(bg3), LZ77Vram); // Descomprimir el contenido de la fuente de letras

	dmaCopy(garlic_fontPal, BG_PALETTE, garlic_fontPalLen);

	_gg_generarMarco(0);
	_gg_generarMarco(1); // Generar los Marcos
	_gg_generarMarco(2);
	_gg_generarMarco(3);

	bgSetScale(bg2, 512, 512);
	bgSetScale(bg3, 512, 512); // Escalar los fondos al 50%

	bgUpdate();
}

unsigned int longitudNumero(unsigned int numero)
{
	int longitud = 0;

	if (numero == 0)
	{
		return 1; // Manejo del caso especial para el nÃºmero 0
	}

	while (numero > 0)
	{
		numero /= 10; // Contar los dÃ­gitos
		longitud++;
	}

	return longitud;
}
/* _gg_procesarFormato: copia los caracteres del string de formato sobre el
					  string resultante, pero identifica las marcas de formato
					  precedidas por '%' e inserta la representaciÃ³n ASCII de
					  los valores indicados por parÃ¡metro.
	ParÃ¡metros:
		formato	->	string con marcas de formato (ver descripciÃ³n _gg_escribir);
		val1, val2	->	valores a transcribir, sean nÃºmero de cÃ³digo ASCII (%c),
					un nÃºmero natural (%d, %x) o un puntero a string (%s);
		resultado	->	mensaje resultante.
	ObservaciÃ³n:
		Se supone que el string resultante tiene reservado espacio de memoria
		suficiente para albergar todo el mensaje, incluyendo los caracteres
		literales del formato y la transcripciÃ³n en cÃ³digo ASCII de los valores.
*/
void _gg_procesarFormato(char *formato, unsigned int val1, unsigned int val2, char *resultado)
{

	int cont = 0, n, j, f = -1, val[2], i = 0;
	val[0] = val1;
	val[1] = val2;

	char num[12];

	while (formato[i] != '\0')
	{

		if (formato[i] == '%')
		{

			f++;
			i++;

			if (formato[i] == 'x')
			{ // Caso transcrivir a Hexadecimal

				_gs_num2str_hex(num, 12, val[f]);

				for (j = 0; num[j] == '0'; j++)
				{
				}

				for (n = j; num[n] != '\0'; n++)
				{

					resultado[cont] = num[n];
					cont++;
				}
			}
			else
			{

				if (formato[i] == 'd')
				{ // Caso transcrivir a Decimal

					_gs_num2str_dec(num, 12, val[f]);

					for (n = 0; num[n] != '\0'; n++)
					{

						if (num[n] != ' ')
						{

							resultado[cont] = num[n];
							cont++;
						}
					}
				}
				else
				{

					if (formato[i] == 'c')
					{ // Caso transcrivir caracter

						resultado[cont] = val[f];
						cont++;
					}
					else
					{
						if (formato[i] == 's')
						{ // Caso transcrivir String

							u8 *o = (u8 *)val[f];

							for (int r = 0; o[r] != 0; r++)
							{

								resultado[cont] = o[r];
								cont++;
							}
						}
						else
						{

							if (formato[i] == '%')
							{ // Caso transcrivir escribir un %

								resultado[cont] = '%';
								cont++;
								f--;
							}
							else
							{

								if (formato[i] == 'l')
								{

									long long longt = *((long long *)val[f]); // Caso trasncrivir un long long
									long long quo, quo2;
									unsigned int res, den = 1000000000;
									unsigned int res2[3];
									int b = 0;

									GARLIC_divmodL(&longt, &den, &quo, &res); // Dividir el long lon por 1000000000

									res2[2] = res; // para obtener los 9 primeros numeros
									res = 0;

									GARLIC_divmodL(&quo, &den, &quo2, &res); // Dividir el long lon por 1000000000

									res2[1] = res;				  // para obtener los 9 siguientes numeros
									res2[0] = (unsigned int)quo2; // y el quociente que seria el ultimo posible num

									if (res2[0] == 0)
									{

										if (res2[1] == 0)
										{

											b = 2;
										}
										else
										{

											b = 1;
										}
									}
									for (int op = b; op < 3; op++)
									{

										_gs_num2str_dec(num, 12, res2[op]);

										for (n = 0; num[n] != '\0'; n++)
										{ // Transcrivir el long long a la variable resultado

											if (num[n] != ' ')
											{

												resultado[cont] = num[n];
												cont++;
											}
										}
									}
								}
								else
								{
									if (formato[i] == 'L')
									{ // Caso trasncrivir un long long

										long long longt = *((long long *)val[f]);
										long long quo, quo2;
										unsigned int res;
										unsigned int den = 1000000000;
										unsigned int res2[3];

										GARLIC_divmodL(&longt, &den, &quo, &res); // Dividir el long lon por 1000000000

										res2[2] = res; // para obtener los 9 primeros numeros
										res = 0;

										GARLIC_divmodL(&quo, &den, &quo2, &res); // Dividir el long lon por 1000000000

										res2[1] = res;				  // para obtener los 9 siguientes numeros
										res2[0] = (unsigned int)quo2; // y el quociente que seria el ultimo posible num

										int b = 0, w = 0;

										if (res2[0] == 0)
										{

											if (res2[1] == 0)
											{ // Control por si el long long no es tan largo no hacer mas bucles

												b = 2;
											}
											else
											{

												b = 1;
											}
										}
										for (int op = b; op < 3; op++)
										{ // Transcrivir resultado poniendo puntos en el lugar adecuado

											w = longitudNumero(res2[op]); // Calcular la longitud del numero para saber cuando poner los puntos

											_gs_num2str_dec(num, 12, res2[op]);

											for (n = 0; num[n] != '\0'; n++)
											{

												if (num[n] != ' ')
												{

													resultado[cont] = num[n];
													cont++;
													w--;

													if (w % 3 == 0 || w == 0)
													{ // Escribir punto en el lugar adecuado

														resultado[cont] = '.';
														cont++;
													}
												}
											}
										}

										cont--; // Eliminar el punto final
									}
								}
							}
						}
					}
				}
			}
		}
		else
		{

			resultado[cont] = formato[i]; // caso que no hay que transcrivir
			cont++;
		}

		i++;
	}

	resultado[cont] = '\0';
}

/* _gg_escribir: escribe una cadena de caracteres en la ventana indicada;
	ParÃ¡metros:
		formato	->	cadena de formato, terminada con centinela '\0';
					admite '\n' (salto de lÃ­nea), '\t' (tabulador, 4 espacios)
					y cÃ³digos entre 32 y 159 (los 32 Ãºltimos son caracteres
					grÃ¡ficos), ademÃ¡s de cÃ³digos de formato %c, %d, %x y %s
					(max. 2 cÃ³digos por cadena)
		val1	->	valor a sustituir en primer cÃ³digo de formato, si existe
		val2	->	valor a sustituir en segundo cÃ³digo de formato, si existe
					- los valores pueden ser un cÃ³digo ASCII (%c), un valor
					  natural de 32 bits (%d, %x) o un puntero a string (%s)
		ventana	->	nÃºmero de ventana (de 0 a 3)
*/
void _gg_escribir(char *formato, unsigned int v, unsigned int val2, int ventana)
{
    char n[96] = "";
    _gg_procesarFormato(formato, v, val2, n);
    int i = 0;
    int pControl = _gd_wbfs[ventana].pControl;
    int nChars = pControl & 0xFFFF; // 16 bits bajos para caracteres pendientes
    int filActual = pControl >> 16; // 16 bits altos para el número de línea

    while (n[i] != '\0')
    {
        if (n[i] == '\n' || nChars == VCOLS)
        {
            swiWaitForVBlank();
            if (filActual == VFILS - 1)
            {
                _gg_desplazar(ventana);
                filActual--;
            }
            _gg_escribirLinea(ventana, filActual, nChars);
            nChars = 0;
            filActual++;
        }
        else
        {
            if (n[i] == '\t')
            {
                int espaciosParaTab = 4 - (nChars % 4);
                while (espaciosParaTab-- > 0 && nChars < VCOLS)
                {
                    _gd_wbfs[ventana].pChars[nChars++] = ' ';
                }
            }
            else
            {
                _gd_wbfs[ventana].pChars[nChars++] = n[i];
            }
        }

        if (nChars < VCOLS)
        {
            i++;
        }

        // Actualizar pControl con la nueva posición
        pControl = (filActual << 16) | nChars;
        _gd_wbfs[ventana].pControl = pControl;
    }
}
/* _gg_generarMarco: dibuja el marco de la ventana que se indica por parÃ¡metro*/
void _gg_generarMarco(int v)
{

	u16 *mapPtr = bgGetMapPtr(bg3);

	int col = (v % PPART) * VCOLS; // Desplazamiento columna ventana
	int fil = (v / PPART) * VFILS; // Desplazamineto fila ventana

	mapPtr[((fil + (VFILS - 1)) * PCOLS + col)] = 100; // generar esquina abajo izquierda

	mapPtr[(fil * PCOLS + col)] = 103; // generar esquina arriba izquierda

	for (int i = 1; i < VCOLS - 1; i++)
	{

		mapPtr[fil * PCOLS + (col + i)] = 99; // generar parte de arriba

		mapPtr[(fil + (-1 + VFILS)) * PCOLS + (col + i)] = 97; // generar parte de abajo
	}

	for (int n = 1; n < VFILS - 1; n++)
	{

		mapPtr[((fil + n) * PCOLS + col)] = 96; // generar parte izquierda

		mapPtr[(fil + n) * PCOLS + col - 1 + VCOLS] = 98; // generar parte derecha
	}

	mapPtr[fil * PCOLS + (col + VCOLS - 1)] = 102; // generar esquina arriba derecha

	mapPtr[(fil + (VFILS - 1)) * PCOLS + col + VCOLS - 1] = 101; // generar esquina bajo izquierda
}
