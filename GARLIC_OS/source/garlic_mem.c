/*------------------------------------------------------------------------------

	"garlic_mem.c" : fase 1 / programador M

	Funciones de carga de un fichero ejecutable en formato ELF, para GARLIC 1.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <filesystem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <garlic_system.h>	// definición de funciones y variables de sistema
#include <elf.h>


ProgramCarregat programCarregats[15];											//estructura per emmagatzemar cada programa carregat a memoria de manera estàtica
int numprogramCarregats = 0;													//número de programes carregats
int _gm_primeraPosMem = INI_MEM;												//posició pròxima lliure a memòria


/* _gm_initFS: inicializa el sistema de ficheros, devolviendo un valor booleano
					para indiciar si dicha inicialización ha tenido éxito; */
int _gm_initFS()
{
	return nitroFSInit(NULL);
}

//la funció _gm_programaEstaCarregat verifica si un programa ja està carregat y retorna la direcció inicial si es així
intFunc _gm_programaEstaCarregat(char *keyName) 
{
    intFunc progCarregat = 0;
	int i;
	for (i = 0; i < numprogramCarregats; i++) 
	{
        if (strcmp(programCarregats[i].nomPrograma, keyName) == 0) 
		{
            progCarregat = programCarregats[i].adrProgramaEstruct;						//si el programa es troba a la llista, retornem la seva adreça inicial en memòria
        }
    }
    return progCarregat;  																//si el programa no es troba a la llista, retornem 0
}

// funcio per calcular un valor múltiple de 4
Elf32_Word ferMultiple(Elf32_Word tSeg)
{
	int multiple;																		//per calcular el valor múltiple de 4 
	multiple = tSeg % 4;																//_gm_primeraPosMem multiple de 4, per al següent programa a partir de la suma del tamanySeg
	if (multiple != 0)
	{
		tSeg = tSeg + (4 - multiple);
	}
	return tSeg;
}

