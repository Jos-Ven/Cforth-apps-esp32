marker bme680.fth \ cr lastacf .name #19 to-column .( 06-11-2024 )

0 [if] For the bme680 sensor of Bosch.

After:
https://github.com/boschsensortec/BME68x_SensorAPI
and the documentation at:
https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-bme680-ds001.pdf

Notes:
1) Not fully optimized.
2) The measurements of temperature pressure and humidity seem to be right.
3) The measurements of gas are still under study.
4) A heat-up time required.

[then]

s" cforth" ENVIRONMENT?  [IF]  DROP  DECIMAL

#26 value sda-pin        #27 value scl-pin

: init-i2c  ( - err )    scl-pin sda-pin i2c-open ;

alias rshift >>

[else]

\ Place your i2c code here !



    [undefined]  init-i2c  [if]
    cr .( Error: The I2C interface is missing ! ) cr
    : init-i2c  ( - err )  0 ;
    : i2c-b@    ( register i2c-addr stop -- reg-value ) 3drop 10 ;
    : i2c-b!    ( value register i2c-addr -- )    3drop 0  ;
    [then]
[then]


\ ---- Settings ----

$76 value BME68X_I2C_ADDRESS \ Connect SDO to ground!
f# -4.0 fvalue ftemp-trim    \ Correction for the temperature.
#3   value IIR_filter
#260 value gas_heater
#25  value gas_WaitMs
#1   value gas_multiplcation \ 0:1x, 1:4x, 2:16x, 3:64x

\ ---- End settings ----

variable #measurements     0 #measurements !                f# 0.0 fvalue temp_comp
f# 0.0 fvalue var2         f# 0.0 fvalue calc_pres          f# 0.0 fvalue var1
f# 0.0 fvalue amb_temp

\ OVER SAMPLING DEFINITIONS
$00 constant BME68X_OVERSAMP_SKIPPED $01 constant BME68X_OVERSAMP_1X
$02 constant BME68X_OVERSAMP_2X      $03 constant BME68X_OVERSAMP_4X
$04 constant BME68X_OVERSAMP_8X      $05 constant BME68X_OVERSAMP_16X

$01 constant BME68X_FORCED_MODE      $0  constant BME68X_FILTER_OFF

