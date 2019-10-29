-- WWW.FPGAArcade.COM
-- REPLAY 1.0
-- Retro Gaming Platform
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
-- Video Display Engine
--
-- Extended clock modes
-- 40.0 MHz, 50.0MHz, 74.25MHz plus sys clock and /n
--

-- i_clk is the sysem clock, base clock * 4 ~= 28MHz
-- i_ena is a one in four clock enable
-- i_cph is a four phase enable. i_cph(3) == i_ena
--     __              __              __
--  __/  \____________/  \____________/  \__                 i_ena
--
--    <P3><P0><P1><P2><P3><P0><P1><P2><P3>                   i_cph


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

  use work.Replay_Pack.all;
  use work.Replay_Amiga_Pack.all;

entity Replay_Amiga_VDE is
  port (
    i_clk               : in  bit1;               
    i_ena               : in  bit1;
    i_cph               : in  word( 3 downto 0);
    i_rst               : in  bit1;
    --
    i_clk_vid           : in  bit1;
    i_rst_vid           : in  bit1;
    --
    i_rd                : in  bit1; 
    i_wr                : in  bit1;
    i_ce                : in  bit1;
    --
    i_addr              : in  word(15 downto 1);
    i_data              : in  word(15 downto 0);
    o_data              : out word(15 downto 0);
    --
    o_irq               : out bit1;
    --
    o_dma_req           : out bit1;
    i_dma_ack           : in  bit1;
    o_dma_addr          : out word(31 downto 0);
    i_dma_data          : in  word(31 downto 0);
    --
    o_display_switch    : out bit1; -- high for us, clk_sys
    o_clock_select      : out word(3 downto 0);
    o_clock_div         : out word(3 downto 0); -- debug
    --
    o_hsync_l           : out bit1;
    o_vsync_l           : out bit1;
    o_blank             : out bit1;
    o_video_rgb         : out word(23 downto 0)
  );
end;

