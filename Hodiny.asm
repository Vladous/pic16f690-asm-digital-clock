
;================================================================================
; JEDNODUCHE DIGITALNI HODINY S LCD DISPLEJEM 2x16
; PIC16F690, LCD HD44780 (4-bitový mód)
; 
; Verze: 1.0 | Vytvořeno: 2014 | Poslední úprava: 2026
;================================================================================
; 
; POPIS:
;   Jednoduchý projekt středověkého hodin s PIC16F690 a LCD displejem 2x16 znaků.
;   Program umožňuje:
;   - Nastavení času pomocí tří tlačítek (hodiny, minuty, potvrzení)
;   - Zobrazení aktuálního času (HH:MM:SS)
;   - České znaky na displeji
;
; FORMÁT ČASU:
;   Čas je uložen v ASCII znakové reprezentaci:
;   - '0' (0x30) až '5' pro desítky (minut/sekund)
;   - '0' (0x30) až '9' (0x39) pro jednotky
;   - Příklad: HOD1='1', HOD0='3' = 13 hodin
;
; KOMPILACE:
;   MPASM (Microchip Assembler) nebo kompatibilní assembler
;   Procesor: PIC16F690
;   Frekvence krystalu: 4MHz
;
;================================================================================
; SCHÉMA ZAPOJENÍ:
; ─────────────────────────────────────────────────────────────────────────────
; PORTA (výstup):
;   RA0 (pin 17) ──> LCD Enable (E)
;   RA1 (pin 18) ──> LCD Register Select (RS): 0=instrukce, 1=data
;
; PORTC (výstup - 4-bitový mód):
;   RC0-RC3 (piny 13-16) ──> LCD Data (DB4-DB7)
;
; PORTB (vstup - tlačítka):
;   RB4 (pin 25) ──> Tlačítko 1: +1 hodina
;   RB5 (pin 24) ──> Tlačítko 2: +1 minuta
;   RB6 (pin 23) ──> Tlačítko 3: START (potvrzení nastavení)
;
; LCD displej HD44780:
;   GND ───────> Zem
;   +5V ───────> Napájení
;   V0 ────────> Kontrast (trimr 10kΩ)
;   RS ───────> RA1
;   RW ───────> GND (pouze čtení, zápis)
;   E ────────> RA0
;   DB4-DB7 ──> RC0-RC3
;   /LED+ ────> +5V (přes rezistor 220Ω)
;   /LED- ────> GND
; ─────────────────────────────────────────────────────────────────────────────

list	P=16F690, R=DEC
include p16f690.inc 

; Konfigurace PIC16F690
__config (_XT_OSC & _WDT_OFF & _PWRTE_ON & _MCLRE_ON & _CP_ON & _BOR_ON & _IESO_OFF & _FCMEN_OFF)

RAM			equ	20h		; pocatek RAM pameti

; Cas - ulozeny v ASCII znakove reprezentaci (0x30='0', 0x39='9')
SEC0		equ RAM+5	; sekundy - jednotky (0-9 jako ASCII)
SEC1		equ RAM+6	; sekundy - desatky (0-5 jako ASCII) 
MIN0		equ RAM+7	; minuty - jednotky (0-9 jako ASCII)
MIN1		equ RAM+8	; minuty - desatky (0-5 jako ASCII)
HOD0		equ RAM+9	; hodiny - jednotky (0-9 jako ASCII)
HOD1		equ RAM+10	; hodiny - desatky (0-2 jako ASCII)
KLAVESA		equ RAM+11	; Stavem tlacitka (nepoužito v tuto chvili)

; Pracovni registry pro cekacie smycky (timery) na krystalu 4MHz
TMP0		equ	RAM+12	; vnitřní čitač
TMP1		equ	RAM+13	; vnější čitač
TMP2		equ	RAM+14	; pomocná proměnná
TMP3		equ	RAM+15	; největší čitač

; Pracovni registry pro LCD komunikaci
TEXT		equ	RAM+20	; index do tabulky textu
ZNAK		equ	RAM+21	; aktuální znak k zobrazení
ADRESA		equ	RAM+22	; adresa znaku v LCD paměti (0x40-0x7F)
CISLO		equ	RAM+23	; pomocná číselná proměnná

