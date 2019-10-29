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
-- Video Blitter Engine
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

  use work.Replay_Pack.all;
  use work.Replay_Amiga_Pack.all;

entity Replay_Amiga_VBE is
  port (
    i_clk               : in  bit1;
    i_ena               : in  bit1;
    i_rst               : in  bit1;
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
    --
    o_dma_rw_l          : out bit1;
    o_dma_bs_l          : out word( 3 downto 0); -- BS0_L is 31..24, BS3_L is 7..0 same as to 68060
    --
    o_dma_addr          : out word(31 downto 0);
    i_dma_data          : in  word(31 downto 0);
    o_dma_data          : out word(31 downto 0)
  );
end;

architecture RTL of Replay_Amiga_VBE is

  constant c_VBE_SRCPTRH : word(15 downto 0) := x"1000";
  constant c_VBE_SRCPTRL : word(15 downto 0) := x"1002";
  constant c_VBE_DSTPTRH : word(15 downto 0) := x"100C";
  constant c_VBE_DSTPTRL : word(15 downto 0) := x"100E";
  constant c_VBE_SRCMODH : word(15 downto 0) := x"1010";
  constant c_VBE_SRCMODL : word(15 downto 0) := x"1012";
  constant c_VBE_DSTMODH : word(15 downto 0) := x"101C";
  constant c_VBE_DSTMODL : word(15 downto 0) := x"101E";
  constant c_VBE_SIZEX   : word(15 downto 0) := x"1020";
  constant c_VBE_SIZEY   : word(15 downto 0) := x"1022";
  constant c_VBE_CONTROL : word(15 downto 0) := x"1030";
  constant c_VBE_STATUS  : word(15 downto 0) := x"1040";
  constant c_VBE_CAPS    : word(15 downto 0) := x"1048";

  type t_State is (S_IDLE, S_LOAD, S_STORE);
  signal state                  : t_State;
  signal next_state             : t_State;

  signal dma_we                 : bit1;
  signal dma_req                : bit1;
  signal dma_addr               : word(25 downto 2);
  signal dma_data               : word(31 downto 0);

  signal size_x                 : word(15 downto 0);
  signal size_y                 : word(15 downto 0);
  signal reverse                : bit1;
  signal busy                   : bit1;

  signal src_ptr                : word(31 downto 0);
  signal src_mod                : word(15 downto 0);
  signal src_size               : word( 2 downto 0);
  signal src_cnt                : word(15 downto 0);
  signal src_new_size           : word( 2 downto 0);
  signal src_new_cnt            : word(15 downto 0);

  signal first_load             : bit1;
  signal last_load              : bit1;
  signal last_load_t            : bit1;

  signal dst_ptr                : word(31 downto 0);
  signal dst_mod                : word(15 downto 0);
  signal dst_size               : word( 2 downto 0);
  signal dst_cnt                : word(15 downto 0);
  signal dst_new_size           : word( 2 downto 0);
  signal dst_new_cnt            : word(15 downto 0);

  signal first_store            : bit1;
  signal last_store             : bit1;

  signal shift                  : word( 1 downto 0);

  signal first_store_mask       : word( 3 downto 0);
  signal last_store_mask        : word( 3 downto 0);
  signal first_mask             : word( 3 downto 0);
  signal last_mask              : word( 3 downto 0);

  signal last_line              : bit1;
  signal data_reg               : word(63 downto 0);