architecture RTL of Replay_Amiga_VDE is
  type t_DisplayMode is (MODE_CLUT, MODE_RGB16, MODE_RGB32, MODE_NONE);

  constant c_VDE_STATUS         : word(15 downto 0) := x"0100";
  constant c_VDE_SWITCH         : word(15 downto 0) := x"0106";
  constant c_VDE_INTREQ         : word(15 downto 0) := x"0108";
  constant c_VDE_INTENA         : word(15 downto 0) := x"010A";
  constant c_VDE_FORMAT         : word(15 downto 0) := x"0110";
  constant c_VDE_FLAGS          : word(15 downto 0) := x"0112";
  constant c_VDE_CLKDIV         : word(15 downto 0) := x"0114";
  constant c_VDE_FBPTRH         : word(15 downto 0) := x"0120";
  constant c_VDE_FBPTRL         : word(15 downto 0) := x"0122";
  constant c_VDE_LNSIZE         : word(15 downto 0) := x"012A"; -- visible line size in bytes
  constant c_VDE_MODULO         : word(15 downto 0) := x"012E"; -- hidden line size in bytes

  constant c_VDE_HTOTAL         : word(15 downto 0) := x"0200";
  constant c_VDE_HDSTOP         : word(15 downto 0) := x"0202";
  constant c_VDE_HSSTRT         : word(15 downto 0) := x"0204";
  constant c_VDE_HSSTOP         : word(15 downto 0) := x"0206";
  constant c_VDE_VTOTAL         : word(15 downto 0) := x"0208";
  constant c_VDE_VDSTOP         : word(15 downto 0) := x"020A";
  constant c_VDE_VSSTRT         : word(15 downto 0) := x"020C";
  constant c_VDE_VSSTOP         : word(15 downto 0) := x"020E";

  constant c_VDE_CLUT           : word(15 downto 0) := x"0400";

  constant c_VDE_SPRCTRL        : word(15 downto 0) := x"2000";
  constant c_VDE_SPRXPOS        : word(15 downto 0) := x"2004";
  constant c_VDE_SPRYPOS        : word(15 downto 0) := x"2006";

  constant c_VDE_SPRCLUT        : word(15 downto 0) := x"2400"; -- sprite colour palette (16x32)
  constant c_VDE_SPRFBUF        : word(15 downto 0) := x"2800"; -- sprite image buffer (2KB)

  -- Picasso96 colour format definitions
  constant c_VDE_RGBFB_NONE     : word( 3 downto 0) := x"0";  -- no valid RGB format
  constant c_VDE_RGBFB_CLUT     : word( 3 downto 0) := x"1";  -- palette mode
  constant c_VDE_RGBFB_R8G8B8   : word( 3 downto 0) := x"2";  -- TrueColor RGB (8 bit each)
  constant c_VDE_RGBFB_B8G8R8   : word( 3 downto 0) := x"3";  -- TrueColor BGR (8 bit each)
  constant c_VDE_RGBFB_R5G6B5PC : word( 3 downto 0) := x"4";  -- HiColor16 (5 bit R, 6 bit G, 5 bit B), format: gggbbbbbrrrrrggg
  constant c_VDE_RGBFB_R5G5B5PC : word( 3 downto 0) := x"5";  -- HiColor15 (5 bit each), format: gggbbbbb0rrrrrgg
  constant c_VDE_RGBFB_A8R8G8B8 : word( 3 downto 0) := x"6";  -- 4 Byte TrueColor ARGB (A unused alpha channel)
  constant c_VDE_RGBFB_A8B8G8R8 : word( 3 downto 0) := x"7";  -- 4 Byte TrueColor ABGR (A unused alpha channel)
  constant c_VDE_RGBFB_R8G8B8A8 : word( 3 downto 0) := x"8";  -- 4 Byte TrueColor RGBA (A unused alpha channel)
  constant c_VDE_RGBFB_B8G8R8A8 : word( 3 downto 0) := x"9";  -- 4 Byte TrueColor BGRA (A unused alpha channel)
  constant c_VDE_RGBFB_R5G6B5   : word( 3 downto 0) := x"A";  -- HiColor16 (5 bit R, 6 bit G, 5 bit B), format: rrrrrggggggbbbbb
  constant c_VDE_RGBFB_R5G5B5   : word( 3 downto 0) := x"B";  -- HiColor15 (5 bit each), format: 0rrrrrgggggbbbbb
  constant c_VDE_RGBFB_B5G6R5PC : word( 3 downto 0) := x"C";  -- HiColor16 (5 bit R, 6 bit G, 5 bit B), format: gggrrrrrbbbbbggg
  constant c_VDE_RGBFB_B5G5R5PC : word( 3 downto 0) := x"D";  -- HiColor15 (5 bit each), format: gggrrrrr0bbbbbbgg
  constant c_VDE_RGBFB_Y4U2V2   : word( 3 downto 0) := x"E";  -- 2 Byte TrueColor YUV
  constant c_VDE_RGBFB_Y4U1V1   : word( 3 downto 0) := x"F";  -- 1 Byte TrueColor ACCUPAK

  -- Mode Info Flags
  constant c_VDE_MIF_INTERLACE     : natural := 1;
  constant c_VDE_MIF_DOUBLESCAN    : natural := 2;
  constant c_VDE_MIF_HSYNCPOLARITY : natural := 3;
  constant c_VDE_MIF_VSYNCPOLARITY : natural := 4;

  -- video params
  signal reg_frame_ptr          : word(31 downto 0);
  signal reg_htotal             : word(15 downto 0);
  signal reg_hdstrt             : word(15 downto 0);
  signal reg_hsstrt             : word(15 downto 0);
  signal reg_hdstop             : word(15 downto 0);
  signal reg_hsstop             : word(15 downto 0);
  signal reg_vtotal             : word(15 downto 0);
  signal reg_vdstop             : word(15 downto 0);
  signal reg_vsstrt             : word(15 downto 0);
  signal reg_vsstop             : word(15 downto 0);

  signal reg_spr_ctrl            : word(15 downto 0);
  signal reg_spr_xpos            : word(15 downto 0);
  signal reg_spr_ypos            : word(15 downto 0);
  signal x_reg_spr_ctrl          : word(15 downto 0);
  signal x_reg_spr_xpos          : word(15 downto 0);
  signal x_reg_spr_ypos          : word(15 downto 0);

  signal reg_line_size          : word(15 downto 0);
  signal reg_line_modulo        : word(15 downto 0);
  signal reg_clk_div            : word(15 downto 0);

  signal reg_display_format     : word( 3 downto 0);
  signal reg_display_flags      : word(15 downto 0);
  signal reg_display_switch     : bit1;
  signal reg_int_ena            : bit1;
  signal do_int_req             : bit1;
  signal int_req                : bit1;

  signal data_in_reg            : word(31 downto 16);

  signal ack                    : bit1;
  signal xfer_ptr               : word(31 downto 0);
  signal xfer_ptr_sol           : word( 1 downto 0);

  signal xfer_cnt               : word(15 downto 0);
  signal next_xfer_cnt          : word(15 downto 0);
  signal xfer_size              : word( 4 downto 0);

  signal hde_meta               : word( 2 downto 0);
  signal vde_meta               : word( 2 downto 0);
  signal line_enable_meta       : word( 1 downto 0);
  signal vcnt_equ_vtotal_meta   : word( 1 downto 0);
  signal sol                    : bit1;
  signal run                    : bit1;
  signal fifo_afull             : bit1;

  signal pre_bta                : bit1;
  signal bta                    : bit1;

  signal first_burst            : bit1;
  signal last_burst             : bit1;
  signal l_ptr                  : word( 3 downto 0);
  signal l_cnt                  : word( 3 downto 0);
  signal first_xfer             : bit1;
  signal last_xfer              : bit1;
  signal xfer_mask              : bit1;
  signal xfer_phase             : word( 1 downto 0);
  signal dma_req                : bit1;

  signal fifo_rst_t             : word( 3 downto 0);
  signal fifo_rst               : bit1;
  signal x_fifo_rst             : bit1;
  signal fifo_w_ena_pipe        : word( 3 downto 0);
  signal fifo_w_ena             : bit1;
  signal fifo_w_data            : word(31 downto 0);
  signal fifo_w_level           : word( 9 downto 0);

  signal x_fifo_r_data          : word(31 downto 0);
  signal x_fifo_valid           : bit1;
  signal x_fifo_taken           : bit1;

  signal display_mode           : t_DisplayMode;
  signal x_display_mode         : t_DisplayMode;
  signal x_reg_display_format   : word( 3 downto 0);

  -- signals with x_ are on video clock domain. V was too confusing
  signal x_clk_cnt              : word( 3 downto 0);
  signal x_ena                  : bit1;
  signal x_ena_t1               : bit1;

  signal x_fifo_r_gate          : bit1;
  signal x_mux_cnt              : word( 1 downto 0);
  signal x_fifo_out_32          : word(31 downto 0);
  signal x_fifo_out_16          : word(15 downto 0);
  signal x_fifo_out_8           : word( 7 downto 0);

  signal x_vid_out_r            : word( 7 downto 0);
  signal x_vid_out_g            : word( 7 downto 0);
  signal x_vid_out_b            : word( 7 downto 0);

  signal x_hcnt_equ_hdstrt      : bit1;
  signal x_hcnt_equ_hdstop      : bit1;
  signal x_hcnt_equ_hsstrt      : bit1;
  signal x_hcnt_equ_hsstop      : bit1;
  signal x_hcnt_equ_htotal      : bit1;

  signal x_vcnt_equ_vdstop      : bit1;
  signal x_vcnt_equ_vsstrt      : bit1;
  signal x_vcnt_equ_vsstop      : bit1;
  signal x_vcnt_equ_vtotal      : bit1;

  signal x_hcnt                 : word(10 downto 0);
  signal x_vcnt                 : word(10 downto 0);
  signal x_line_enable          : bit1;

  signal x_hde                  : bit1;
  signal x_vde                  : bit1;

  signal x_hs                   : bit1;
  signal x_vs                   : bit1;
  signal x_hs_t                 : word( 1 downto 0);
  signal x_vs_t                 : word( 1 downto 0);
  signal x_blank_t              : word( 1 downto 0);

  --
  -- LUTs
  --
  signal clut_w_addr            : word( 8 downto 0);
  signal clut_w_ena             : bit1;
  signal clut_w_in              : word(31 downto 0);
  signal x_clut_r_addr          : word( 8 downto 0);
  signal x_clut_r_out           : word(31 downto 0);

  signal spr_img_w_addr         : word( 8 downto 0);
  signal spr_img_w_in           : word(31 downto 0);
  signal spr_img_w_ena          : bit1;
  signal x_spr_img_r_addr       : word( 8 downto 0);
  signal x_spr_img_r_out        : word(31 downto 0);

  signal spr_lut_w_addr         : word( 3 downto 0);
  signal spr_lut_w_in           : word(23 downto 0);
  signal spr_lut_w_ena          : bit1;
  signal x_spr_lut_r_addr       : word( 3 downto 0);
  signal x_spr_lut_r_out        : word(23 downto 0);

  signal x_spr_xcnt             : word( 4 downto 0);
  signal x_spr_ycnt             : word( 5 downto 0);

  signal x_spr_xsel0            : word( 4 downto 0);
  signal x_spr_xsel1            : word( 4 downto 0);

  signal x_spr_hde              : bit1;
  signal x_spr_vde              : bit1;
  signal x_spr_de               : bit1;
  signal x_spr_de_t1            : bit1;

