        LIST    P=16F690
        #include <p16f690.inc>

; Configuration bits
        __CONFIG _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF

; LCD pin mapping (PORTC)
; RC0 -> RS
; RC1 -> E
; RC4..RC7 -> D4..D7

; Buttons (PORTA, active low with pull-ups)
; RA0 -> MODE (enter/exit setup)
; RA1 -> NEXT (field select)
; RA2 -> UP (increment selected field)

        CBLOCK  0x20
h_tens
h_units
m_tens
m_units
s_tens
s_units
setup_field     ; 0=hour,1=minute,2=second
setup_req
cnt0
cnt1
tmp0
tmp1
        ENDC

        ORG     0x0000
        GOTO    start

start:
        banksel OSCCON
        movlw   b'01100000' ; 4 MHz internal oscillator
        movwf   OSCCON

        banksel ANSEL
        clrf    ANSEL
        clrf    ANSELH

        banksel TRISA
        movlw   b'00000111' ; RA0..RA2 inputs
        movwf   TRISA

        banksel TRISC
        clrf    TRISC       ; LCD on PORTC outputs

        banksel PORTA
        clrf    PORTA

        banksel PORTC
        clrf    PORTC

        banksel WPUA
        movlw   b'00000111'
        movwf   WPUA

        banksel OPTION_REG
        bcf     OPTION_REG, 7 ; enable weak pull-ups

        call    init_time
        call    lcd_init
        call    lcd_show_time

main_loop:
        call    delay_1s_or_mode
        movf    setup_req, W
        btfss   STATUS, Z
        goto    setup_mode

        call    increment_time
        call    lcd_show_time
        goto    main_loop

setup_mode:
        clrf    setup_req
        clrf    setup_field

setup_loop:
        call    lcd_show_time

wait_action:
        call    mode_pressed
        btfss   STATUS, Z
        goto    check_next
        goto    main_loop

check_next:
        call    next_pressed
        btfss   STATUS, Z
        goto    check_up
        incf    setup_field, F
        movlw   0x03
        subwf   setup_field, W
        btfsc   STATUS, C
        clrf    setup_field
        goto    setup_loop

check_up:
        call    up_pressed
        btfss   STATUS, Z
        goto    wait_action

        movf    setup_field, W
        btfsc   STATUS, Z
        goto    inc_hours
        xorlw   0x01
        btfsc   STATUS, Z
        goto    inc_minutes
        goto    inc_seconds

inc_hours:
        call    increment_hours
        goto    setup_loop

inc_minutes:
        call    increment_minutes
        goto    setup_loop

inc_seconds:
        call    increment_seconds
        goto    setup_loop

init_time:
        movlw   '1'
        movwf   h_tens
        movlw   '2'
        movwf   h_units
        movlw   '0'
        movwf   m_tens
        movwf   m_units
        movwf   s_tens
        movwf   s_units
        return

increment_time:
        call    increment_seconds
        return

increment_seconds:
        incf    s_units, F
        movlw   ':'
        subwf   s_units, W
        btfss   STATUS, C
        return
        movlw   '0'
        movwf   s_units

        incf    s_tens, F
        movlw   '6'
        subwf   s_tens, W
        btfss   STATUS, C
        return
        movlw   '0'
        movwf   s_tens
        call    increment_minutes
        return

increment_minutes:
        incf    m_units, F
        movlw   ':'
        subwf   m_units, W
        btfss   STATUS, C
        return
        movlw   '0'
        movwf   m_units

        incf    m_tens, F
        movlw   '6'
        subwf   m_tens, W
        btfss   STATUS, C
        return
        movlw   '0'
        movwf   m_tens
        call    increment_hours
        return

increment_hours:
        incf    h_units, F

        movf    h_tens, W
        xorlw   '2'
        btfss   STATUS, Z
        goto    hours_lt_20

        movlw   '4'
        subwf   h_units, W
        btfss   STATUS, C
        return
        movlw   '0'
        movwf   h_tens
        movwf   h_units
        return

hours_lt_20:
        movlw   ':'
        subwf   h_units, W
        btfss   STATUS, C
        return
        movlw   '0'
        movwf   h_units
        incf    h_tens, F
        return

