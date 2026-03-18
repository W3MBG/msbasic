.setcpu "65C02"
.debuginfo

; Adresses for VIA
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
ACR = $600b
PCR = $600c
IFR = $600d
IER = $600e

; Adresses for ACIA/UART
ACIA_DATA   = $5000
ACIA_STATUS = $5001
ACIA_CMD    = $5002
ACIA_CTRL   = $5003

;lcd_data = $00          ; 1 byte, lcd status read
;LCDCMD = $01            ; 1 byte, lcd command / char
READ_PTR = $00          ; 1 byte
WRITE_PTR = $01         ; 1 byte
;LCD1PTR = $04           ; 2 bytes, line 1 address pointer
;LCD2PTR = $06           ; 2 bytes, line 2 address pointer
IN_BUFFER = $0300       ; 256 Bytes, input buffer

LOAD:
                rts

SAVE:
                rts

reset:
    ldx #$ff            ; Initialize stack pointer
    txs

    cli                 ; Clear interrupt disable flag

    lda #%11111111      ; Set port B data direction
    sta DDRB
    lda #%00000111      ; Set port A data direction
    sta DDRA

    ;jsr lcd_init

; Setup UART
uart_config:
    lda #%00011111      ; 8-N-1, 19200 baud.
    sta ACIA_CTRL
    lda #%00001001      ; No parity, no echo, interrupts.
    sta ACIA_CMD

    jsr init_buffer

    jmp WOZMON

MONRDKEY:
CHRIN:
    phx
    jsr buffer_size     ; Get buffer size
    beq nochar          ; branch if 0
    cmp #$b4            ; enable cts if less than 180
    bcc cts_enable
getchar:
    jsr read_buffer     ; Get next char from buffer
    jsr CHROUT          ; Echo it
    sec
    plx
    rts                 ; Return
nochar:
    lda #0              ; Return 0 if buffer empty
    clc
    plx
    rts
cts_enable:
    lda #%11111110      ; Set A0 low (CTS high)
    and PORTB           ; Don't modify other bits
    sta PORTB           ; Store
    jmp getchar

MONCOUT:
CHROUT:
    pha                 ; Save A.
    sta ACIA_DATA       ; Output character.
    lda #$FF            ; Initialize delay loop.
txdelay:
    dec                 ; Decrement A.
    bne     txdelay     ; Until A gets to 0.
    pla                 ; Restore A.
    rts                 ; Return.


INIT_BUFFER:
init_buffer:
    pha
    lda WRITE_PTR
    sta READ_PTR
    lda #$fe
    and PORTB
    sta PORTB
    pla
    rts

write_buffer:
    ldx WRITE_PTR
    sta IN_BUFFER,x
    inc WRITE_PTR
    rts

read_buffer:
    ldx READ_PTR
    lda IN_BUFFER,x
    inc READ_PTR
    rts

buffer_size:
    lda WRITE_PTR
    sec
    sbc READ_PTR
    rts


;.include "code.asm"

;.include "lcd.asm"

;interrupt handlers
nmi:
irq:
    pha
    phx
    lda ACIA_STATUS
    bpl exit_irq
    lda ACIA_DATA       ; Read byte from UART
    jsr write_buffer
    jsr buffer_size
    cmp #$f0
    bcc exit_irq        ; Branch if not full
    lda #$1             ; Set B0 High (CTS low)
    ora PORTB
    sta PORTB
exit_irq:
    plx
    pla
    rti

.include "wozmon.s"

; Reset / interrupt vectors
.segment "RESETVEC"
    .word nmi
    .word reset
    .word irq