begin
  -- video clock enable (clk_div) can be used for very low resolutions
  -- however DVI will still see an increased pixel count

  --
  -- Registers
  --
  p_data_reg : process
  begin
    wait until rising_edge(i_clk);
    if (i_ena = '1') then
      -- hold even writes
      if (i_ce = '1') and (i_wr = '1') and (i_addr(1) = '0') then
        data_in_reg(31 downto 16) <= i_data;
      end if;
    end if;
  end process;

  p_registers : process(i_clk, i_rst)
    variable addr : word(15 downto 0);
  begin
    if (i_rst = '1') then

      reg_display_switch <= '0';
      reg_int_ena        <= '0';
      reg_display_format <= c_VDE_RGBFB_CLUT;
      reg_display_flags  <= (others => '0');
      reg_clk_div        <= (others => '0');

      reg_frame_ptr      <= x"02000000";
      reg_line_size      <= to_word(640*4/4,     16); -- in bytes (fetch from memory)
      reg_line_modulo    <= to_word(0,           16);

      reg_htotal         <= to_word(800-1,       16);
      reg_hdstrt         <= to_word(  0,         16); -- not changable
      reg_hdstop         <= to_word(640,         16); -- NO -1

      reg_hsstrt         <= to_word(640+16-1,    16);
      reg_hsstop         <= to_word(640+16+96-1, 16);
      reg_vtotal         <= to_word(525-1,       16);
      reg_vdstop         <= to_word(480-1,       16);

      reg_vsstrt         <= to_word(480+10-1,    16);
      reg_vsstop         <= to_word(480+10+2-1,  16);

      reg_spr_ctrl       <= (others => '0');
      reg_spr_xpos       <= (others => '0');
      reg_spr_ypos       <= (others => '0');
      --pragma translate_off
      reg_line_size      <= to_word(12*4/4,    16); -- in bytes  (each line must be divisible by 32 bit)
      reg_hdstop         <= to_word(4  ,       16); -- NO -1
      reg_vtotal         <= to_word(8-1,       16);
      reg_vdstop         <= to_word(4-1,       16);
      --pragma translate_on

    elsif rising_edge(i_clk) then
      addr := i_addr & '0';

      if (i_ena = '1') then
        if (i_ce = '1') and (i_wr = '1') then
          case (addr) is
            when c_VDE_SWITCH => reg_display_switch <= i_data(0);
            when c_VDE_INTENA => reg_int_ena        <= i_data(0);
            when c_VDE_FORMAT => reg_display_format <= i_data(3 downto 0);
            when c_VDE_FLAGS  => reg_display_flags  <= i_data;
            when c_VDE_CLKDIV => reg_clk_div        <= i_data(15 downto 0); -- sel 11..8, 3..0 divider

            when c_VDE_FBPTRL => reg_frame_ptr      <= data_in_reg & i_data;
            when c_VDE_LNSIZE => reg_line_size      <= i_data;
            when c_VDE_MODULO => reg_line_modulo    <= i_data;

            when c_VDE_HTOTAL => reg_htotal         <= i_data;
            when c_VDE_HDSTOP => reg_hdstop         <= i_data;
            when c_VDE_HSSTRT => reg_hsstrt         <= i_data;
            when c_VDE_HSSTOP => reg_hsstop         <= i_data;
            when c_VDE_VTOTAL => reg_vtotal         <= i_data;
            when c_VDE_VDSTOP => reg_vdstop         <= i_data;
            when c_VDE_VSSTRT => reg_vsstrt         <= i_data;
            when c_VDE_VSSTOP => reg_vsstop         <= i_data;

            when c_VDE_SPRCTRL => reg_spr_ctrl      <= i_data;
            when c_VDE_SPRXPOS => reg_spr_xpos      <= i_data;
            when c_VDE_SPRYPOS => reg_spr_ypos      <= i_data;

            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  p_decode_format : process
  begin
    wait until rising_edge(i_clk);
    display_mode <= MODE_NONE;
    case reg_display_format is
      when c_VDE_RGBFB_CLUT       => display_mode <= MODE_CLUT;
      when c_VDE_RGBFB_R5G6B5PC   => display_mode <= MODE_RGB16;
      when c_VDE_RGBFB_R5G5B5PC   => display_mode <= MODE_RGB16;
      when c_VDE_RGBFB_A8R8G8B8   => display_mode <= MODE_RGB32;
      when c_VDE_RGBFB_A8B8G8R8   => display_mode <= MODE_RGB32;
      when c_VDE_RGBFB_R8G8B8A8   => display_mode <= MODE_RGB32;
      when c_VDE_RGBFB_B8G8R8A8   => display_mode <= MODE_RGB32;
      when c_VDE_RGBFB_R5G6B5     => display_mode <= MODE_RGB16;
      when c_VDE_RGBFB_R5G5B5     => display_mode <= MODE_RGB16;
      when c_VDE_RGBFB_B5G6R5PC   => display_mode <= MODE_RGB16;
      when c_VDE_RGBFB_B5G5R5PC   => display_mode <= MODE_RGB16;
      when others => null;
    end case;
  end process;

  p_meta : process
  begin
    wait until rising_edge(i_clk);
    -- sync display signals to system clock
    hde_meta             <= hde_meta(1 downto 0) & x_hde;
    vde_meta             <= vde_meta(1 downto 0) & x_vde;
    line_enable_meta     <= line_enable_meta(0)  & x_line_enable;
    vcnt_equ_vtotal_meta <= vcnt_equ_vtotal_meta(0) & x_vcnt_equ_vtotal;

    sol <= (not hde_meta(1)) and hde_meta(2); -- falling edge of blank, start of line
  end process;

  p_int_req : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      do_int_req <= '0';
      int_req    <= '0';
    elsif rising_edge(i_clk) then
      -- sync asset to clk_ena
      if (vde_meta(2) = '1') and (vde_meta(1) = '0') then -- falling edge
        do_int_req <= '1';
      elsif (int_req = '1') then
        do_int_req <= '0';
      end if;

      if (i_ena = '1') then
        if (do_int_req = '1') then
          int_req <= '1';
        elsif (i_ce = '1') and (i_rd = '1') and (i_addr = c_VDE_INTREQ(15 downto 1)) then
          int_req <= '0';
        end if;
      end if;
    end if;
  end process;
  o_irq <= reg_int_ena and int_req and reg_display_switch;

  p_reg_read : process(i_addr, i_ce, i_rd, vde_meta, int_req, reg_int_ena)
  begin
    o_data <= x"0000";
    if (i_ce = '1') and (i_rd = '1') then
      if (i_addr = c_VDE_STATUS(15 downto 1)) then
        o_data(15) <= (not vde_meta(1));
      end if;

      if (i_addr = c_VDE_INTREQ(15 downto 1)) then
        o_data(0) <= int_req;
      end if;

      if (i_addr = c_VDE_INTENA(15 downto 1)) then
        o_data(0) <= reg_int_ena;
      end if;

    end if;
  end process;

  p_clock_select : process
  begin
    wait until rising_edge(i_clk);
    if (i_ena = '1') then
      -- top bit high for 2ndary clock, 2..0 select clock
      -- 0xxx = default clock
      if (reg_display_switch = '0') then
        o_clock_select <= "0000";
        o_clock_div    <= reg_clk_div(3 downto 0);
      else
        o_clock_select <= '1' & reg_clk_div(10 downto 8); -- high bit to indicate RTG
        o_clock_div    <= reg_clk_div(3 downto 0);
      end if;
    end if;
  end process;
  --
  -- address generator
  --
  p_dma_ack : process
  begin
    wait until rising_edge(i_clk);
    if (i_cph(0) = '1') then -- ack must come back on phase 1, same as req is sampled
      ack <= i_dma_ack; -- latch it
    end if;
  end process;

  p_xfer_size : process(xfer_ptr, xfer_cnt)
    variable new_xfer_size : word(4 downto 0);
  begin
    new_xfer_size := "10000" - xfer_ptr(3 downto 0);

    if (xfer_cnt(15 downto 0) >= new_xfer_size(4 downto 0)) then
      xfer_size <= new_xfer_size;
    else
      xfer_size <= '0' & xfer_cnt(3 downto 0);
    end if;

  end process;
  next_xfer_cnt <= xfer_cnt - xfer_size;

  p_xfer_ptr : process(i_clk, i_rst)
    variable new_xfer_ptr : word(31 downto 0);
  begin
    if (i_rst = '1') then
      xfer_cnt     <= (others => '0');
      xfer_ptr     <= (others => '0');
      xfer_ptr_sol <= (others => '0');
    elsif rising_edge(i_clk) then
      -- new line offset
      new_xfer_ptr := xfer_ptr - reg_line_size; -- restart line
      if (line_enable_meta(1) = '1') then
        if (vcnt_equ_vtotal_meta(1) = '1') then -- done
          new_xfer_ptr := reg_frame_ptr;
        else
          new_xfer_ptr := xfer_ptr - reg_line_modulo; -- next line
        end if;
      end if;

      if (sol = '1')  then
        if (vde_meta(1) = '1') then
          -- start new line
          xfer_cnt <= reg_line_size;
          xfer_ptr <= new_xfer_ptr;
        else
          xfer_cnt <= (others => '0');
        end if;

      elsif (i_ena = '1') then -- normal ena
        if (ack = '1') then
          -- move along line
          xfer_cnt <= next_xfer_cnt;
          xfer_ptr <= xfer_ptr + xfer_size;
        end if;
      end if;

      if (sol = '1') then
        xfer_ptr_sol <= new_xfer_ptr(1 downto 0);
      end if;

    end if;
  end process;

  o_dma_addr <= xfer_ptr(31 downto 4) & "0000";

  p_run : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      run        <= '0';
      dma_req    <= '0';
      fifo_afull <= '1';
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then
        if (run = '0') and (red_or(xfer_cnt) = '1') and (reg_display_switch = '1') then
        -- disable fetch if RTG not enabled
          run     <= '1';
          dma_req <= (not fifo_afull);
        elsif (run = '1') and (red_or(next_xfer_cnt) = '0') then
          run     <= '0';
          dma_req <= '0';
        elsif (run = '1') then
          dma_req <= (not fifo_afull);
        end if;

        fifo_afull <= red_or(fifo_w_level(9 downto 8));
      end if;
    end if;
  end process;

  o_dma_req <= dma_req;

  p_burst_ctrl : process(i_clk, i_rst)
    variable first_xfer : bit1;
    variable last_xfer  : bit1;
  begin
    if (i_rst = '1') then
      l_ptr       <= (others => '0');
      bta         <= '0';
      first_burst <= '0';
      last_burst  <= '0';
      l_cnt       <= (others => '0');

    elsif rising_edge(i_clk) then
      if (i_cph(1) = '1') then
        pre_bta <= ack;
        l_ptr   <= xfer_ptr(3 downto 0);
      end if;

      bta <= pre_bta;

      if (sol = '1') then
        first_burst <= '1';
      elsif (i_cph(1) = '1') and (bta = '1') then
        first_burst <= '0';
      end if;

      if (i_cph(2) = '1') then
        last_burst <= not red_or(next_xfer_cnt);
        l_cnt      <= xfer_ptr(3 downto 0) + xfer_cnt(3 downto 0) + "0011";
      end if;

    end if;
  end process;

  p_xfer_phase : process
  begin
    wait until rising_edge(i_clk);
    xfer_phase <= xfer_phase + "1";
    if (i_cph(1) = '1') then
      xfer_phase <= "00";
    end if;
  end process;

  p_xfer_ends : process(first_burst, last_burst, pre_bta, bta, l_ptr, l_cnt, xfer_phase)
  begin
    first_xfer <= '0';
    if (l_ptr(3 downto 2) = xfer_phase) then
      if (first_burst = '1') and (pre_bta = '1') then
        first_xfer <= '1';
      end if;
    end if;

    last_xfer <= '0';
    if (l_cnt(3 downto 2) = xfer_phase) then
      if (last_burst = '1') and (bta = '1') then
        last_xfer <= '1';
      end if;
    end if;
  end process;

  p_xfer_mask : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      xfer_mask <= '0';
    elsif rising_edge(i_clk) then
      if (first_xfer = '1') then
        xfer_mask <= '1';
      elsif (last_xfer = '1') then
        xfer_mask <= '0';
      end if;
    end if;
  end process;
  -- xfer mask and bta is correctly times for data arriving on the HP mem interface
  -- the video one is 2 sys clocks behind however.

  p_fifo_w_ena_pipe : process
  begin
    wait until rising_edge(i_clk);
    fifo_w_ena_pipe <= fifo_w_ena_pipe(2 downto 0) & (bta and xfer_mask);

    fifo_w_ena  <= fifo_w_ena_pipe(1);
    fifo_w_data <= i_dma_data;
  end process;

  p_fifo_rst : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      fifo_rst_t <= (others => '1');
      fifo_rst <= '1';
    elsif rising_edge(i_clk) then
      fifo_rst_t(0) <= '0';
      if (vde_meta(2) = '1') and (vde_meta(1) = '0') then -- falling edge
        fifo_rst_t(0) <= '1';
      end if;

      fifo_rst_t(3 downto 1) <= fifo_rst_t(2 downto 0);
      fifo_rst <= red_or(fifo_rst_t);
    end if;
  end process;

  --
  -- ASYNC FIFO
  --
  u_fifo : entity work.FIFO_ASync
  generic map (
    g_width       => 32,
    g_depth       => 9
  ) port map (
    i_w_data      => fifo_w_data,
    i_w_ena       => fifo_w_ena,
    o_w_full      => open,
    o_w_level     => fifo_w_level,

    o_r_data      => x_fifo_r_data,
    i_r_taken     => x_fifo_taken,
    o_r_valid     => x_fifo_valid,
    --
    i_rst         => x_fifo_rst, -- async
    i_clk_w       => i_clk,
    i_clk_r       => i_clk_vid
  );

  -- make FIFO fall through

  --
  -- (mainly) vid clock domain from here on
  --

  p_vid_ena : process(i_clk_vid, i_rst_vid)
  begin
    if (i_rst_vid = '1') then
      x_clk_cnt <= (others => '0');
      x_ena     <= '0';
    elsif rising_edge(i_clk_vid) then

      x_ena     <= '0';
      if (x_clk_cnt = "0000") then
        x_clk_cnt <= reg_clk_div(3 downto 0); -- META, but static so OK
        x_ena     <= '1';
      else
        x_clk_cnt <= x_clk_cnt - "1";
      end if;
    end if;
  end process;

  p_vid_meta : process
  begin
    wait until rising_edge(i_clk_vid);
    x_display_mode       <= display_mode; -- META, static
    x_reg_display_format <= reg_display_format; -- META, static
    --
    x_ena_t1   <= x_ena; -- delay ena
    --
    x_fifo_rst <= fifo_rst;
  end process;

  x_fifo_taken <= x_hde and x_vde and x_fifo_r_gate and x_ena_t1;

  p_vid_mux_ctrl : process(i_clk_vid, x_fifo_rst)
    variable inc : word(1 downto 0);
  begin
    if (x_fifo_rst = '1') then
      x_mux_cnt <= "00";
    elsif rising_edge(i_clk_vid) then
      -- step size
      inc := "00";
      case x_display_mode is
        when MODE_CLUT  => inc := "01";
        when MODE_RGB16 => inc := "10";
        when MODE_RGB32 => inc := "10";
        when others => null;
      end case;

      if (x_ena_t1 = '1') then
        if (x_hde = '1') then
          x_mux_cnt <= x_mux_cnt + inc;  -- 0 for first pixel (ref x_hde)
        else
          x_mux_cnt <= xfer_ptr_sol; -- META
        end if;
      end if;
    end if;
  end process;

  p_fifo_step : process(x_mux_cnt, x_display_mode)
  begin
    x_fifo_r_gate <= '0';
    case x_display_mode is
      when MODE_CLUT  => x_fifo_r_gate <= red_and(x_mux_cnt);
      when MODE_RGB16 => x_fifo_r_gate <= x_mux_cnt(1);
      when MODE_RGB32 => x_fifo_r_gate <= '1';
      when others => null;
    end case;
  end process;

  p_fifo_demux : process
  begin
    wait until rising_edge(i_clk_vid);

    x_fifo_out_16 <= x_fifo_r_data(31 downto 16);
    if (x_mux_cnt(1) = '1') then
      x_fifo_out_16 <= x_fifo_r_data(15 downto  0);
    end if;

    x_fifo_out_8 <= x_fifo_r_data(31 downto 24);
    case x_mux_cnt is
      when "00" => x_fifo_out_8 <= x_fifo_r_data(31 downto 24);
      when "01" => x_fifo_out_8 <= x_fifo_r_data(23 downto 16);
      when "10" => x_fifo_out_8 <= x_fifo_r_data(15 downto  8);
      when "11" => x_fifo_out_8 <= x_fifo_r_data( 7 downto  0);
      when others => null;
    end case;

    x_fifo_out_32 <= x_fifo_r_data(31 downto 0);
  end process;

  p_fifo_repack : process
  begin
    wait until rising_edge(i_clk_vid);

    x_vid_out_r <= x"80";
    x_vid_out_g <= x"00";
    x_vid_out_b <= x"00";

    case x_reg_display_format is
      --when c_VDE_RGBFB_R8G8B8   =>
      --when c_VDE_RGBFB_B8G8R8   =>
      when c_VDE_RGBFB_R5G6B5PC => x_vid_out_r <= x_fifo_out_16( 7 downto 3) & "000";  -- gggbbbbb rrrrrggg
                                   x_vid_out_g <= x_fifo_out_16( 2 downto 0) & x_fifo_out_16(15 downto 13) & "00";
                                   x_vid_out_b <= x_fifo_out_16(12 downto 8) & "000";

      when c_VDE_RGBFB_R5G5B5PC => x_vid_out_r <= x_fifo_out_16( 6 downto 2) & "000";   -- gggbbbbb 0rrrrrgg
                                   x_vid_out_g <= x_fifo_out_16( 1 downto 0) & x_fifo_out_16(15 downto 13) & "000";
                                   x_vid_out_b <= x_fifo_out_16(12 downto 8) & "000";

      when c_VDE_RGBFB_A8R8G8B8 => x_vid_out_r <= x_fifo_out_32(23 downto 16);
                                   x_vid_out_g <= x_fifo_out_32(15 downto  8);
                                   x_vid_out_b <= x_fifo_out_32( 7 downto  0);

      when c_VDE_RGBFB_A8B8G8R8 => x_vid_out_r <= x_fifo_out_32( 7 downto  0);
                                   x_vid_out_g <= x_fifo_out_32(15 downto  8);
                                   x_vid_out_b <= x_fifo_out_32(23 downto 16);

      when c_VDE_RGBFB_R8G8B8A8 => x_vid_out_r <= x_fifo_out_32(31 downto 24);
                                   x_vid_out_g <= x_fifo_out_32(23 downto 16);
                                   x_vid_out_b <= x_fifo_out_32(15 downto  8);

      when c_VDE_RGBFB_B8G8R8A8 => x_vid_out_r <= x_fifo_out_32(15 downto  8);
                                   x_vid_out_g <= x_fifo_out_32(23 downto 16);
                                   x_vid_out_b <= x_fifo_out_32(31 downto 24);

      when c_VDE_RGBFB_R5G6B5 =>   x_vid_out_r <= x_fifo_out_16(15 downto 11) & "000"; -- rrrrrggggggbbbbb
                                   x_vid_out_g <= x_fifo_out_16(10 downto  5) & "00";
                                   x_vid_out_b <= x_fifo_out_16( 4 downto  0) & "000";

      when c_VDE_RGBFB_R5G5B5 =>   x_vid_out_r <= x_fifo_out_16(14 downto 10) & "000"; -- 0rrrrrgggggbbbbb
                                   x_vid_out_g <= x_fifo_out_16( 9 downto  5) & "000";
                                   x_vid_out_b <= x_fifo_out_16( 4 downto  0) & "000";

      when c_VDE_RGBFB_B5G6R5PC => x_vid_out_r <= x_fifo_out_16(12 downto  8) & "000"; -- gggrrrrrbbbbbggg
                                   x_vid_out_g <= x_fifo_out_16( 2 downto  0) & x_fifo_out_16(15 downto 13) & "00";
                                   x_vid_out_b <= x_fifo_out_16( 7 downto  3) & "000";

      when c_VDE_RGBFB_B5G5R5PC => x_vid_out_r <= x_fifo_out_16(12 downto  8) & "000"; -- gggrrrrr0bbbbbgg
                                   x_vid_out_g <= x_fifo_out_16( 1 downto  0) & x_fifo_out_16(15 downto 13) & "000";
                                   x_vid_out_b <= x_fifo_out_16( 6 downto  2) & "000";

      when others => null;
    end case;
  end process;