;================================================================================
; KONSTANTY - ASCII ZNAKY PRO DIGITY A LCD PŘÍKAZY
;================================================================================
ASCII_0			equ 0x30		; ASCII '0' - pocatek cifer
ASCII_9_PLUS		equ 0x3A		; Detekce preteceni - po '9' (0x39+1)
ASCII_5_PLUS		equ 0x36		; Detekce preteceni - po '5' (pro 60 sekund/minut)

; LCD príkazy - adresy v DDRAM
LCD_CLEAR			equ 0x01		; Vymazat displej, kurzor na home
LCD_HOME			equ 0x80		; Radek 1, pozice 0
LCD_LINE2			equ 0xC0		; Radek 2, pozice 0

; LCD EEPROM - vlastni ceske znaky
LCD_CHAR_ADDR_START	equ 0x40		; Zacatek vlastnich znaku v LCD CGRAM

; Port definice - LCD
#define	E		PORTA,0			; LCD Enable signál
#define	RS		PORTA,1			; LCD Register Select: 0=instrukce, 1=data
#define	P_VYS	PORTC			; LCD datove piny (RC0-RC3 = DB4-DB7)


	org	0x2100			; prednastaveni dat v pameti EEPROM
	de	0x0A, 0x04, 0x0F, 0x10, 0x0E, 0x01, 0x1E, 0x00	; znak0 = 40h  (kod 0x00) - š
	de	0x1D, 0x09, 0x0D, 0x13, 0x11, 0x13, 0x0D, 0x00	; znak1 = 48h  (kod 0x01) - ď
	de	0x0A, 0x04, 0x0E, 0x11, 0x1F, 0x10, 0x0E, 0x00	; znak2 = 50h  (kod 0x02) - ě
	de	0x0A, 0x04, 0x0E, 0x10, 0x0E, 0x01, 0x1E, 0x00	; znak3 = 58h  (kod 0x03) - š
	de	0x0A, 0x04, 0x0E, 0x10, 0x10, 0x11, 0x0E, 0x00	; znak4 = 60h  (kod 0x04) - č
	de	0x0A, 0x04, 0x16, 0x19, 0x10, 0x10, 0x10, 0x00	; znak5 = 68h  (kod 0x05) - ř
	de	0x0A, 0x04, 0x1F, 0x02, 0x04, 0x08, 0x1F, 0x00	; znak6 = 70h  (kod 0x06) - ž
	de	0x00, 0x04, 0x0E, 0x0E, 0x0E, 0x1F, 0x1F, 0x04	; znak8 = 78h  (kod 0x07) - zvonek (bell)

	org	0x0000			; zacatek programu
	goto	INIT		; skok na zacatek inicializaci

;**************************************************************************
TAB_TXT	addwf	PCL,F
	retlw	'V'			; 0
	retlw	'l'
	retlw	'a'
	retlw	80h			;'ď'
	retlw	'o'			; 4
	retlw	'u'
	retlw	80h			;'š'
	retlw	' '			; 7
	retlw	't'
	retlw	'i'
	retlw	'm'
	retlw	'e'
	retlw	' '
	retlw	'L'
	retlw	'C'
	retlw	'D'
	retlw	80h			; konec textu
;-------------------------------
	retlw	'v'			; 17
	retlw	'e'
	retlw	'r'
	retlw	'z'
	retlw	'e'
	retlw	' '
	retlw	'1'
	retlw	'.'
	retlw	'0'
	retlw	' '
	retlw	'2'
	retlw	'0'
	retlw	'1'
	retlw	'4'
	retlw	80h			; konec textu
;-------------------------------
	retlw	'C'			; 32
	retlw	'Z'
	retlw	' '
	retlw	'z'
	retlw	'n'
	retlw	'a'
	retlw	'k'
	retlw	'y'
	retlw	80h			; konec textu
;-------------------------------
	retlw	'N'			; 41
	retlw	'a'
	retlw	's'
	retlw	't'
	retlw	'a'
	retlw	'v'
	retlw	' '
	retlw	80h			; 'č'
	retlw	'a'			; 49
	retlw	's'
	retlw	' '
	retlw	80h			; konec textu
	retlw	'H'			; 53
	retlw	'H'
	retlw	'/'
	retlw	'M'
	retlw	'M'
	retlw	80h			; konec textu
