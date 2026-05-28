#include <stdio.h>
#include <stdlib.h>


//   TABLA DE TECLADO + VRAM
asm(".psect data, global, reloc=16");          // segmento de datos relocatable
asm("K_DATA:");                                // inicio tabla teclado
asm("DW 0100H,0040H"); // tecla 2              // patrón fila + máscara
asm("DW 0080H,0020H"); // tecla 4              // patrón fila + máscara
asm("DW 0200H,0040H"); // tecla 6              // patrón fila + máscara
asm("DW 0100H,0010H"); // tecla 8              // patrón fila + máscara
asm("DW 0010H,0080H"); // ESPACIO              // patrón fila + máscara
asm("DW 0800H,0800H"); // MAYÚS                // patrón fila + máscara
asm("DW 0080H,0200H"); // ENTER ↵             // patrón fila + máscara
asm("DW 0001H,0001H"); // BRK                  // patrón fila + máscara
asm("K_END:");                                 // fin tabla teclado
asm("K_COUNT EQU (K_END-K_DATA)/4");           // número automático de entradas (cada una 4 bytes)

asm("VRAM: .blkb 26*60");                      // buffer VRAM sistema

//   SECCIÓN DE CÓDIGO
asm(".psect text, global, reloc=16");          // segmento de código relocatable
//   RUTINA WAIT 
asm("_WAIT:");                                 // inicio WAIT
asm("PUSH CX");                                // guardar CX
asm("MOV CX, #9");                             // delay fijo
asm("_WAIT_LOOP:");                            // bucle delay
asm("LOOP _WAIT_LOOP");                        // decrementa CX hasta 0
asm("POP CX");                                 // restaurar CX
asm("RET");                                    // retorno
//  SUBRUTINA KSUB 
asm("_KSUB:");                                 // inicio subrutina teclado
asm("OUT [DX], AX");                           // enviar patrón al teclado
asm("CALL _WAIT");                             // estabilización hardware
asm("MOV DX, #202H");                          // puerto entrada teclado (KIN)
asm("IN AX, [DX]");                            // leer estado teclado
asm("MOV DX, #200H");                          // restaurar puerto salida (KOUT)
asm("TEST AX, BX");                            // comprobar si tecla activa
asm("JZ _KSJP1");                              // si no hay tecla saltar
asm("STC");                                    // marcar tecla pulsada en CF
asm("_KSJP1:");                                // etiqueta salto
asm("RCR CH, #1");                             // guardar bit en acumulador CH
asm("RET");                                    // retorno subrutina

//VARIABLES GLOBALES C89

unsigned char result;                          // resultado final tecla


int inkey()
{
// Guardar registros */
    asm("push si");                            // guardar SI
    asm("push dx");                            // guardar DX
    asm("push cx");                            // guardar CX
    asm("push bx");                            // guardar BX
// Deshabilitar interrupciones */
    asm("cli");                                // desactivar interrupciones
// Reset teclado 
    asm("mov dx, #200H");                      // puerto salida teclado
    asm("mov ax, #1FFFH");                     // patrón inicial teclado
    asm("out [dx], ax");                       // enviar patrón
    asm("xor ax, ax");                         // limpiar AX
    asm("out [dx], ax");                       // reset teclado
// Preparación escaneo 
    asm("xor ch, ch");                         // CH = acumulador resultado teclas
    asm("mov cl, #K_COUNT");                   // CL = número de entradas
    asm("mov si, #K_DATA");                    // SI apunta tabla teclado
// BUCLE PRINCIPAL ESCANEO
    asm("_INLP1:");                            // inicio loop
    asm("mov ax, [si]");                       // cargar patrón teclado
    asm("add si, #2");                         // avanzar SI
    asm("mov bx, [si]");                       // cargar máscara tecla
    asm("add si, #2");                         // avanzar SI
    asm("call _KSUB");                         // comprobar tecla
    asm("dec cl");                             // decrementar contador
    asm("jnz _INLP1");                         // repetir si no cero
//  FINALIZACIÓN ESCANEO
    asm("mov dx, #200H");                      // puerto teclado
    asm("mov ax, #7FFH");                      // patrón final
    asm("out [dx], ax");                       // enviar finalización
    asm("call _WAIT");                         // estabilizar hardware
// Controlador teclado 
    asm("mov dx, #204H");                      // puerto control KCTL
    asm("mov al, #3");                         // configuración 1
    asm("out [dx], al");                       // enviar
    asm("dec al");                             // cambiar valor
    asm("out [dx], al");                       // enviar configuración 2
// Guardar resultado 
    asm("mov al, ch");                         // mover resultado a AL
    asm("sti");                                // reactivar interrupciones
    asm("mov _result, al");                    // guardar en variable C
//Restaurar registros 
    asm("pop bx");                             // restaurar BX
    asm("pop cx");                             // restaurar CX
    asm("pop dx");                             // restaurar DX
    asm("pop si");                             // restaurar SI
// LIMPIEZA FINAL
    asm("push ax");                            // guardar AX
    asm("push dx");                            // guardar DX
    asm("mov dx, #204H");                      // puerto control
    asm("xor ax, ax");                         // limpiar AX
    asm("out [dx], al");                       // reset control
    asm("mov dx, #200H");                      // puerto teclado
    asm("out [dx], ax");                       // reset salida teclado
    asm("call _WAIT");                         // estabilizar
    asm("pop dx");                             // restaurar DX
    asm("pop ax");                             // restaurar AX
return result;                                 // devolver tecla

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
	if(result == 128) break; 
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
