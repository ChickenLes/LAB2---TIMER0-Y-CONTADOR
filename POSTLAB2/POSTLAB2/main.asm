;-----------------------------------------------
; Universidad del Valle de Guatemala
; IE2023: Programacion de Microcontroladores
; CONTADOR_POSTLAB.asm
; Autor: ANTHONY ALEJANDRO BOTEO L�PEZ
; Proyecto: LABORATORIO_2
; Hardware: ATMEGA328P
; Creado: 14/02/2025 
; Ultima modificacion: 20/02/2025
; Descripci�n:
;-----------------------------------------------

/////////////CONFIGURACION GENERAL//////////////////////////////////////
.include "M328PDEF.inc"

.cseg
.org	0x0000				//VECTOR DE RESET
		RJMP	SETUP
.org	0x0020				//VECTOR DE INTERRUPCION TIMER0 OVERFLOW
		RJMP	CONTADOR

//////////////////////////////////DEFINICION VARIABLES GLOBALES/////////////

.def	DISP_COUNTER = R18  //DEFINICION DE VARIABLE GLOBAL EN REGISTRO R18
.def	LED_COUNTER = R22   //DEFINICION DE VARIABLE GLOBAL EN REGISTRO R22
.def	COUNTER = R23		//DEFINICION DE VARIABLE GLOBAL EN REGISTRO R23


/////////////////////////DATOS DISPLAY/////////////////////////////////////
DATA:

	//.DB	 0x3E,0x30,0x6D,0x79,0x33,0x5B,0x5F,0x70,0x7F,0x7B,0x77,0x7F,0x4E,0x7E,0x4F,0x47
	//.DB	 0x7E, 0x30, 0x6D,0x79,0x33,0x5B,0x5F,0x70,0x7F,0x7B,0x77,0x7F,0x4E,0x7E,0x4F,0x47
	.DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

////////////////////////////////////CONFIGURANDO EL MCU//////////////////////
SETUP:

	//////////////////////CONFIGURACION TIMER///////////////////////////////
	LDI R16, (1 << CLKPCE)    ; Habilitar cambios en CLKPR (CLKPCE = 1)
	STS CLKPR, R16			  ; Escribir en CLKPR para desbloquear cambios
	LDI R16, 0b00000100       ; Configurar prescaler a 8 (8 MHz / 8 = 1 MHz)
	STS CLKPR, R16            ; Aplicar prescaler

	//////////////////INICIAR TIMER0 E INTERRUPCIONES////////////////////////
	
	//PILA
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	//CONFIGURANDO SALIDAS
	LDI		R16, 0xFF
	OUT		DDRD, R16	//TODO PORTD COMO SALIDA
	OUT		DDRB, R16	//TODO PORTB COMO SALIDA
	LDI		R16, 0x00
	OUT		PORTD,	R16	//TODO PORTD PULL UP DESACTIVADO
	OUT		PORTB, R16  //TODO PORTD PULL UP DESACTIVADO
	 
	//CONFIGURANDO INPUTS
	LDI		R16, 0x20
	OUT		DDRC, R16	//TODO PORTC COMO INPUT
	LDI		R16, 0x1F
	OUT		PORTC, R16	//TODO PORTC PULL UP ACTIVADOD

	//PUNTERO
	LDI		ZH, HIGH(DATA << 1)
	LDI		ZL, LOW(DATA << 1)
	LPM		R16, Z
	OUT		PORTD, R16

	//APAGAR LEDS ARDUINO
	LDI		R16, 0x00
	STS		UCSR0B, R16

	//CONFIGURACIONES INICIALES
	LDI		R17, 0xFF		//GUARDA EL VALOR DEL CONTADOR
	LDI		R18, 0x00		//CONTADOR DE LOS LEDS
	LDI		COUNTER, 0x00	//CONTADOR INTERNO DEL TIMER0
	LDI		R22, 0x00
	OUT		PORTD, R18
	OUT		PORTB, R22

	//INICIAR VARIABLES
	CLR		DISP_COUNTER
	CLR		LED_COUNTER
	CLR		COUNTER

	//LLAMAR A TIMER0
	CALL	INIT_TMR0	
	SEI					//HABILITAR INTERRUPCIONES

	//MOSTRAR EL VALOR ACTUAL DEL DISPLAY(TIENE QUE SER 0)
	CALL	DISPLAY

////////////////////////////////MAIN LOOP/////////////////////////
MAIN: 

	CALL ANTI_REBOTE	//INICIAR ANTIREBOTE
	RJMP MAIN

////////////////////////////INIT_TMR0///////////////////////////
INIT_TMR0:

	LDI		R16, (1<<CS01) | (1<<CS00) //PRESCALER 64
	OUT		TCCR0B, R16				   //ACTIVA EL PRESCALER EN TCCR0B
	LDI		R16, 100				   //VALOR DESDE DONDE INICIAMOS
	OUT		TCNT0, R16				   //CARGA EL VALOR A TCNT0 

	//HABILITAR INTERRUPCION DE OVERFLOW
	LDI		R16, (1 << TOIE0)			//INTERRUPCION POR OVERFLOW
	STS		TIMSK0, R16					//HABILITAR MASCARA
	RET


	