;-------------------------------
	retlw	'V'			; 59
	retlw	'l'
	retlw	'a'
	retlw	80h			; 'ď'
	retlw	'o'			; 63
	retlw	'u'
	retlw	80h			;'š'
	retlw	' '			; 66
	retlw	't'
	retlw	'i'
	retlw	'm'
	retlw	'e'
	retlw	' '
	retlw	80h			; konec textu
;**************************************************************************
TAB_CZ	addwf	PCL,F	; tabulka ceskzch znaku pro LCD displej
;       ------------------------
	retlw	0x0A		; znak0 = 40h	š
	retlw	0x04
	retlw	0x0F
	retlw	0x10
	retlw	0x0E
	retlw	0x01
	retlw	0x1E
	retlw	0x00
;       ------------------------
	retlw	0x1D		; znak1 = 48h	ď
	retlw	0x09
	retlw	0x0D
	retlw	0x13
	retlw	0x11
	retlw	0x13
	retlw	0x0D
	retlw	0x00
;       ------------------------
	retlw	0x0A		; znak2 = 50h	ý
	retlw	0x04
	retlw	0x0E
	retlw	0x11
	retlw	0x1F
	retlw	0x10
	retlw	0x0E
	retlw	0x00
;       ------------------------
	retlw	0x0A		; znak3 = 58h	š
	retlw	0x04
	retlw	0x0E
	retlw	0x10
	retlw	0x0E
	retlw	0x01
	retlw	0x1E
	retlw	0x00
;       ------------------------
	retlw	0x0A		; znak4 = 60h	č
	retlw	0x04
	retlw	0x0E
	retlw	0x10
	retlw	0x10
	retlw	0x11
	retlw	0x0E
	retlw	0x00
;       ------------------------
	retlw	0x0A		; znak5 = 68h	ř
	retlw	0x04
	retlw	0x16
	retlw	0x19
	retlw	0x10
	retlw	0x10
	retlw	0x10
	retlw	0x00
;       ------------------------
	retlw	0x0A		; znak6 = 70h	ž
	retlw	0x04
	retlw	0x1F
	retlw	0x02
	retlw	0x04
	retlw	0x08
	retlw	0x1F
	retlw	0x00
;       ------------------------
	retlw	0x00		; znak8 = 78h  - zvonek (bell)
	retlw	0x04
	retlw	0x0E
	retlw	0x0E
	retlw	0x0E
	retlw	0x1F
	retlw	0x1F
	retlw	0x04
;**************************************************************************
INIT
	; Inicializace banků a portů
	bcf STATUS,RP0		; Zvolení banky 0
	bcf STATUS,RP1
	clrf PORTA			; Vymazat porty
	clrf PORTB
	clrf P_VYS
	
	; Nastavení směru pinů
	bsf STATUS,RP0		; Banka 1
	bcf OPTION_REG,7	; Zapnout PULL-UP rezistory na RB
	movlw	0xF0		; RB4-RB7 jako vstup (tlačítka), RB0-RB3 jako výstup
	movwf TRISB
	movlw	0x00		; Všechny piny PORTA jako výstup
	movwf TRISA
	movwf TRISC			; Všechny piny PORTC jako výstup (LCD data)
	bcf STATUS,RP0		; Zpět do banky 0
	
	; Vypnout analogové vstupy
	bsf STATUS,RP1		; Banka 2
	movwf ANSEL			; Digitální režim
	movwf ANSELH
	bcf STATUS,RP1		; Zpět do banky 0
	
	; Inicializace času na 00:00:00 (ASCII reprezentace)
	movlw ASCII_0		; Nastavit všechny časy na '0'
	movwf HOD1
	movwf HOD0
	movwf MIN1
	movwf MIN0
	movwf SEC1
	movwf SEC0			
	
	; Inicializace periferií
	call	INI_LCD			; Inicializovat LCD displej
	call	CESTINA			; Nahrát české znaky do LCD paměti
	
	; Zobrazit uvítání a verzi
	call	SHOW_VERSION	; Zobrazit software verzi
	call	DELAY_2s		; Čekat 2 sekundy
	
	; Přejít do režimu nastavování času
	goto	SETUP_TIME_MODE

