# Nombre del ejecutable
TARGET := ordh

# Directorio donde se encuentra la API de GARLIC
GARLICAPI := ../../GARLIC_API

# Opciones de compilación
ARCH := -march=armv5te -mlittle-endian
CFLAGS := -Wall -g0 $(ARCH) -mtune=arm946e-s -fomit-frame-pointer -ffast-math
ASFLAGS := -g0 $(ARCH) -mcpu=arm946e-s
LDFLAGS := --oformat elf32-littlearm --emit-relocs --gc-sections --strip-debug -z max-page-size=0x0400

# Define el nombre del archivo .elf en mayúsculas
UPPERCASE_TARGET := $(shell echo $(TARGET) | tr 'a-z' 'A-Z')

# Objetivos
$(UPPERCASE_TARGET).elf: $(TARGET).o heapsort_functions.o
	arm-none-eabi-ld $(LDFLAGS) $(TARGET).o heapsort_functions.o $(GARLICAPI)/GARLIC_API.o -o $(UPPERCASE_TARGET).elf

$(TARGET).o: $(TARGET).s
	arm-none-eabi-as $(ASFLAGS) $(TARGET).s -o $(TARGET).o

$(TARGET).s: $(TARGET).c heapsort.h
	arm-none-eabi-gcc $(CFLAGS) -S $(TARGET).c -I$(GARLICAPI) -o $(TARGET).s

heapsort_functions.o: heapsort_functions.c heapsort.h
	arm-none-eabi-gcc $(CFLAGS) -c heapsort_functions.c -I$(GARLICAPI) -o heapsort_functions.o

# Comando para limpiar
clean:
	@rm -fv $(TARGET).s
	@rm -fv $(TARGET).o
	@rm -fv heapsort_functions.o
	@rm -fv $(UPPERCASE_TARGET).elf