#include <stdio.h>
#include <stdlib.h>


	asm(".psect data, global, reloc=16");
	asm("KDATA:");
	asm("DW 0100H,0040H"); // tecla 2
	asm("DW 0080H,0020H"); // tecla 4
	asm("DW 0200H,0040H"); // tecla 6
	asm("DW 0100H,0010H"); // tecla 8
	asm("DW 0010H,0080H"); // ESPACIO
	asm("DW 0800H,0800H"); // MAYÚS
	asm("DW 0080H,0200H"); // ENTER ↵
	asm("DW 0001H,0001H"); // BRK
	asm("VRAM: .blkb 26*60");    

unsigned int result;

int inkey(){
/* Guardar registros */
    asm("push si"); 
    asm("push dx"); 
    asm("push cx"); 
    asm("push bx"); 
/* Deshabilitar interrupciones */
	asm("cli");				// Deshabilita interrupciones
	asm("mov dx, #200H");	// DX = puerto de salida del teclado (KOUT)
	asm("mov ax, #1FFFH");	// AX = patrón inicial
	asm("out [dx], ax");	// Envía patrón al teclado
	asm("xor ax, ax");		// AX = 0
	asm("out [dx], ax");	// Envía 0 al teclado (reset)	 
/* Preparación del escaneo de teclas */
    asm("xor ch, ch");		// CH = 0 (acumulador de bits de teclas)
	asm("mov cx, #8");		// CX = 8 (número de pares a escanear)
	asm("mov si, #KDATA");	// SI apunta a tabla de datos del teclado
/*    Bucle principal de escaneo */
	asm("_INLP1:"); 
	asm("mov ax, [si]");	// Carga patrón de teclado
	asm("add si, #2");		// Avanza al siguiente elemento
	asm("mov bx, [si]");	// Carga máscara de verificación
	asm("add si, #2");		// Avanza al siguiente elemento
	asm("CALL _KSUB");		// Llama a subrutina de verificación
	asm("DEC CL");			// Decrementa contador
	asm("JNZ _INLP1");		// Repite si no es cero
 /* --- Finalización del escaneo --- */
    asm("MOV AX, #7FFH"); 
	asm("OUT [DX], AX");	// Envía patrón de finalización
	asm("CALL _WAIT");		// Espera estabilización
/* Configuración del controlador de teclado */
	asm("MOV DX, #204H");	// DX = puerto de control (KCTL)
	asm("MOV AL, #3");
	asm("OUT [DX], AL");	// Configura controlador
	asm("DEC AL");
	asm("OUT [DX], AL");	// Otra configuración
/* Resultado y restauración */
	asm("mov AL, CH");		// Mueve resultado a AL
	asm("STI");				// Habilita interrupciones
	asm("mov _result, AL");	// Guarda resultado en variable
/* Restauración de registros */
	asm("pop bx"); 
	asm("pop cx"); 
	asm("pop dx"); 
	asm("pop si"); 
/* Limpieza FINAL (sin afectar registros usados por el caller) */
	asm("push ax");       // Preservar AX (por si acaso)
	asm("push dx");       // Preservar DX
	asm("mov dx, #204H"); // KCTL
	asm("xor ax, ax");    // AX = 0 (comando de reset)
	asm("out [dx], al");  // Enviar 0 a KCTL
	asm("mov dx, #200H"); // KOUT
	asm("out [dx], ax");  // Enviar 0 a KOUT
	asm("call _WAIT");    // Esperar estabilización (opcional)
	asm("pop dx");        // Restaurar DX
	asm("pop ax");        // Restaurar AX
/* Rutina de espera  */	
    asm("_WAIT:");               // Nueva rutina de espera    
    asm("PUSH CX");          // Preserva CX (¡importante para bucles externos!)   
    asm("MOV CX, #8");       // 9 iteraciones (ajusta según necesidad)    
	asm("_WAIT_LOOP:"); 
    asm("LOOP _WAIT_LOOP");  // CX -= 1, salta si CX != 0    
    asm("POP CX");           // Restaura CX   
    asm("RET "); 
/* Subrutina de verificación de tecla */
	asm("_KSUB:"); 
	asm("OUT [DX], AX");	// Envía patrón al teclado
	asm("CALL _WAIT");		// Espera
	asm("MOV DX, #202H");	// DX = puerto de entrada (KIN)
	asm("IN AX, [DX]");		// Lee estado del teclado
	asm("MOV DX, #200H");	// Restaura DX a KOUT
	asm("TEST AX, BX");		// Verifica si la tecla está presionada
	asm("JZ _KSJP1");		// Salta si no está presionada
	asm("STC");				// Marca tecla presionada (CF=1)
	asm("_KSJP1:"); 
	asm("RCR CH, #1");		// Almacena resultado en CH
	asm("RET");
return result;
}

void jugar(){

	while(1) {
        inkey();
        if(result != 0) {
        /* Procesar tecla pulsada */			
			printf("Tecla  %d \n",result);		
        }
	if(result == 27) break; 	
	if(result == 134) break; 
    }
}



int main() {
	
printf("\n");

	while (1) {
		jugar(); 
		break;
	}

return 0;
}