;================================================================================
; REŽIM NASTAVOVÁNÍ ČASU - Tlačítka na PORTB (RB4, RB5, RB6)
; RB4 (pin 25): +1 hodina  |  RB5 (pin 24): +1 minuta  |  RB6 (pin 23): START
;================================================================================
SETUP_TIME_MODE
	call	C_LCD		; Vymazat displej
	call	DISPLAY_TIME	; Zobrazit čas na 1. řádku
	call	LINE2
	movlw	.41			; Text "Nastav čas"
	call	WR_TEXT
	movlw	0x04		; Vlastní znak (háček ù)
	call	WR_DATA
	movlw	.49			; Pokračování textu
	call	WR_TEXT

;--- Hlavní smyčka čekání na tlačítka ---
BUTTON_LOOP
	movf PORTB,W		; Přečíst stav tlačítek
	xorlw 0xEF			; Porovnat s RB4 stisknutý (ostatní HIGH)
	BTFSS STATUS,Z
	goto CHECK_BTN2
	; --- Tlačítko 1 stisknuté: +1 hodina ---
	call INCREMENT_HOUR	; Zvýšit hodinu
	call DISPLAY_TIME	; Aktualizovat displej
	call DELAY_500ms	; Debouncing
	
CHECK_BTN2
	movf PORTB,W
	xorlw 0xDF			; Porovnat s RB5 stisknutý
	BTFSS STATUS,Z
	goto CHECK_BTN3
	; --- Tlačítko 2 stisknuté: +1 minuta ---
	call INCREMENT_MINUTE	; Zvýšit minutu
	call DISPLAY_TIME	; Aktualizovat displej
	call DELAY_500ms	; Debouncing
	
CHECK_BTN3
	movf PORTB,W
	xorlw 0xBF			; Porovnat s RB6 stisknutý
	BTFSC STATUS,Z
	goto MAIN_CLOCK		; Tlačítko 3: START - přejít do běhu hodin
	
	goto BUTTON_LOOP	; Čekat na další tlačítko



;================================================================================
; HLAVNÍ SMYČKA - BĚH HODIN
;================================================================================
MAIN_CLOCK
	call	DISPLAY_TIME	; Zobrazit čas (HH:MM:SS) na 1. řádku
	
	; Zobrazit text na 2. řádku - "Vlášťuji se [ikona]"
	call	LINE2
	movlw	.59			; Text "Vlášť"
	call	WR_TEXT
	movlw	0x01		; Vlastní znak (ů)
	call	WR_DATA
	movlw	.63			; Text "ujeme se"
	call	WR_TEXT
	movlw	0x00		; Vlastní znak (háček)
	call	WR_DATA
	movlw	.66			; Pokračování
	call	WR_TEXT
	
	; Inkrementovat sekundy a čekat 1 vteřinu
	call INCREMENT_SECOND	; Přičíst 1 sekundu
	call DELAY_1s		; Čekat 1 vteřinu
	goto	MAIN_CLOCK	; Opakovat



;================================================================================
; FUNKCE PRO PRÁCI S ČASEM - INKREMENTACE ÚDAJŮ S KONTROLOU PŘETEČENÍ
;================================================================================

; --- Funkce: Inkrementovat SEKUNDU ---
INCREMENT_SECOND
	incf SEC0,F						; SEC0 = SEC0 + 1
	movf SEC0,W						; Přečíst SEC0 do W
	xorlw ASCII_9_PLUS				; Porovnat (SEC0 = 0x3A = ':')
	btfss STATUS,Z					; Pokud se NEJROVNAJÍ, skip next
	return							; Vrátit se (SEC0 není v přetečení)
	
	; SEC0 dosáhl 0x3A - sekundy jednotky přetekly
	movlw ASCII_0					; Resetovat na '0'
	movwf SEC0
	incf SEC1,F						; Inkrementovat desítky
	movf SEC1,W
	xorlw ASCII_5_PLUS				; Porovnat (SEC1 = 0x36 = po '5')
	btfss STATUS,Z
	return
	
	; SEC1 dosáhla 0x36 - sekundy desetky přetekly (60 sekund)
	movlw ASCII_0
	movwf SEC1
	; Pokračuj do inkrementace minut
	
