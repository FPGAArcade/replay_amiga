--
-- WWW.FPGAArcade.COM
--
-- REPLAY Retro Gaming Platform
-- No Emulation No Compromise
--
-- All rights reserved
-- Mike Johnson 
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.FPGAArcade.com
--
-- Email support@fpgaarcade.com
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

Package Replay_Amiga_Pack is

  subtype int_9  is integer range 0 to  511;
  subtype int_11 is integer range 0 to 2047;
  subtype int_12 is integer range 0 to 4095;

  -- to do, check all reset values

  constant c_Reg_BLTDDAT        : int_12 := 16#000#; -- ER
  constant c_Reg_DMACONR        : int_12 := 16#002#;

  constant c_Reg_VPOSR          : int_12 := 16#004#;
  constant c_Reg_VHPOSR         : int_12 := 16#006#;

  constant c_Reg_DSKDATR        : int_12 := 16#008#;  -- ER

  constant c_Reg_JOY0DAT        : int_12 := 16#00A#;
  constant c_Reg_JOY1DAT        : int_12 := 16#00C#;
  constant c_Reg_CLXDAT         : int_12 := 16#00E#;

  constant c_Reg_ADKCONR        : int_12 := 16#010#;
  constant c_Reg_POT0DAT        : int_12 := 16#012#;
  constant c_Reg_POT1DAT        : int_12 := 16#014#;
  constant c_Reg_POTINP         : int_12 := 16#016#;
  constant c_Reg_SERDATR        : int_12 := 16#018#;
  constant c_Reg_DSKBYTR        : int_12 := 16#01A#;
  constant c_Reg_INTENAR        : int_12 := 16#01C#;
  constant c_Reg_INTREQR        : int_12 := 16#01E#;

  constant c_Reg_DSKPTH         : int_12 := 16#020#;
  constant c_Reg_DSKPTL         : int_12 := 16#022#;
  constant c_Reg_DSKLEN         : int_12 := 16#024#;
  constant c_Reg_DSKDAT         : int_12 := 16#026#;
  constant c_Reg_REFPTR         : int_12 := 16#028#;

  constant c_Reg_VPOSW          : int_12 := 16#02A#;
  constant c_Reg_VHPOSW         : int_12 := 16#02C#;
  constant c_Reg_COPCON         : int_12 := 16#02E#;
  constant c_Reg_SERDAT         : int_12 := 16#030#;
  constant c_Reg_SERPER         : int_12 := 16#032#;
  constant c_Reg_POTGO          : int_12 := 16#034#;
  constant c_Reg_JOYTEST        : int_12 := 16#036#;

  constant c_Reg_STREQU         : int_12 := 16#038#;
  constant c_Reg_STRVBL         : int_12 := 16#03A#;
  constant c_Reg_STRHOR         : int_12 := 16#03C#;
  constant c_Reg_STRLONG        : int_12 := 16#03E#;
  constant c_Reg_BLTCON0        : int_12 := 16#040#;
  constant c_Reg_BLTCON1        : int_12 := 16#042#;
  constant c_Reg_BLTAFWM        : int_12 := 16#044#;
  constant c_Reg_BLTALWM        : int_12 := 16#046#;
  constant c_Reg_BLTCPTH        : int_12 := 16#048#;
  constant c_Reg_BLTCPTL        : int_12 := 16#04A#;
  constant c_Reg_BLTBPTH        : int_12 := 16#04C#;
  constant c_Reg_BLTBPTL        : int_12 := 16#04E#;
  constant c_Reg_BLTAPTH        : int_12 := 16#050#;
  constant c_Reg_BLTAPTL        : int_12 := 16#052#;
  constant c_Reg_BLTDPTH        : int_12 := 16#054#;
  constant c_Reg_BLTDPTL        : int_12 := 16#056#;
  constant c_Reg_BLTSIZE        : int_12 := 16#058#;
                                            -- 5A spare
                                            -- 5C spare
                                            -- 5E spare
  constant c_Reg_BLTCMOD        : int_12 := 16#060#;
  constant c_Reg_BLTBMOD        : int_12 := 16#062#;
  constant c_Reg_BLTAMOD        : int_12 := 16#064#;
  constant c_Reg_BLTDMOD        : int_12 := 16#066#;
                                            -- 68 spare
                                            -- 6A spare
                                            -- 6C spare
                                            -- 6E spare
  constant c_Reg_BLTCDAT        : int_12 := 16#070#;
  constant c_Reg_BLTBDAT        : int_12 := 16#072#;
  constant c_Reg_BLTADAT        : int_12 := 16#074#;
                                            -- 76 spare
                                            -- 78 spare
                                            -- 7A spare
  constant c_Reg_DENISEID       : int_12 := 16#07C#;
  constant c_Reg_DSKSYNC        : int_12 := 16#07E#;

  constant c_Reg_COP1LCH        : int_12 := 16#080#;
  constant c_Reg_COP1LCL        : int_12 := 16#082#;
  constant c_Reg_COP2LCH        : int_12 := 16#084#;
  constant c_Reg_COP2LCL        : int_12 := 16#086#;
  constant c_Reg_COPJMP1        : int_12 := 16#088#;
  constant c_Reg_COPJMP2        : int_12 := 16#08A#;
  constant c_Reg_COPINS         : int_12 := 16#08C#;
  constant c_Reg_DIWSTRT        : int_12 := 16#08E#;
  constant c_Reg_DIWSTOP        : int_12 := 16#090#;
  constant c_Reg_DDFSTRT        : int_12 := 16#092#;
  constant c_Reg_DDFSTOP        : int_12 := 16#094#;
  constant c_Reg_DMACON         : int_12 := 16#096#;
  constant c_Reg_CLXCON         : int_12 := 16#098#;
  constant c_Reg_INTENA         : int_12 := 16#09A#;
  constant c_Reg_INTREQ         : int_12 := 16#09C#;
  constant c_Reg_ADKCON         : int_12 := 16#09E#;

  constant c_Reg_AUD0LCH        : int_12 := 16#0A0#;
  constant c_Reg_AUD0LCL        : int_12 := 16#0A2#;
  constant c_Reg_AUD0LEN        : int_12 := 16#0A4#;
  constant c_Reg_AUD0PER        : int_12 := 16#0A6#;
  constant c_Reg_AUD0VOL        : int_12 := 16#0A8#;
  constant c_Reg_AUD0DAT        : int_12 := 16#0AA#;
                                            -- AC spare
                                            -- AE spare
  constant c_Reg_AUD1LCH        : int_12 := 16#0B0#;
  constant c_Reg_AUD1LCL        : int_12 := 16#0B2#;
  constant c_Reg_AUD1LEN        : int_12 := 16#0B4#;
  constant c_Reg_AUD1PER        : int_12 := 16#0B6#;
  constant c_Reg_AUD1VOL        : int_12 := 16#0B8#;
  constant c_Reg_AUD1DAT        : int_12 := 16#0BA#;
                                            -- BC spare
                                            -- BE spare
  constant c_Reg_AUD2LCH        : int_12 := 16#0C0#;
  constant c_Reg_AUD2LCL        : int_12 := 16#0C2#;
  constant c_Reg_AUD2LEN        : int_12 := 16#0C4#;
  constant c_Reg_AUD2PER        : int_12 := 16#0C6#;
  constant c_Reg_AUD2VOL        : int_12 := 16#0C8#;
  constant c_Reg_AUD2DAT        : int_12 := 16#0CA#;
                                            -- CC spare
                                            -- CE spare
  constant c_Reg_AUD3LCH        : int_12 := 16#0D0#;
  constant c_Reg_AUD3LCL        : int_12 := 16#0D2#;
  constant c_Reg_AUD3LEN        : int_12 := 16#0D4#;
  constant c_Reg_AUD3PER        : int_12 := 16#0D6#;
  constant c_Reg_AUD3VOL        : int_12 := 16#0D8#;
  constant c_Reg_AUD3DAT        : int_12 := 16#0DA#;
                                            -- DC spare
                                            -- DE spare
  constant c_Reg_BPLPTBASE      : int_12 := 16#0E0#;
                                            -- to FE

  constant c_Reg_BPLCON0        : int_12 := 16#100#;
  constant c_Reg_BPLCON1        : int_12 := 16#102#;
  constant c_Reg_BPLCON2        : int_12 := 16#104#;
  constant c_Reg_BPLCON3        : int_12 := 16#106#;
  constant c_Reg_BPL1MOD        : int_12 := 16#108#;
  constant c_Reg_BPL2MOD        : int_12 := 16#10A#;
  constant c_Reg_BPLCON4        : int_12 := 16#10C#;
  constant c_Reg_CLXCON2        : int_12 := 16#10E#;

  constant c_Reg_BPL1DAT        : int_12 := 16#110#;
  constant c_Reg_BPL2DAT        : int_12 := 16#112#;
  constant c_Reg_BPL3DAT        : int_12 := 16#114#;
  constant c_Reg_BPL4DAT        : int_12 := 16#116#;
  constant c_Reg_BPL5DAT        : int_12 := 16#118#;
  constant c_Reg_BPL6DAT        : int_12 := 16#11A#;
  constant c_Reg_BPL7DAT        : int_12 := 16#11C#;
  constant c_Reg_BPL8DAT        : int_12 := 16#11E#;

  constant c_Reg_SPRPTBASE      : int_12 := 16#120#;
  constant c_Reg_SPRPOSCTLBASE  : int_12 := 16#140#;

  constant c_Reg_COLORBASE      : int_12 := 16#180#;

  constant c_Reg_HTOTAL         : int_12 := 16#1C0#;
  constant c_Reg_HSSTOP         : int_12 := 16#1C2#;
  constant c_Reg_HBSTRT         : int_12 := 16#1C4#;
  constant c_Reg_HBSTOP         : int_12 := 16#1C6#;
  constant c_Reg_VTOTAL         : int_12 := 16#1C8#;
  constant c_Reg_VSSTOP         : int_12 := 16#1CA#;
  constant c_Reg_VBSTRT         : int_12 := 16#1CC#;
  constant c_Reg_VBSTOP         : int_12 := 16#1CE#;
  constant c_Reg_BEAMCON0       : int_12 := 16#1DC#;

  constant c_Reg_HSSTRT         : int_12 := 16#1DE#;
  constant c_Reg_VSSTRT         : int_12 := 16#1E0#;
  constant c_Reg_HCENTER        : int_12 := 16#1E2#;
  constant c_Reg_DIWHIGH        : int_12 := 16#1E4#;

  constant c_Reg_SCRDAT         : int_12 := 16#1F0#; -- extension for mouse wheel
  constant c_Reg_FMODE          : int_12 := 16#1FC#;

end;

package body Replay_Amiga_Pack is

end;