///////////////////////////////CONTADOR////////////////////////////
CONTADOR:
	
	PUSH	R16					//GUARDAR EL VALOR DE R16
	IN		R16, SREG			//GUARDAMOS LAS BANDERAS EN R16
	PUSH	R16					//VOLVEMOS A GUARDAR EL VALOR DE R16
	PUSH	R17					//GUARDAR EL VALOR DEL PUSH BOTTOM ACTUAL


	//VALOR INICIAL
	
	LDI		R16, 100			// VALOR QUE SE CARGA AL TEMPORIZADOR PARA CONTAR
	OUT		TCNT0, R16
	
	INC		COUNTER				
	CPI		COUNTER, 100		//HACE LA COMPARACI�N SI ES IGUAL A 10(QUE TAN RAPIDO CUENTA)
	BRNE	CONTADOR_EXIT		//Z = 0, SALTA A CONTADOR_EXIT. Z = 1, NO SALTA.
	CLR		COUNTER				//SI COUNTER LLEGA A 10 EL COUNTER SE SETEA EN 0

	//CONTADOR 4 BITS
	
	ANDI	LED_COUNTER, 0x0F	//SOLO MANTIENE LOS 4 BITS
		
	//COMPARANDO EL CONTADOR LED Y DISPLAY
	MOV		R16, LED_COUNTER	//COPIA EL VALOR DE LED_COUNTER EN R16
	CP		R16, DISP_COUNTER	//COMPARA SI R16 Y DISP_COUNTER SON IGUALES
	BRNE	NO_COIN			//SI Z = 0, SALTA A NO_COIN. SI Z = 1, NO SALTA.

	//LIMPIANDO EL CONTADOR LED 4 BITS
	CLR		LED_COUNTER			//SETEA EN 0 LED_COUNTER
	IN		R16, PORTC			//LEE LO QUE HAY EN EL PUERTO
	LDI		R17, (1<<PC5)		//ASIGNA 0b00"1"00000 PC5 
	EOR		R16, R17			//HACE EL TOGGLE PARA VERIFICAR SI EST� ENCENDIDO/APAGADO DURANTE UN CICLO
	OUT		PORTC, R16			//LA SALIDA DEL XOR EN R16 EN EL PUERTOC

				
//MODULO DE NO COINCIDENCIA
NO_COIN:
	OUT		PORTB, R22			//LO QUE SE ENCUENTRA EN R22 SE DEBE ASIGNAR AL PORTB

//HACER UN MODULO QUE NOS HAGA SALIR DE LA INTERRUPCION
CONTADOR_EXIT:

	POP		R17					//RECUPERAR EL VALOR EN LA PILA ANTES DE LA INTERRUPECION
	POP		R16					//RECUEPERAR EL VALOR EN LA PILA ANTES D ELA INTERRUPCION
	OUT		SREG, R16			//LAS BANDERAS RECUPERADAS LUEGO DEL POP SE ASIGNAN A SREG(BANDERAS)
	POP		R16					//SE RECUPERA EL VALOR ORIGINAL
	RETI


/////////////////////////////////ANTI_REBOTE///////////////////////////
ANTI_REBOTE:

	//ANTIREBOTE
	IN		R16, PINC
	CP		R17, R16
	BREQ	ANTI_REBOTE
	
	CALL	DELAY
	IN		R16, PINC	//VERIFICAR QUE SI EL ESTADO DE LECTURA ES CORRECTO	
	CP		R17, R16
	BREQ	ANTI_REBOTE

	MOV		R17, R16	//GUARDA EL NUEVO ESTADO(POR SI SE MANTIENE PRESIONADO)


	CALL	CONTROL1	//CONTROL SUMA
	RET
//////////////////////CONTROL PUSH BOTTOM////////////////////////////////
CONTROL1:

	CPI		R16, 0x1E	//COMPARA EL VALOR CON 0001 111"0" EN PINC0
	BREQ	AUMENTO

	CPI		R16, 0x1D	//COMPARA EL VALOR CON 0001 11"0"1 EN PINC1
	BREQ	DECREMENTO
	RET

//////////////////////////////////AUMENTO-DECREMENTO-DISPLAY///////////////////
AUMENTO:

	INC		DISP_COUNTER
	CPI 	DISP_COUNTER, 0x10	//COMPARA CON 16
	BRNE	DISPLAY		
	LDI		DISP_COUNTER, 0x00
	RJMP	DISPLAY
	
DECREMENTO:

	DEC		DISP_COUNTER
	BRPL	DISPLAY		//VEMOS LA BANDERA NEGATIVA N = 0 SALTA, N = 1 NO SALTA
	LDI		DISP_COUNTER, 0x0F
	

DISPLAY:

	LDI ZH, HIGH(DATA << 1)
	LDI ZL, LOW(DATA << 1)	//PUNTERO APUNTA A LA TABLA Z
	ADD ZL, DISP_COUNTER				//A�adir el valor del contador R20 al puntero Z para obtener la salida en PORTD
	LPM R16, Z				//Copia el valor guardado en el nuevo Z
	OUT PORTD, R16			//Modifico el 7 segmentos en PORTD

	RJMP	ANTI_REBOTE




/////////////////////////////// DELAY /////////////////////////
DELAY:
    LDI     R19, 0xFF
SUB_DELAY1:
    DEC     R19
    CPI     R19, 0
    BRNE    SUB_DELAY1
    LDI     R19, 0xFF
SUB_DELAY2:
	DEC     R19
    CPI     R19, 0
    BRNE    SUB_DELAY2
    LDI     R19, 0xFF
SUB_DELAY3:
	DEC     R19
    CPI     R19, 0
    BRNE    SUB_DELAY3
	RET