; --- Funkce: Inkrementovat MINUTU ---
INCREMENT_MINUTE
	incf MIN0,F
	movf MIN0,W
	xorlw ASCII_9_PLUS
	btfss STATUS,Z
	return
	
	movlw ASCII_0
	movwf MIN0
	incf MIN1,F
	movf MIN1,W
	xorlw ASCII_5_PLUS
	btfss STATUS,Z
	return
	
	movlw ASCII_0
	movwf MIN1
	; Pokračuj do inkrementace hodin
	
; --- Funkce: Inkrementovat HODINU ---
INCREMENT_HOUR
	incf HOD0,F
	movf HOD0,W
	xorlw ASCII_9_PLUS
	btfss STATUS,Z
	return
	
	movlw ASCII_0
	movwf HOD0
	incf HOD1,F
	
	; Kontrola: 24 hodin = 0x32 0x34 (ASCII '2' '4')
	movf HOD0,W
	xorlw 0x34						; Porovnat HOD0 s ASCII '4'
	btfss STATUS,Z
	return
	
	movf HOD1,W
	xorlw 0x32						; Porovnat HOD1 s ASCII '2'
	btfss STATUS,Z
	return
	
	; Dosáhli jsme 24:00 - resetovat na 00:00
	movlw ASCII_0
	movwf HOD0
	movwf HOD1
	return


;**************************************************************************
INI_LCD	call	CEK15m	; 4-bitova inicializace displeje LCD
	call	CEK15m		; cekej 15 ms
	bcf	RS				; zapis ridicich instrukci do LCD
;-------------------------------
	movlw	03h			; !!! poslat 03h na P_VYS0-3 (vstupy LCD DB4-DB7) !!!
	movwf	P_VYS
;       ------------------------
	bsf	E
	bcf	E
	call	CEK4m		; cekej 4,1 ms
;       ------------------------
	bsf	E
	bcf	E
	call	CEK100		; cekej 100 us
;       ------------------------
	bsf	E
	bcf	E
	call	CEK40		; cekej 40 us
;-------------------------------
	movlw	02h			; !!! poslat 02h na P_VYS0-3 (vstupy LCD DB4-DB7) !!!
	movwf	P_VYS		; nastavena 4-bitova komunikace
;       ------------------------
	bsf	E
	bcf	E
	call	CEK40		; cekej 40 us
;-------------------------------
	movlw	2Ch			; 00101000 - pocet bitu, 2 radky, 5x10 znaky
	call	WR_CMD
	movlw	0Ch			; 00001100 - display ON, kurzor OFF, blikani OFF
	call	WR_CMD
	movlw	01h			; 00000001 - smaze displej, kurzor na pozici 0
	call	WR_CMD
	movlw	06h			; 00000110 - smer kurzoru, posunu displeje
	call	WR_CMD
;       ------------------------
	return
;**************************************************************************
	
;================================================================================
; LCD OVLÁDÁNÍ - NÍZKOÚROVŇOVÉ FUNKCE (4-bitový mód)
;================================================================================

; --- Funkce: Napsat TEXT z tabulky TAB_TXT ---
; Vstup: W = index do tabulky
WR_TEXT
	movwf TEXT				; Uložit index
	call TAB_TXT			; Přečíst znak z tabulky
	movwf ZNAK				; Uložit  
	sublw 0x80				; Testovat konec textu (0x80)
	btfsc STATUS,Z
	retlw 0x00				; Vrátit se pokud je konec
	
	movf ZNAK,W				; Přípravit znak
	call WR_DATA			; Zapsat do LCD
	incf TEXT,W				; Index + 1
	goto WR_TEXT			; Opakovat

; --- Funkce: Přejít na ŘÁDEK 1 ---
LINE1
	movlw LCD_HOME			; 0x80 = 1. řádek, pozice 0
	goto WR_CMD

; --- Funkce: Přejít na ŘÁDEK 2 ---
LINE2
	movlw LCD_LINE2			; 0xC0 = 2. řádek, pozice 0
	goto WR_CMD

; --- Funkce: Vymazat LCD displej ---
C_LCD
	movlw LCD_CLEAR			; 0x01 = vymazat a home
	goto WR_CMD

