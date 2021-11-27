/*
Demo Sourcecode

----------------------------------------
Memory map:
[Global]
$0800         : BASIC start
$8000 - $A000 : Demo core (Intro and Main)

[Intro]
$0ff0 - $2000 : Music Buffer (Intro)
$2000 - $3300 : Intro Code
$3300 - $4500 : Fadeout Code
$4500 - $7700 : Mega Logo
* $8000 - $A000 : Demo core (Intro and Main)
$A000 - $B000 : Petscii Font Image
$B800 - $D000 : Load Buffer (Intro)

[Timeline 1]
$0ff0 - $1800 : Sfx Buffer (Timeline 1)
$1800 - $2600 : open-segment (petscii framebuffer)
$2600 - $3900 : open-loop (petscii framebuffer)
$3900 - $5200 : close-segment (petscii framebuffer)
* $5800 - $8000 : Menu and Song Titles
* $8000 - $A000 : Demo core (Intro and Main)
$a000 - $c000 : final segment (petscii framebuffer)
$5200 - $5800 : Timeline 1 Code

[Main]
$0ff0 - $4000 : Music Buffer  (Main)
$4000 - $5800 : Timelines
$5800 - $8000 : Menu and Song Titles
* $8000 - $A000 : Demo core (Intro and Main)
$A000 - $C000 : Petscii Frame Buffer (Main)
$C000 - $D000 : Load Buffer (Main)



----------------------------------------
ZeroPage:
$50-$5f Keyboard Handler
$9e-$9f IRQ Load Setup
$ab-$ae Scroller
$d0-$ef Exomizer
$fd-$fe GoatTracker
$f0-$f3 IRQ Load Runtime
$60/$61 General demo controller
*/
.var dzp_lo = $60
.var dzp_hi = $61

/*
----------------------------------------
Macros
----------------------------------------
*/
.import source "const.asm"
.import source "macro.asm"

/*
----------------------------------------
Memory management
----------------------------------------
*/
.import source "petscii_addresses.asm"

/*
----------------------------------------
Autogenerated Modules
----------------------------------------
*/
.import source "sid_include.asm"
.import source "petscii_include.asm"

/*
----------------------------------------
Template Code Modules
(these get loaded into the template space)
----------------------------------------
*/

.segment xys_routine [outPrg="ab.prg"]
*=$2000
.pc=* "XYSwinger Effect"
.import source "xyswinger.asm"
.pc = * "Tile Scroller Effect"
.import source "scroller.asm"

.segment megalogo [outPrg="ac.prg"]
*=$4500
.pc = * "Mega Logo"
.import source "biglogo_include.asm"

.segment xys_fadeout [outPrg="ad.prg"]
*=$3300
.pc = * "XYSwinger Effect Fadeout"
.import source "xyswinger_fadeout.asm"

.segment menu_core [outPrg="ba.prg"]
*=$6400
.pc = * "Song Titles"
.import source "menu_items.asm"
*=$5800
.pc = * "Menu Core"
.import source "menu.asm"
.pc = * "Player Status"
.import source "title.asm"
.pc = * "Sprite Colorcycler"
.import source "colorcycle_sprites.asm"
/*
----------------------------------------
Common Utils
----------------------------------------
*/

/*
Main Demo BASIC Entry
*/
.segment demo_main [outPrg="demo.prg"]
*=$0801
BasicUpstart2(start)

/*
Global flags
*/
enable_music:
.byte $00

enable_effect:
.byte $00

demo_state:
.byte $00

/*
Buffers:
*/

/*
----------------------------------------
Sprite
----------------------------------------
*/
.pc=$0a00
.for(var i=0;i<8;i++){
    .byte $ff, $ff, $ff
}
.for(var i=0;i<13;i++){
    .byte $00, $00, $00
}
.pc=$0a40
.for(var i=0;i<21;i++){
    .byte $ff, $ff, $ff
}
.pc=$0a80
.for(var i=0;i<12;i++){
    .byte $ff, $ff, $ff
}
.for(var i=0;i<09;i++){
    .byte $00, $00, $00
}


/*
----------------------------------------
Music
----------------------------------------
*/

// $0f00 - $3000 is reserved for music
.pc=$0f00 "Music Buffer (and temporary irq loader drivecode)"
loader_init:
.import source "loader_init.asm"
.var music_song = $0f00
.var music_speed = $0f01
.var music_init = $0f02
.var music_play = $0f04


// $A000 - $C000 is reserved for packed animation in main demo
.pc=$A000 "PETSCII Animation Buffers"


/*
----------------------------------------
Base code that never gets replaced
----------------------------------------
*/
.pc=$8000 "Code"
.pc=* "Exomizer"
.import source "exo.asm"