--================================================================================
     --CLUT
--================================================================================

  clut_w_addr <= '0' & i_addr(9 downto 2);
  clut_w_in   <= x"00" & data_in_reg(23 downto 16) & i_data(15 downto 0);

  p_clut_we : process(i_ena, i_ce, i_wr, i_addr)
  begin
    clut_w_ena  <= '0';
    if (i_ena = '1') then
      if (i_ce = '1') and (i_wr = '1') and (i_addr(1) = '1') then
        if (i_addr(15 downto 10) = c_VDE_CLUT(15 downto 10)) then
          clut_w_ena  <= '1';
        end if;
      end if;
    end if;
  end process;

  u_lut : entity work.RAM_DP
  generic map (
    g_width        => 32,
    g_depth        => 9,
    g_has_a_read   => false,
    g_has_b_write  => false
  ) port map (
    i_a_addr      => clut_w_addr,
    i_a_data      => clut_w_in(31 downto 0),
    o_a_data      => open,
    --
    i_a_write     => clut_w_ena,
    i_a_ena       => '1',
    i_a_clk       => i_clk,

    i_b_addr      => x_clut_r_addr,
    i_b_data      => x"00000000",
    o_b_data      => x_clut_r_out,

    i_b_write     => '0',
    i_b_ena       => '1',
    i_b_clk       => i_clk_vid
  );

  x_clut_r_addr <= '0' & x_fifo_out_8; -- space for a second set here (512 entries)
  --
  -- Sprite
  --
  spr_img_w_addr <= i_addr(10 downto 2);
  spr_img_w_in   <= data_in_reg(31 downto 16) & i_data(15 downto 0);

  spr_lut_w_addr <= i_addr( 5 downto 2);
  spr_lut_w_in   <= data_in_reg(23 downto 16) & i_data(15 downto 0);

  p_sprite_we : process(i_ena, i_ce, i_wr, i_addr)
  begin
    spr_img_w_ena <= '0';
    spr_lut_w_ena <= '0';

    if (i_ena = '1') then
      if (i_ce = '1') and (i_wr = '1') and (i_addr(1) = '1') then
        if (i_addr(15 downto 11) = c_VDE_SPRFBUF(15 downto 11)) then
          spr_img_w_ena <= '1';
        end if;

        if (i_addr(15 downto  6) = c_VDE_SPRCLUT(15 downto  6)) then
          spr_lut_w_ena <= '1';
        end if;
      end if;
    end if;
  end process;

  p_sprite_pos : process(i_clk_vid, i_rst_vid)
  begin
    if (i_rst_vid = '1') then
      x_spr_hde  <= '0';
      x_spr_vde  <= '0';
      x_spr_xcnt <= (others => '0');
      x_spr_ycnt <= (others => '0');
    elsif rising_edge(i_clk_vid) then
      if (x_ena_t1 = '1') then
        --
        if (x_hcnt = x_reg_spr_xpos) then
          x_spr_hde <= '1';
        elsif (red_and(x_spr_xcnt) = '1') then
          x_spr_hde <= '0';
        end if;
        --
        if (x_vcnt = x_reg_spr_ypos) then
          x_spr_vde <= '1';
        elsif ((red_and(x_spr_xcnt) = '1') and (red_and(x_spr_ycnt) = '1')) then
          x_spr_vde <= '0';
        end if;
        --
        if (x_spr_hde = '1') then
          x_spr_xcnt <= x_spr_xcnt + "1";
        end if;

        if (x_spr_vde = '1') and (red_and(x_spr_xcnt) = '1') and (x_line_enable = '1') then
          x_spr_ycnt <= x_spr_ycnt + "1";
        end if;
      end if;
    end if;
  end process;

  x_spr_img_r_addr <= "00" & x_spr_ycnt & x_spr_xcnt(4);

  u_sprite_img : entity work.RAM_DP
  generic map (
    g_width        => 32,
    g_depth        => 9,
    g_has_a_read   => true,
    g_has_b_write  => false
  ) port map (
    i_a_addr      => spr_img_w_addr,
    i_a_data      => spr_img_w_in,
    o_a_data      => open,
    --
    i_a_write     => spr_img_w_ena,
    i_a_ena       => '1',
    i_a_clk       => i_clk,

    i_b_addr      => x_spr_img_r_addr,
    i_b_data      => x"00000000",
    o_b_data      => x_spr_img_r_out,

    i_b_write     => '0',
    i_b_ena       => '1',
    i_b_clk       => i_clk_vid
  );

  p_sprite_reg : process
  begin
    wait until rising_edge(i_clk_vid);

    -- match clock delay throguh sprite_img
    x_spr_xsel0 <= '0' & not x_spr_xcnt(3 downto 0); -- pixel sel
    x_spr_xsel1 <= '1' & not x_spr_xcnt(3 downto 0); -- pixel sel

    x_spr_lut_r_addr(3) <= '0';
    x_spr_lut_r_addr(2) <= '0';
    x_spr_lut_r_addr(1) <= x_spr_img_r_out(to_integer(unsigned(x_spr_xsel0)));
    x_spr_lut_r_addr(0) <= x_spr_img_r_out(to_integer(unsigned(x_spr_xsel1)));

    -- move sprite registers to video domain. Plug once per frame?
    x_reg_spr_xpos <= reg_spr_xpos;
    x_reg_spr_ypos <= reg_spr_ypos;
    x_reg_spr_ctrl <= reg_spr_ctrl;

    -- pipe
    x_spr_de    <= x_reg_spr_ctrl(0) and x_spr_hde and x_spr_vde; -- spr_ctrl(0) enable sprite display
    x_spr_de_t1 <= x_spr_de;

  end process;

  u_sprite_lut : entity work.RAM_LUT
    generic map (
      g_width       => 24
      )
    port map (
      i_a_addr      => spr_lut_w_addr,
      i_a_data      => spr_lut_w_in,
      i_a_write     => spr_lut_w_ena,
      i_a_clk       => i_clk,

      i_b_addr      => x_spr_lut_r_addr,
      o_b_data      => x_spr_lut_r_out
      );
  --
  -- Display Generator
  --

  -- META, but static so OK....
  x_hcnt_equ_hdstrt <= '1' when (x_hcnt = reg_hdstrt(10 downto 0)) else '0';
  x_hcnt_equ_hdstop <= '1' when (x_hcnt = reg_hdstop(10 downto 0)) else '0';
  x_hcnt_equ_hsstrt <= '1' when (x_hcnt = reg_hsstrt(10 downto 0)) else '0';
  x_hcnt_equ_hsstop <= '1' when (x_hcnt = reg_hsstop(10 downto 0)) else '0';
  x_hcnt_equ_htotal <= '1' when (x_hcnt = reg_htotal(10 downto 0)) else '0';

  x_vcnt_equ_vdstop <= '1' when (x_vcnt = reg_vdstop(10 downto 0)) else '0';
  x_vcnt_equ_vsstrt <= '1' when (x_vcnt = reg_vsstrt(10 downto 0)) else '0';
  x_vcnt_equ_vsstop <= '1' when (x_vcnt = reg_vsstop(10 downto 0)) else '0';
  x_vcnt_equ_vtotal <= '1' when (x_vcnt = reg_vtotal(10 downto 0)) else '0';

  p_vid_display_counters : process(i_clk_vid, i_rst_vid)
  begin
    if (i_rst_vid = '1') then
      x_hcnt        <= (others => '0');
      x_vcnt        <= (others => '0');
      --pragma translate_off
      x_vcnt        <= to_word(525-5, 11);
      --x_vcnt        <= to_word(5, 11);
      --pragma translate_on
      x_line_enable <= '0';
    elsif rising_edge(i_clk_vid) then
      if (x_ena_t1 = '1') then
        if (x_hcnt_equ_htotal = '1') then
          -- new line
          x_hcnt        <= (others => '0');
          x_line_enable <= (not x_line_enable) or (not reg_display_flags(c_VDE_MIF_DOUBLESCAN));
          --
          if (x_line_enable = '1') then
            if (x_vcnt_equ_vtotal = '1') then
              x_vcnt <= (others => '0');
            else
              x_vcnt <= x_vcnt + "1";
            end if;
          end if;
        else
          x_hcnt <= x_hcnt + "1";
        end if;
      end if;
    end if;
  end process;

  p_vid_display_enable : process(i_clk_vid, i_rst_vid)
  begin
    if (i_rst_vid = '1') then
      x_hde <= '0';
      x_vde <= '0';
    elsif rising_edge(i_clk_vid) then
      if (x_ena_t1 = '1') then
        if    (x_hcnt_equ_hdstrt = '1') then
          x_hde <= '1';
        elsif (x_hcnt_equ_hdstop = '1') then
          x_hde <= '0';
          if (x_line_enable = '1') then
            if    (x_vcnt_equ_vtotal = '1') then
              x_vde <= '1'; -- enabled here (and not at the end of the line) to prefetch next display line
            elsif (x_vcnt_equ_vdstop = '1') then
              x_vde <= '0';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  p_vid_sync : process(i_clk_vid, i_rst_vid)
  begin
    if (i_rst_vid = '1') then
      x_hs <= '0';
      x_vs <= '0';
    elsif rising_edge(i_clk_vid) then
      if (x_ena_t1 = '1') then
        if    (x_hcnt_equ_hsstrt = '1') then
          x_hs <= '1';
          if (x_line_enable = '1') then
            if    (x_vcnt_equ_vsstrt = '1') then
              x_vs <= '1';
            elsif (x_vcnt_equ_vsstop = '1') then
              x_vs <= '0';
            end if;
          end if;
        elsif (x_hcnt_equ_hsstop = '1') then
          x_hs <= '0';
        end if;

      end if;
    end if;
  end process;

  -- pipe to compensate for LUT delays
  p_vid_sync_t : process
  begin
    wait until rising_edge(i_clk_vid);
    --if (x_ena_t1 = '1') then
      x_hs_t(1 downto 0) <= x_hs_t(0) & (x_hs xor reg_display_flags(c_VDE_MIF_HSYNCPOLARITY));
      x_vs_t(1 downto 0) <= x_vs_t(0) & (x_vs xor reg_display_flags(c_VDE_MIF_VSYNCPOLARITY));
      -- and blanking
      x_blank_t(1 downto 0) <= x_blank_t(0) & (not (x_hde and x_vde));
    --end if;
  end process;

  p_video_out_mux : process
  begin
    wait until rising_edge(i_clk_vid);

    -- 3 clocks (including this one) after ena_t1
    o_video_rgb <= (others => '0');
    if (x_blank_t(1) = '0') then
      if (x_spr_de_t1 = '1') and (red_or(x_spr_lut_r_addr) = '1') then
        o_video_rgb(23 downto  0) <= x_spr_lut_r_out(23 downto 0);
      elsif (x_display_mode = MODE_CLUT) then
        o_video_rgb(23 downto  0) <= x_clut_r_out(23 downto 0); -- 2 clocks after hde
      else
        o_video_rgb(23 downto 16) <= x_vid_out_r;
        o_video_rgb(15 downto  8) <= x_vid_out_g;
        o_video_rgb( 7 downto  0) <= x_vid_out_b;
       end if;
    end if;

    o_hsync_l <= x_hs_t(1);
    o_vsync_l <= x_vs_t(1);
    o_blank   <= x_blank_t(1);

    o_display_switch <= reg_display_switch;

  end process;

end RTL;