/* _gm_cargarPrograma: busca un fichero de nombre "(keyName).elf" dentro del
					directorio "/Programas/" del sistema de ficheros, y
					carga los segmentos de programa a partir de una posición de
					memoria libre, efectuando la reubicación de las referencias
					a los símbolos del programa, según el desplazamiento del
					código en la memoria destino;
	Parámetros:
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
		!= 0	->	dirección de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
intFunc _gm_cargarPrograma(char *keyName)
{
	char pathFit[20];															//per guardar el keyName rebut per paràmetre
	FILE *fitxer;																//per gestionar el fitxer .elf a obrir
	long tamany;																//per guardar el nombre d'elements que conté el fitxer .elf
	char *buffer;																//per emmagatzemar el contingut del fitxer .elf en memòria dinámica com una seqüència de caràcters																		//per emmagatzemar el contingut del fitxer .elf en memòria dinámica com una seqüència de caràcters								
	unsigned int offset;														//offset de la taula de segments
	unsigned short entry;														//primera instruccio a executar del programa
	unsigned short phentsize;													//tamany de cada entrada de la taula de segments
	unsigned short phnum;														//número d'entrades de la taula de segments
	int h = 0;																	//per guardar l'adreça final del programa a retornar
	int i;																		//bucle per recòrrer els segments	
	Elf32_Ehdr capcaleraElf;													//per emmagatzemar l'estructura correcta de la capçalera del .elf
	Elf32_Phdr taulaSeg;														//per emmagatzemar l'estructura correcta de la taula de segments
	Elf32_Word tamanySeg;														//per emmagatzemar el tamany memSize del programa
	intFunc adrProg;															//variable aux per guardar l'adressa del programa actual
	
	//verifiquem si el programa ja està carregat a memòria
    adrProg = _gm_programaEstaCarregat(keyName);  
	if (adrProg == 0) 															//si ens retorna 0, voldrà dir que encara no ha sigut carregat el programa actual
	{
        //buscar el fitxer
		sprintf(pathFit, "/Programas/%s.elf", keyName);							//guardem el path del "fitxer.elf" en una cadena de caràcters
		fitxer = fopen(pathFit, "rb"); 											//obrim el fitxer anterior en mode lectura binaria
		
		//si fitxer no trobat en programas del nitrofiles retornem 0, sinò passem a carregar-ho a memòria
		if (fitxer != NULL)					
		{
			//si fitxer trobat, calculem el tamany (quantitat d'elemnts) per saber el que es necessita per reservar-ho en memòria dinàmica
			fseek(fitxer, 0, SEEK_END);											//moure el punter del fitxer al final 
			tamany = ftell(fitxer);												//obtenir la posició actual del punter (que equivaldrà al tamany del fitxer=num d'elements)
			fseek(fitxer, 0, SEEK_SET);											//situem el punter al principi del fitxer per fer gestions posteriors
			
			//cargar el fitxer íntegramente dins d'un buffer de memòria dinámica per un accés al seu contingut més eficient 
			buffer = (char*) malloc(tamany);									//assignem dinàmicament memòria en el heap pel buffer de caràcters en funció del tamany del fitxer 	
			fread(buffer, sizeof(char), tamany, fitxer); 						//guardem el contingut del fitxer al buffer 								
			memcpy(&capcaleraElf, buffer, sizeof(Elf32_Ehdr));					//capçalera .elf
			
			offset = capcaleraElf.e_phoff;										//e_phoff (offset de la taula de segments)
			entry = capcaleraElf.e_entry;										//e_entry (primera instruccio a executar del programa)								
			phentsize = capcaleraElf.e_phentsize;								//e_phentsize (tamany de cada entrada de la taula de segments)
			phnum = capcaleraElf.e_phnum;										//e_phnum (número d'entrades de la taula de segments)
			
			if (phnum != 0)														//si té entrada en la taula de segments
			{
				memcpy(&taulaSeg, buffer + offset, sizeof(Elf32_Phdr)); 		//llegim la taula de segments del programa en l'estructura establerta pels segments			
				for (i = 0; i < phnum; i++) 									//guardarem cadascun dels segments del programa a cada iteració
				{ 										
					if (taulaSeg.p_type == PT_LOAD) 							//si l'entrada és de tipus PT_LOAD
					{									
						tamanySeg = taulaSeg.p_memsz;							//obtenim la informació del segment del programa actual (capcaleraElf)																		
						tamanySeg = ferMultiple(tamanySeg);						//fer càlcul múltiple per fer la próxima còpia a memòria
						if (_gm_primeraPosMem + tamanySeg <= END_MEM) 			//verifiquem si la posición de memòria _gm_primeraPosMem no supera la direcció final de memòria
						{
							//copia el contingut del segment de programa des del buffer en la dirección de memòria _gm_primeraPosMem (_gs_copiaMem(const void *source, void *dest, unsigned int numBytes))
							_gs_copiaMem((const void *) buffer + taulaSeg.p_offset, (void *) _gm_primeraPosMem, tamanySeg);
							//aplica reubicancions per ajustar referències
							_gm_reubicar(buffer, taulaSeg.p_paddr, (unsigned int *) _gm_primeraPosMem);	
							//direcció d'inici del programa a la memòria física, tenint en compte totes les reubicacions necessàries perquè el programa s'executi correctament des de la posició en memòria on s'ha carregat
							adrProg = (intFunc) (_gm_primeraPosMem + entry - taulaSeg.p_paddr);				
							//actualitzem memòria pel següent programa tenint en compte el tamany del segment actual carregat a memòria					
							h = (int)adrProg;						
							_gm_primeraPosMem += tamanySeg;
							intFunc funcPtr = adrProg; 								
							//assigna funcPtr a programCarregats[numprogramCarregats].adrProgramaEstruct
							programCarregats[numprogramCarregats].adrProgramaEstruct = funcPtr;
						}
					}			
					//comprovem si s'ha de seguir amb les iteracions segons si queden segments a tractar
					if (i+1 < phnum)																	
					{	
						offset = offset + phentsize;							//actualitzem offset per a que apunti al següent segment del .elf				
						fseek(fitxer, offset, SEEK_SET);						//actualitza apuntador per moure el apuntador del fitxer a la posició actual de l'offset
						fread(&taulaSeg, 1, sizeof(Elf32_Phdr), fitxer); 		//actualitzem capçalera pel següent segment
					}		
					//registra el programa com a carregat
					strncpy(programCarregats[numprogramCarregats].nomPrograma, keyName, 5);	//copiem el nom del programa a la llista de programes carregats
					programCarregats[numprogramCarregats].adrProgramaEstruct = adrProg;		//guardem la direcció d'inici del programa 
					numprogramCarregats++;													//incrementem el número de programes carregats
				}
			}
			fclose(fitxer);														//tanquem fitxer
			free(buffer);														//netejem buffer
		} 														
    }
	else																		//si el programa ja està carregat a memòria retornem la seva adreça
	{		
		h=(int)adrProg;		
	}																	
	return ((intFunc) h);														//una vegada acabem de tractar els segments, retornem l'adreça d'inici del programa 
																				//o un 0 en cas de que hagi un error
}