.pc=* "RLE Depacker"
.import source "rle_depacker.asm"

.pc=* "IRQ Loader"
.import source "loader_load.asm"

.pc=* "spinner"
.import source "spinner.asm"

.pc=* "keyboard handler"
keyboard:
.import source "keyboard.asm"

.pc=* "Music Functions"
.import source "music.asm"

.pc=* "Input Handlers"
press_space:
    jsr keyboard
    bcs press_space
    cmp #$20
    beq !finish+
    jmp press_space
!finish:
    rts

.pc=* "Utilities"

/*
----------------------------------------
Fill: 
x = fill char
y = fill color

*/
fill:
    //note: trying to balance size and speed with this, 
    //and can't use kernel as this whacks zeropage...
    stx fill_char
    sty fill_color
    ldx #$00
!loop:
    lda fill_char: #$20
    .for(var i=0;i<25;i++){
        sta $0400+(i*40),x
    }
    lda fill_color: #$00
    .for(var i=0;i<25;i++){
        sta $d800+(i*40),x
    }
    inx
    cpx #$28
    beq !+
    jmp !loop-
!:
    rts

/*
----------------------------------------
Pause:
y = number of iterations to pause
*/
pause:
    stx tmpx
    ldx #$00
!:
    nop
mini_pause:
    dex
    bne !-
    dey
    bne !-
    ldx tmpx: #$00
    rts

/*
----------------------------------------
MAIN
----------------------------------------
*/
.pc = * "Main DEMO"
start:
    lda #$00
    sta $d020
    sta $d021
    lda #$00
    sta $d020
    sta $d021
    ldx #$20
    ldy #$00
    jsr fill
    lda #$15
    sta $d018	
    lda#$80
    sta $0291
    //have to init scroller after clearing the screen!
    sei              
    lda #$7f       // Disable CIA
    sta $dc0d
    lda $d01a      // Enable raster interrupts
    ora #$01
    sta $d01a
    lda $d011      // High bit of raster line cleared, we're
    and #$7f       // only working within single byte ranges
    sta $d011
    lda #$01    // We want an interrupt at the top line
    sta $d012
    lda #<irq_loader 
    sta $0314    
    lda #>irq_loader
    sta $0315
    lda #$36
    sta $01
    cli  
    jmp timeline

/*
----------------------------------------
Interrupt Management
----------------------------------------

*/
.pc=* "irq"

//IRQ state machine
irq_state:
    lda demo_state
    cmp current_state: #$00
    bne !zero+
    rts

!zero:  
    sta current_state
    cmp #$00
    bne !one+

    // 0 = loader irq
    lda #$00
    sta $d012
    lda #>irq_loader
    sta $0315
    lda #<irq_loader
    sta $0314
    rts

!one:  
    cmp #$01
    beq !+
    jmp !two+
!:
    // 1 = intro irq a
    lda #$20
    sta $d012
    lda #>irq_intro_a
    sta $0315
    lda #<irq_intro_a
    sta $0314
    ldaStaMany($28,$07f8,$08,$01) //sprite ptr
    ldaStaMany($ae,$d001,$10,$02) // set y
    ldaStaMany($00,$d027,$08,$01) //fg color
    .var base=0
    .for(var i=0;i<8;i++){
        lda #<(base + (i*3*8*2))
        sta $d000 + (i*2)
    }
    lda #%11000000
    sta $d010
    lda #$00
    sta $d01c
    sta $d017
    sta $d01b
    lda #$ff
    sta $d015
    sta $d01d
    rts


!two:  
    cmp #$02
    bne !nope+
    // 2 = main irq
    lda #$00
    sta $d012
    lda #>irq_a
    sta $0315
    lda #<irq_a
    sta $0314
!nope:
    rts

//Actual IRQs
irq_loader:
    lda enable_effect
    beq !+
    jsr spinner_run
!:
    jsr irq_state
    lda #$ff 
    sta $d019
    jmp $ea81  


irq_intro_a:
    //inc $d020
    lda #$99
    sta $d012
    lda enable_effect
    beq !+
    jsr xys
    jsr s_scroll
    jsr m_play
!:
    jsr irq_state
    lda #$ff 
    sta $d019
    jmp $ea81  

//standard main irq
irq_a:
    lda #$4a
    sta $d001
    sta $d003
    sta $d005
    lda #$00
    sta $d027
    sta $d028
    sta $d029

    lda enable_effect
    beq !+
    jsr menu_irq_handler
!:
    lda enable_music
    beq !+
    jsr m_play
!:

    lda #$60
    sta $d012
    lda #>irq_b
    sta $0315
    lda #<irq_b
    sta $0314
    jsr irq_state
    lda #$ff 
    sta $d019
    jmp $ea81  