: ?IorCodeBme680 ( result - result ior ) dup  -1 =  if  dup  h. space else  0  then ;
: bme-b@         ( reg# -- b )   BME68X_I2C_ADDRESS 0 i2c-b@  ;
: bme-b!         ( b reg# -- )   BME68X_I2C_ADDRESS i2c-b! abort" PCA9685 write failed" ;
: ChipId@        (  - id )       $D0 ( BME68X_REG_CHIP_ID )    bme-b@ ;
: variantId@     ( - variantID ) $F0 ( BME68X_REG_VARIANT_ID ) bme-b@ ?IorCodeBme680 drop ;
: ctrl_gas_1!    ( nb_conv run_gas - )       #4 lshift or $71 bme-b! ;
: gas_wait_x!    ( WaitMs multiplcation - )  #6 lshift or $64 bme-b! ;
: ReadBme680     ( until &Start -- msb lsb ) do  i bme-b@  loop ;
: init-bme680    ( - )                       init-i2c drop ;
: concat2Bytes   ( lsm msb - )               8 lshift or ;

: .IdBme680 ( - )
  ." ChipId BME680: " ChipId@ ?IorCodeBme680 drop h.
  ." variant: "  VariantId@ h. ;

: ctrl_meas! ( Pressure_oversampling  Temperature_oversampling  mode - )
   >r 5 lshift swap 2 lshift or r> or
   $74  ( BME68X_CTRL_MEAS_REG ) bme-b! ;

: signed-char  ( s8bit -- ) ( f: - n )
   dup $7f >
    if  [ -1 $ff xor ] literal or
    then ;

: signed-short ( s16bit - signed )
   dup $7fff >
    if  [ -1 $ffff xor ] literal or
    then ;

: signed-4bit ( s4bit - signed )
   dup $7 >
    if  [ -1 $f xor ] literal or
    then ;

: calib.s16   ( Start -- ) ( f: -- n )
  dup 2 + swap ReadBme680  concat2Bytes signed-short s>f  ;

: calib.u16   ( Start -- ) ( f: -- n )
  dup 2 + swap ReadBme680  concat2Bytes s>f  ;

: calib.u8  ( adr -- ) ( f: - n ) bme-b@ s>f ;
: calib.s8  ( adr -- ) ( f: - n ) bme-b@ signed-char s>f ;
: 20b>s     ( xlsb lsb msb  - n ) rot #12 lshift  rot #4 lshift  or   swap #4 rshift  or  ;

: calib.H1 (   f: - calib )
   $e2  bme-b@  $7 and ( par_h1 )
   $e3  bme-b@  #4 lshift  or  s>f ;

: calib.H2  (   f: - calib )
   $e2  bme-b@  $4 rshift ( par_h2 )
   $e1  bme-b@  #4 lshift  or  s>f ;

: raw_temp>f  ( f: rawtemp - t_fine temp )
   $e9 ( par_t1) calib.u16  to var1
   fdup f# 16384.0 f/ var1 f# 1024.0 f/  f- $8A ( PAR_T2 )  calib.s16  f*
   fswap f# 131072.0   F/ var1 f# 8192.00 F/
   fover fover   F- F*   $8c ( PAR_T3 ) bme-b@    s>f
   f# 16.0000 F* F* F-   \ var1 var2
   f+  fdup \   t_fine    \ dev->calib.t_fine = (var1 + var2);
   f# 5120.0 f/  ftemp-trim f+ ;

: Calc_pressure ( f: - pres )  \ Uses var1, calc_pres, and var2 of raw_pressure>f
   CALC_PRES VAR2 f# 4096.00 F/ F- f# 6250.00 F* VAR1 F/ to calc_pres
   $9e ( PAR_P9 ) calib.s16  CALC_PRES F* CALC_PRES F* f# 2147483648.0 F/ to var1 \ var1
   CALC_PRES $9c ( PAR_P8 ) calib.s16 f# 32768.0 F/ F* to var2 \ var2
   CALC_PRES f# 256.000 F/ CALC_PRES f# 256.000 F/ F* CALC_PRES
             f# 256.000 F/ F*  $a0 ( PAR_P10 ) bme-b@ s>f f# 131072.0  F/  F*  \ var3
   VAR1 VAR2 F+  F+  CALC_PRES fswap $98 ( PAR_P7)  bme-b@ s>f f# 128.000 F*
             F+ f# 16.0000 F/ F+  f# 100.0 f/ ;

: raw_pressure>f  ( f: t_fine acd_press -- pres )  \ Not optimized. Uses T_fine of raw_temp>f
   fswap f# 2.0 f/ f# 64000.0 f-  to var1  \  var1.0
   VAR1 VAR1 F*       $99 ( par_p6) bme-b@  s>f f# 131072.0  F/ F* to var2 \ 2.0
   VAR2 VAR1          $96 ( PAR_P5) calib.s16 F* f# 2.00000 F* F+  to var2 \ 2.1
   VAR2 f# 4.00000 F/ $94 ( PAR_P4) calib.s16 f# 65536.0 F* F+     to var2 \ 2.2
     $92 ( PAR_P3)  bme-b@ s>f VAR1 F* VAR1 F* f# 16384.0 F/
     $90 ( PAR_P2) calib.s16 VAR1 F* F+ f# 524288.0  F/            to var1 \ 1.1
   f# 1.00000 VAR1 f# 32768.0 F/ F+ $8e ( PAR_P1) calib.u16 F*     to var1 \ 1.2
   f# 1048576.0  fswap f-  to calc_pres     \ calc_pres 1.0
   var1 f0<>
      if    Calc_pressure
      else  fdrop f# 0
      then ;

: raw-humidity>f  ( f: t_fine acd_hum -- pres ) \ 50.9
   ( t_fine ) fswap f# 5120.0  f/ to temp_comp
   ( hum_adc )  calib.H1  f# 16.0000 f*
     $e4 ( par_h3 ) calib.u8 f# 2.00000  F/ TEMP_COMP F* F+ F-  \ VAR1
   ( VAR1 ) calib.H2 f# 262144.0  F/ f# 1.00000 $e5 ( PAR_H4 ) calib.u8
     f# 16384.0 TEMP_COMP F* F/ $e6 ( PAR_H5 ) calib.u8 f# 1048576.0 F/
     TEMP_COMP F* TEMP_COMP F* F+ F+ F* F* fdup \ var2
   $e7 ( par_h6 ) calib.u8 f# 16384.0    f/     \ var3
   $e8 ( par_h7 ) calib.s8 f# 2097152.0  f/     \ var4
   TEMP_COMP F* F+ fover F* F* F+
    f# 100.0 fmin  f# 0.0 fmax ;

: read-temp ( f: - t_fine temp )
   $25 $22   ( temp_adc ) ReadBme680  20b>s s>f
   raw_temp>f ;

: read-pressure ( f: t_fine - pressure )  \ Depends on read-temp
   $22 $1f  ReadBme680   20b>s s>f raw_pressure>f ;

: read-humidity ( f: t_fine - humidity )  \ Depends on read-temp
   $26 bme-b@  $25 bme-b@ concat2Bytes s>f raw-humidity>f ;

: calc_res_heat ( temp - res_heat_x )
   $ed ( PAR_GH1 ) calib.s8  f# 16.0000 F/ f# 49.0000 F+   \  var1
   $eb ( PAR_GH2 ) calib.s16 f# 32768.0 F/ f# 5.00000E-4 F* f# .002350  F+ \  var2 <<
   $ee ( PAR_GH3 ) calib.s8 f# 1024.00 F/                  \ var3
   frot frot f# 1.00000 fswap  s>f F* F+ F*                \ var4
   fswap   amb_temp F* F+                                  \ var5
   f# 3.40000 fswap f# 4.00000 f#  4.00000  $2 ( HEAT_RANGE ) bme-b@ $1f and #4 rshift s>f
     F+ F/ F* f#  1.00000 f#  1.00000 $0 ( RES_HEAT_VAL ) calib.s8 f# .002000
     F* F+ F/ F* f#  25.0000 F- F*  \ res_heat_x \
     f>s ;

create lookup_k1_range
 f# 0.0 f, f# 0.0 f, f# 0.0 f,  f# 0.0 f,  f# 0.0 f, f# -1.0 f, f# 0.0 f, f# -0.8 f,
 f# 0.0 f, f# 0.0 f, f# -0.2 f, f# -0.5 f, f# 0.0 f, f# -1.0 f, f# 0.0 f, f# 0.0  f,

create lookup_k2_range
 f# 0.0 f,  f# 0.0 f, f# 0.0 f, f# 0.0 f,  f# 0.1 f, f# 0.7 f,  f# 0.0 f, f# -0.8 f,
 f# -0.1 f, f# 0.0 f, f# 0.0 f, f# 0.0 f,  f# 0.0 f, f# 0.0 f,  f# 0.0 f, f# 0.0  f,

0 [if]
1. read gas_r ( 2A-MSB:7:0 2B-LSB:7.6)    ADC-range gas_range_r (2B 3:0)
2. read RANGE_SW_ERR 0x04 7:4 signed 4bit
3  convert to ohm
[then]

: range_sw_err@ ( - range_sw_err ) $4 ( RANGE_SW_ERR ) bme-b@ 4 rshift signed-4bit s>f ;

: calc_gas_resistance ( - gas_res )
( 2)  f# 1340.00  f# 5.00000 range_sw_err@ F* F+ to var1
( 1)  VAR1 f# 1.00000 $2b bme-b@ ( gas_range_r ) $0f and floats dup lookup_k1_range + f@  f# 100.000 F/ F+ f* to var2
   f# 1.00000 ( gas_range_r-addr )  lookup_k2_range + f@  f# 100.000 F/ F+ \  var3
   f# 1.00000 fswap f# 1.25000E-7 F*
   $2a ( GAS_R_MSB ) bme-b@ 2 lshift   $2b ( GAS_R_LSB ) bme-b@ 6 rshift  or \ raw gas_r
   dup s>f F*  s>f ( gas_res_f ) f# 512.000
   F- VAR2 F/ f# 1.00000 F+ F* fdup f0<>
       if   F/    \ calc_gas_res
       else f2drop f# 0.0
       then ;

: heat_stab_r   ( - heat_stab-flag )  $2b ( REG_GAS_WAIT_0 ) bme-b@ 4 rshift 1 and  ; \ OK when <> 0
: .heat_stab_r  ( - ) heat_stab_r . ;
: bme-reset     ( - ) $b6 $e0 ( reset ) bme-b! ;

: wait_meas ( - )  \ normally +/- 136 ms
  ms@ #100 0       \ max 1 sec
     do   #10 ms  $1d ( meas_status_0 ) bme-b@  $60 and 0=
            if  leave
            then
     loop  ms@ swap - . ." Ms " ;

\ Forced mode: Perform one measurement, to get results and return to sleep mode
: ForceBme680 ( - )                                            \ See 3.2.2
   BME68X_OVERSAMP_2X $72              ( ctrl_hum ) bme-b!     \ --1 Set osrs_h
   BME68X_OVERSAMP_4X BME68X_OVERSAMP_8X 2dup 2>r 0 ctrl_meas! \ --2 Set  osrs_t osrs_p and wait
   IIR_filter 2 lshift $75 ( BME68X_REG_CONFIG )      bme-b!   \ --3 IIR_filter
   0 ( nb_conv )  variantId@
      if    2 ( BME68X_ENABLE_GAS_MEAS_H )
      else  1 ( BME68X_ENABLE_GAS_MEAS_L )
      then  ctrl_gas_1!                                        \ --4 index and gas conversion
   gas_WaitMs  gas_multiplcation                   gas_wait_x! \ --6 Heatup time
   gas_heater  calc_res_heat  $5A      (     res_heat ) bme-b! \ --5 Heater temperature
   2r> BME68X_FORCED_MODE                         ctrl_meas! ; \ --7 Run it

: measure       ( - t_fine )  1 #measurements +! ForceBme680 wait_meas read-temp to amb_temp ;
: gas_wait-time ( - ms )      gas_WaitMs 1 gas_multiplcation 0 ?do 4 * loop * ;

\ After init-bme680:
: .bme680Data  ( - )
    cr .IdBme680  measure fdup
    cr ." Gas heater at:" gas_heater . ." C for " gas_Wait-time .  ." Ms."
    cr ." Heat stab. : " .heat_stab_r
    cr ." Temperature: " amb_temp       f. ." C"
    cr ."   Pressure : " read-pressure  f. ." hPa"
    cr ."   Humidity : " read-humidity  f. ." %"
    cr ."        Gas : " calc_gas_resistance fe. ." Ohm"
    cr
    0 $74 ( BME68X_CTRL_MEAS_REG ) bme-b! ;

: .poll  ( - )
    measure fdup
    cr  .heat_stab_r
    amb_temp       f. ." C "
    read-pressure  f. ." hPa "
    read-humidity  f. ." % "
    calc_gas_resistance fe. ." Ohm" ;

\ Eg: init-bme680 50 ms .bme680Data
\ \s