; --- Funkce: Napsat LCD PŘÍKAZ ---
WR_CMD
	bcf RS					; RS=0: zápis příkazu
	goto WR_LCD

; --- Funkce: Napsat LCD DATA (znak) ---
WR_DATA
	bsf RS					; RS=1: zápis dat

; --- Funkce: Nízkoúrovňový zápis do LCD (4-bitový mód) ---
; V registru W jsou data/příkaz
; RS již nastaven (0=příkaz, 1=data)
WR_LCD
	movwf ZNAK				; Uložit data
	
	; Odeslat vyšší 4 bity
	bsf E					; Nastavit Enable
	movf P_VYS,W			; Přečíst aktuální PORTC
	iorlw 0x0F				; Maskovat dolní bity (zachovat ostatní piny)
	movwf TMP1
	
	swapf ZNAK,W			; Swap: vyšší 4 bity → dolní 4 bity
	iorlw 0xF0				; Maskovat horní bity
	andwf TMP1,W			; Zkombinovat
	movwf P_VYS			; Zapsat na datový port
	bcf E					; Vypnout Enable (latch dat)
	
	; Odeslat nižší 4 bity
	bsf E					; Nastavit Enable
	movf ZNAK,W			; Přečíst původní data
	iorlw 0xF0				; Maskovat horní bity
	andwf TMP1,W			; Zkombinovat s dolními bity z PORTC
	movwf P_VYS			; Zapsat na datový port
	bcf E					; Vypnout Enable
	
	; Čekat na dokončení operace
	btfsc RS				; Pokud RS=1 (data write)
	goto WAIT_40US			; Krátká čekací doba (40 µs)
	
	; Příkaz - ověřit jaký byl (vyžaduje delší čekání)
	movlw 0x04
	subwf ZNAK,W			; Porovnat s instrukcí CLEAR
	btfss STATUS,C			; Pokud was CLEAR
	goto WAIT_4MS			; Čekat 4 ms
	goto WAIT_40US			; Jinak 40 µs

WAIT_4MS
	call DELAY_4ms
	return

WAIT_40US
	call DELAY_40us
	return

;================================================================================
; FUNKCE ČESKÝCH ZNAKŮ - Nahrát do LCD CGRAM paměti
;================================================================================
CESTINA
	movlw 0x00				; Adresa prvního znaku v EEPROM
	movwf EEADR
	movlw LCD_CHAR_ADDR_START	; 0x40 = adresa v LCD
	movwf ADRESA

LOAD_CHAR_LOOP
	movf ADRESA,W
	call WR_CMD				; Nastavit adresu v LCD
	call RD_MEM				; Přečíst z EEPROM
	call WR_DATA			; Zapsat do LCD
	
	banksel EEADR
	incf EEADR,F			; Další byte v EEPROM
	banksel 0x00
	incf ADRESA,F			; Další pozice v LCD
	movf ADRESA,W
	sublw 0x80				; Pokud ADRESA < 0x80
	btfss STATUS,Z
	goto LOAD_CHAR_LOOP
	
	return

; --- Funkce: Čtení z EEPROM paměti ---
; Vstup: EEADR = adresa, Výstup: W = načtená hodnota
RD_MEM
	BANKSEL EECON1
	BCF EECON1, EEPGD		; Číst z datové paměti (ne program memory)
	BSF EECON1, RD			; Inicializovat čtení
	BANKSEL EEDAT
	MOVF EEDAT, W			; Načíst do W
	BCF STATUS, RP1			; Zpět do banky 0
	return



;================================================================================
; FUNKCE ČEKÁNÍ - DELAY TIMERY NA KRYSTALU 4MHz
;================================================================================
; Poznámka: Všechny časy se odečítají od volání do návratu

DELAY_1s
	movlw .9
	movwf TMP3
	
DL1S_LOOP
	call DELAY_100ms
	decfsz TMP3,F
	goto DL1S_LOOP
	
	; Zbývajících ~100ms
	movlw .5
	movwf TMP3
	call DELAY_100ms
	call DELAY_100ms
	call DELAY_100ms
	call DELAY_100ms
	call DELAY_100ms
	call DELAY_4ms
	call DELAY_4ms
	call DELAY_40us
	movlw 0x05
	movwf TMP0