begin
  --
  -- pointers
  --
  p_src_ptr : process(i_clk, i_rst)
    variable offset : word(15 downto 0);
  begin
    if (i_rst = '1') then
      src_ptr <= (others => '0');
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then
        if    (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_SRCPTRH(15 downto 1)) then
          src_ptr(31 downto 16) <= i_data;

        elsif (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_SRCPTRL(15 downto 1)) then
          src_ptr(15 downto  0) <= i_data;

        elsif (state = S_LOAD) and (i_dma_ack = '1') then

          if (last_load = '1') then
            offset := ("0000000000000" & src_size) + src_mod;
          else
            offset :=  "0000000000000" & src_size;
          end if;

          if (reverse = '1') then
            src_ptr <= src_ptr - offset;
          else -- forward
            src_ptr <= src_ptr + offset;
          end if;

        end if;
      end if;
    end if;
  end process;

  p_dst_ptr : process(i_clk, i_rst)
    variable offset : word(15 downto 0);
  begin
    if (i_rst = '1') then
      dst_ptr <= (others => '0');
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then
        if    (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_DSTPTRH(15 downto 1)) then
          dst_ptr(31 downto 16) <= i_data;

        elsif (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_DSTPTRL(15 downto 1)) then
          dst_ptr(15 downto  0) <= i_data;

        elsif (state = S_STORE) and (i_dma_ack = '1') then

          if (last_store = '1') then
            offset := ("0000000000000" & dst_size) + dst_mod;
          else
            offset :=  "0000000000000" & dst_size;
          end if;

          if (reverse = '1') then
            dst_ptr <= dst_ptr - offset;
          else -- forward
            dst_ptr <= dst_ptr + offset;
          end if;

        end if;
      end if;
    end if;
  end process;
  --
  -- Registers
  --
  p_reg : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      src_mod <= (others => '0');
      dst_mod <= (others => '0');
      size_x  <= (others => '0');
      size_y  <= (others => '0');
      busy    <= '0';
      reverse <= '0';
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then

        if (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_SRCMODL(15 downto 1)) then
          src_mod(15 downto 0) <= i_data;
        end if;

        if (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_DSTMODL(15 downto 1)) then
          dst_mod(15 downto 0) <= i_data;
        end if;

        if (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_SIZEX(15 downto 1)) then
          size_x(15 downto 0) <= i_data;
        end if;

        if (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_SIZEY(15 downto 1)) then
          size_y(15 downto 0) <= i_data;
          busy                <= '1';
        else
          if (state = S_STORE) and (last_store = '1') and (i_dma_ack = '1') then
            size_y <= size_y - "1";
          end if;

          if (state = S_STORE) and (next_state = S_IDLE) then -- finished
            busy <= '0';
          end if;
        end if;

        if (i_ce = '1') and (i_wr = '1') and (i_addr = c_VBE_CONTROL(15 downto 1)) then
          reverse <= i_data(0);
        end if;

      end if;
    end if;
  end process;

  p_reg_read : process(i_addr, i_ce, i_rd, busy)
  begin
    o_data <= x"0000";
    if (i_ce = '1') and (i_rd = '1') then
      if (i_addr = c_VBE_STATUS(15 downto 1)) then
        o_data(15) <= busy;
        o_data( 0) <= '1';
      end if;

      if (i_addr = c_VBE_CAPS(15 downto 1)) then
        o_data(15 downto 8) <= x"42";
        o_data( 0) <= '1'; -- base
      end if;
    end if;
  end process;

  --
  -- DMA state machine
  --
  p_state : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      state <= S_IDLE;
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then
        state <= next_state;
      end if;
    end if;
  end process;

  p_next_date : process(state, i_dma_ack, src_ptr, dst_ptr, first_load, last_load_t,
                        src_size, dst_size, busy, last_store, last_line)
  begin
    dma_req  <= '0';
    dma_we   <= '0';
    dma_addr <= (others => '0');

    next_state <= state; -- default stay put

    case state is
      when S_IDLE =>
        if (busy = '1') then
          next_state <= S_LOAD;
        end if;

      when S_LOAD =>

        dma_req  <= '1';
        dma_we   <= '0';
        dma_addr(25 downto 2) <= src_ptr(25 downto 2);

        if (i_dma_ack = '1') then
          if (first_load = '1') and (src_size < dst_size) then
            next_state <= S_LOAD; -- stay put
          else
            next_state <= S_STORE;
          end if;
        end if;

      when S_STORE =>

        dma_req  <= '1';
        dma_we   <= '1';
        dma_addr(25 downto 2) <= dst_ptr(25 downto 2);

        if (i_dma_ack = '1') then

          if (last_store = '1') then

            if (last_line = '1') then
              next_state <= S_IDLE; -- done
            else
              next_state <= S_LOAD;
            end if;

          elsif (last_load_t = '1') then
            next_state <= S_STORE;
          else
            next_state <= S_LOAD;
          end if;
        end if;

      when others => null;
    end case;
  end process;
  --
  -- size calc
  --
  p_new_size : process(reverse, src_ptr, dst_ptr)
  begin
    if (reverse = '1') then
      src_new_size <= ('0' & src_ptr(1 downto 0)) + "1";
      dst_new_size <= ('0' & dst_ptr(1 downto 0)) + "1";
    else
      src_new_size <= "100" - src_ptr(1 downto 0);
      dst_new_size <= "100" - dst_ptr(1 downto 0);
    end if;
  end process;

  p_size : process(src_cnt, src_new_size, dst_cnt, dst_new_size)
  begin
    if (src_cnt < ("0000000000000" & src_new_size)) then
      src_size <= src_cnt(2 downto 0);
    else
      src_size <= src_new_size;
    end if;

    if (dst_cnt < ("0000000000000" & dst_new_size)) then
      dst_size <= dst_cnt(2 downto 0);
    else
      dst_size <= dst_new_size;
    end if;

  end process;

  src_new_cnt <= src_cnt - src_size;
  dst_new_cnt <= dst_cnt - dst_size;

  --
  -- counters
  --
  p_count : process(i_clk, i_rst)
    variable cnt_rld : bit1;
  begin
    if (i_rst = '1') then
      src_cnt <= (others => '0');
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then
        --
        cnt_rld := '0';
        if (state = S_IDLE) or
           ((state = S_STORE) and (last_store = '1') and (i_dma_ack = '1')) then
          cnt_rld := '1';
        end if;
        --
        if (cnt_rld = '1') then
          src_cnt <= size_x;
        elsif (state = S_LOAD) and (i_dma_ack = '1') then
          src_cnt <= src_new_cnt;
        end if;

        if (cnt_rld = '1') then
          dst_cnt <= size_x;
        elsif (state = S_STORE) and (i_dma_ack = '1') then
          dst_cnt <= dst_new_cnt;
        end if;

      end if;
    end if;
  end process;
  --
  --
  --
  first_load  <= '1' when (    src_cnt = size_x ) else '0';
  last_load   <= '1' when (src_new_cnt = x"0000") else '0';

  first_store <= '1' when (    dst_cnt = size_x ) else '0';
  last_store  <= '1' when (dst_new_cnt = x"0000") else '0';

  last_line   <= '1' when (     size_y = x"0001") else '0';
  --
  --
  --
  p_shift : process(i_clk, i_rst)
  begin
    if (i_rst = '1') then
      last_load_t <= '0';
      shift       <= "00";
    elsif rising_edge(i_clk) then
      if (i_ena = '1') then
        if (i_dma_ack = '1') and (dma_we = '0') then
          last_load_t <= last_load;
        end if;

        if (i_dma_ack = '1') and (state = S_LOAD) and (first_load = '1') then
          if (reverse = '1') then
            shift <= src_ptr(1 downto 0) - dst_ptr(1 downto 0);
          else
            shift <= dst_ptr(1 downto 0) - src_ptr(1 downto 0);
          end if;
        end if;
      end if;
    end if;
  end process;

  p_first_store_mask : process(reverse, dst_ptr)
  begin
    first_store_mask <= "1000";
    if (reverse = '1') then
      case dst_ptr(1 downto 0) is
        when "00" => first_store_mask <= "1000";
        when "01" => first_store_mask <= "1100";
        when "10" => first_store_mask <= "1110";
        when "11" => first_store_mask <= "1111";
        when others => null;
      end case;
    else
      case dst_ptr(1 downto 0) is
        when "00" => first_store_mask <= "1111";
        when "01" => first_store_mask <= "0111";
        when "10" => first_store_mask <= "0011";
        when "11" => first_store_mask <= "0001";
        when others => null;
      end case;
    end if;
  end process;

  p_last_store_mask : process(reverse, dst_cnt, dst_ptr)
    variable last_store_cnt     : word( 1 downto 0);
    variable last_store_cnt_rev : word( 1 downto 0);
  begin
    last_store_cnt     := dst_cnt(1 downto 0) + dst_ptr(1 downto 0);
    last_store_cnt_rev := dst_cnt(1 downto 0) - dst_ptr(1 downto 0);

    last_store_mask <= "1000";
    if (reverse = '1') then
      case last_store_cnt_rev(1 downto 0) is
        when "01" => last_store_mask <= "1111";
        when "10" => last_store_mask <= "0001";
        when "11" => last_store_mask <= "0011";
        when "00" => last_store_mask <= "0111";
        when others => null;
      end case;
    else
      case last_store_cnt(1 downto 0) is
        when "00" => last_store_mask <= "1111";
        when "01" => last_store_mask <= "1000";
        when "10" => last_store_mask <= "1100";
        when "11" => last_store_mask <= "1110";
        when others => null;
      end case;
    end if;
  end process;

  first_mask <= first_store_mask when (first_store = '1') else "1111";
  last_mask  <= last_store_mask  when (last_store = '1')  else "1111";

  --
  -- dma data path
  --

  p_data_reg : process
  begin
    wait until rising_edge(i_clk);
    if (i_ena = '1') then
      if (i_dma_ack = '1') then
        if    (dma_we = '0') and (first_load = '1') then
          data_reg(63 downto  0) <= i_dma_data & i_dma_data;

        elsif (dma_we = '0') and (reverse = '0') then
          data_reg(63 downto  0) <= data_reg(31 downto 0) & i_dma_data;

        elsif (dma_we = '1') and (reverse = '0') and (last_load_t = '1') then
          data_reg(63 downto 32) <= data_reg(31 downto 0);

        elsif (dma_we = '0') and (reverse = '1') then
          data_reg(63 downto  0) <= i_dma_data & data_reg(63 downto 32);

        elsif (dma_we = '1') and (reverse = '1') and (last_load_t = '1') then
          data_reg(31 downto  0) <= data_reg(63 downto 32);

        end if;
      end if;
    end if;
  end process;

  p_dma_data : process(data_reg, reverse, shift)
  begin
    -- 8 bit shifts
    dma_data <= data_reg(31 downto 0); -- default
    if (reverse = '1') then
      case shift is
        when "00" => dma_data <= data_reg(63 downto 32);
        when "01" => dma_data <= data_reg(55 downto 24);
        when "10" => dma_data <= data_reg(47 downto 16);
        when "11" => dma_data <= data_reg(39 downto  8);
        when others => null;
      end case;
    else
      case shift is
        when "00" => dma_data <= data_reg(31 downto  0);
        when "01" => dma_data <= data_reg(39 downto  8);
        when "10" => dma_data <= data_reg(47 downto 16);
        when "11" => dma_data <= data_reg(55 downto 24);
        when others => null;
      end case;
    end if;
  end process;

  p_dma_output : process(dma_data, dma_we, first_mask, last_mask)
    variable mask : word(3 downto 0);
  begin
    mask := first_mask and last_mask;

    o_dma_data <= dma_data;
    o_dma_bs_l <= "0000"; -- read

    if (dma_we = '1') then
      o_dma_bs_l(3) <= not mask(0);
      o_dma_bs_l(2) <= not mask(1);
      o_dma_bs_l(1) <= not mask(2);
      o_dma_bs_l(0) <= not mask(3);
    end if;
  end process;

  o_dma_req  <= dma_req;
  o_dma_rw_l <= not dma_we;
  o_dma_addr <= "000000" & dma_addr & "00";

  o_irq <= '0'; -- not used


end RTL;