lcd_show_time:
        movlw   0x80
        call    lcd_cmd

        movf    h_tens, W
        call    lcd_data
        movf    h_units, W
        call    lcd_data

        movlw   ':'
        call    lcd_data

        movf    m_tens, W
        call    lcd_data
        movf    m_units, W
        call    lcd_data

        movlw   ':'
        call    lcd_data

        movf    s_tens, W
        call    lcd_data
        movf    s_units, W
        call    lcd_data
        return

lcd_init:
        call    delay_20ms

        movlw   0x03
        call    lcd_write_init_nibble
        call    delay_5ms

        movlw   0x03
        call    lcd_write_init_nibble
        call    delay_5ms

        movlw   0x03
        call    lcd_write_init_nibble
        call    delay_5ms

        movlw   0x02
        call    lcd_write_init_nibble
        call    delay_5ms

        movlw   0x28
        call    lcd_cmd
        movlw   0x0C
        call    lcd_cmd
        movlw   0x06
        call    lcd_cmd
        movlw   0x01
        call    lcd_cmd
        call    delay_5ms
        return

lcd_write_init_nibble:
        banksel PORTC
        bcf     PORTC, 0
        call    lcd_write_nibble
        return

lcd_cmd:
        banksel PORTC
        bcf     PORTC, 0
        call    lcd_write_byte
        call    delay_2ms
        return

lcd_data:
        banksel PORTC
        bsf     PORTC, 0
        call    lcd_write_byte
        call    delay_2ms
        return

lcd_write_byte:
        movwf   tmp0

        swapf   tmp0, W
        andlw   0x0F
        call    lcd_write_nibble

        movf    tmp0, W
        andlw   0x0F
        call    lcd_write_nibble
        return

lcd_write_nibble:
        movwf   tmp1
        swapf   tmp1, W
        andlw   0xF0
        movwf   tmp1

        banksel PORTC
        movf    PORTC, W
        andlw   0x0F
        iorwf   tmp1, W
        movwf   PORTC

        bsf     PORTC, 1
        nop
        nop
        bcf     PORTC, 1
        return

mode_pressed:
        banksel PORTA
        btfsc   PORTA, 0
        goto    button_not_pressed
        call    delay_20ms
        btfsc   PORTA, 0
        goto    button_not_pressed
mode_wait_release:
        btfss   PORTA, 0
        goto    mode_wait_release
        clrf    tmp0
        return

next_pressed:
        banksel PORTA
        btfsc   PORTA, 1
        goto    button_not_pressed
        call    delay_20ms
        btfsc   PORTA, 1
        goto    button_not_pressed
next_wait_release:
        btfss   PORTA, 1
        goto    next_wait_release
        clrf    tmp0
        return

up_pressed:
        banksel PORTA
        btfsc   PORTA, 2
        goto    button_not_pressed
        call    delay_20ms
        btfsc   PORTA, 2
        goto    button_not_pressed
up_wait_release:
        btfss   PORTA, 2
        goto    up_wait_release
        clrf    tmp0
        return

button_not_pressed:
        movlw   0x01
        movwf   tmp0
        movf    tmp0, W
        return

delay_1s_or_mode:
        movlw   d'100'
        movwf   cnt0

delay_1s_loop:
        call    delay_10ms

        banksel PORTA
        btfss   PORTA, 0
        goto    mode_detected

        decfsz  cnt0, F
        goto    delay_1s_loop
        return

mode_detected:
        call    mode_pressed
        btfss   STATUS, Z
        return
        movlw   0x01
        movwf   setup_req
        return

delay_20ms:
        movlw   2
        movwf   cnt1

_delay20_loop:
        call    delay_10ms
        decfsz  cnt1, F
        goto    _delay20_loop
        return

delay_5ms:
        movlw   d'50'
        movwf   cnt1
_d5_1:
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        decfsz  cnt1, F
        goto    _d5_1
        return

delay_2ms:
        movlw   d'20'
        movwf   cnt1
_d2_1:
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        decfsz  cnt1, F
        goto    _d2_1
        return

delay_10ms:
        movlw   d'25'
        movwf   cnt1
_d10_outer:
        movlw   d'200'
        movwf   tmp0
_d10_inner:
        nop
        nop
        nop
        decfsz  tmp0, F
        goto    _d10_inner
        decfsz  cnt1, F
        goto    _d10_outer
        return

        END