DL1S_END_LOOP
	decfsz TMP0,F
	goto DL1S_END_LOOP
	nop
	nop
	return

DELAY_500ms
	movlw .5
	movwf TMP3
	call DELAY_100ms
	decfsz TMP3,F
	goto $-2
	return

DELAY_2s
	movlw .20
	movwf TMP3
	call DELAY_100ms
	decfsz TMP3,F
	goto $-2
	return

DELAY_100ms
	movlw 0xCE			; ≈ 100,009 ms (parametry výpočtu)
	movwf TMP0
	movlw 0xA0
	movwf TMP1
	goto TIMING_LOOP

DELAY_4ms
	movlw 0xA5			; ≈ 4,001 ms
	movwf TMP0
	movlw 0x08
	movwf TMP1
	goto TIMING_LOOP

DELAY_40us
	movlw 0x09			; ≈ 40 µs
	movwf TMP0
	movlw 0x01
	movwf TMP1
	goto TIMING_LOOP

; --- Hlavní timing smyčka ---
TIMING_LOOP
	movf TMP0,W
	movwf TMP2
TIMING_INNER
	decfsz TMP2,F		; Vnitřní smyčka
	goto TIMING_INNER
	
	decfsz TMP1,F		; Vnější smyčka
	goto TIMING_LOOP
	return

CEK1s:
	call DELAY_1s
	return

CEK500m:
	call DELAY_500ms
	return

CEK2s:
	call DELAY_2s
	return

CEK100m:
	call DELAY_100ms
	return

CEK15m:
	movlw 0xAB
	movwf TMP0
	movlw 0x1D
	movwf TMP1
	goto TIMING_LOOP

CEK4m:
	call DELAY_4ms
	return

CEK1m6:
	movlw 0x41
	movwf TMP0
	movlw 0x08
	movwf TMP1
	goto TIMING_LOOP

CEK100:
	movlw 0x1D
	movwf TMP0
	movlw 0x01
	movwf TMP1
	goto TIMING_LOOP

CEK40:
	call DELAY_40us
	return


;**************************************************************************
;================================================================================
; DISPLAY_TIME: Zobrazit čas v PRVNÍM ŘÁDKU jako HH:MM:SS
;================================================================================
DISPLAY_TIME
	call LINE1					; Přejít na 1. řádek displeje
	movf HOD1,W					; Zobrazit desítky hodin
	call WR_DATA
	movf HOD0,W					; Zobrazit jednotky hodin
	call WR_DATA
	movlw ASCII_COLON			; Zobrazit ':'
	call WR_DATA
	movf MIN1,W					; Zobrazit desítky minut
	call WR_DATA
	movf MIN0,W					; Zobrazit jednotky minut
	call WR_DATA
	movlw ASCII_COLON
	call WR_DATA
	movf SEC1,W					; Zobrazit desítky sekund
	call WR_DATA
	movf SEC0,W					; Zobrazit jednotky sekund
	call WR_DATA
	return

; --- Funkce: Zobrazit software verzi ---
SHOW_VERSION
	call C_LCD					; Vymazat displej
	movlw .00					; Text "Vlášťuji se [ikona]"
	call WR_TEXT
	movlw 0x01					; Vlastní znak
	call WR_DATA
	movlw .04					; Pokračování textu
	call WR_TEXT
	movlw 0x00					; Vlastní znak
	call WR_DATA
	movlw .07					; Pokračování
	call WR_TEXT
	
	call LINE2					; Přejít na 2. řádek
	movlw .17					; Text "verze 1.0 2014"
	call WR_TEXT
	return

	movlw	.00			; text 0 - jmeno sofware
	call	WR_TEXT
	movlw	01h
	call	WR_DATA
	movlw	.04			; text 4 - jmeno sofware pokra�ov�n�
	call	WR_TEXT
	movlw	00h
	call	WR_DATA
	movlw	.07			; text 7 - jmeno sofware pokra�ov�n�
	call	WR_TEXT

	call	LINE2
	movlw	.17			; text 17 - verze, datum
	call	WR_TEXT

	call	CEK2s		; cekej 2 sekundu
	return
;**************************************************************************
	end