irq_b:
    lda #$74
    sta $d001
    sta $d003
    sta $d005
    lda #$9b
    sta $d012
    lda #>irq_c
    sta $0315
    lda #<irq_c
    sta $0314
    lda #$ff 
    sta $d019
    jmp $ea81  

irq_c:
    lda #$9e
    sta $d001
    sta $d003
    sta $d005

    lda $d012
!:
    cmp $d012
    beq !-
    lda $d012
!:
    cmp $d012
    beq !-
    lda #$00
    sta $d017
    lda #$2a
    sta $07f8
    sta $07f9
    sta $07fa
    lda #$b5
    sta $d012
    lda #>irq_d
    sta $0315
    lda #<irq_d
    sta $0314
    lda #$ff 
    sta $d019
    jmp $ea81  

//multispeed irq
irq_d:
    lda #$c2
    sta $d001
    sta $d003
    sta $d005
    lda cc_current_player_color
    sta $d027
    sta $d028
    sta $d029
    lda #$07
    sta $d017
    lda #$29
    sta $07f8
    sta $07f9
    sta $07fa


    lda enable_music
    beq !+
    lda music_speed
    cmp #$ff //multispeed flag from SID
    bne !+
    jsr m_play
!: 
    lda enable_effect
    beq !+
    jsr tt_run
    jsr cc_colorcycle
!:
    lda #$ec
    sta $d012
    lda #>irq_a
    sta $0315
    lda #<irq_a
    sta $0314
    lda #$ff 
    sta $d019
    jmp $ea81  






/* 
----------------------------------------
timeline:
----------------------------------------
*/
.pc = * "Internal timeline"
timeline:
    inc enable_effect
    jsr loader_init

//jmp debug_skip_intro

/*
START INTRO
*/

    load('0','7',$c000) //01.prg
    jsr m_disable
    jsr exo_exo
    jsr m_reset

    //load scroller-xyswinger merged template
    load('A','B',$b800) 
    jsr exo_exo

    //load scroller-xyswinger merged template
    load('A','D',$b800) 
    jsr exo_exo

    //load mega logo template
    load('A','C',$b800) 
    jsr exo_exo
    jsr xys_copy
/*
Todo: copy color map to phantom space and clear
*/

    //disable spinner
    lda #$00
    sta enable_effect
    ldx #$20
    ldy #$00
    jsr fill
    //init scroller
    jsr s_init
    // set up color for startup
    jsr s_switch_alt
    lda #$00
    sta intro_scroller_bg
    //transition IRQ to next state 
    //and enable effects in the IRQ
    inc demo_state
    inc enable_effect
    //fade in scroller
    ldy #$40
    jsr pause
    lda #$0b
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$0b
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$0c
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$03
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$0f
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$01
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$0f
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$03
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$0c
    sta intro_scroller_bg
    ldy #$02
    jsr pause
    lda #$0b
    sta intro_scroller_bg
    // switch to color in scroller
    ldy #$10
    jsr pause
    jsr s_switch_main
    //switch to colorful scroller
    jsr xys_fadein
    jsr press_space

    /*
    Fade out music and logo
    */
    lda #$0c
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$0f
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$03
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$01
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$03
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$0f
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$0c
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$0b
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    lda #$00
    sta intro_scroller_bg
    ldy #$04
    jsr pause
    jsr s_switch_alt
    jsr xys_fadeout
    jsr m_disable

/*
END INTRO
*/
debug_skip_intro:

    // disable effects
    lda #$00
    sta enable_effect 
    //switch to spinner IRQ
    lda #$00
    sta demo_state
    // clear screen
    ldx #$20
    ldy #$00
    jsr fill
    lda #$00
    sta $d015
    //disable music
    sta enable_music
    //enable spinner
    inc enable_effect
    //preload menu core
    load('B','A',$c000) 
    jsr exo_exo
    //load timeline 1
    load('T','1',$c000) 
    jsr exo_exo
    //timeline 1
    jsr $5200
    //timeline 2 (player)
    // load('T','2',$c000) <-- preload in timeline 1!
    jsr exo_exo
    jsr $4000


!:
    jmp !-

/*
----------------------------------------
Template code that can be overwritten
----------------------------------------
*/
.pc=$4000 "Template code that is replaced"
template_base:
/*
Timeline templates
*/
.segment timeline1 [outPrg="t1.prg"]
*=$5200
.pc = * "Timeline 1"
.import source "timeline1.asm"

.segment timeline2 [outPrg="t2.prg"]
*=$4000
.pc = * "Timeline 2"
.import source "timeline2.asm"

