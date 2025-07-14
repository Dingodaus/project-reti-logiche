----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.07.2025 21:58:14
-- Design Name: 
-- Module Name: 10855364_10842752 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);

        o_done : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in  std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_type is (START, READ, FILTER, WRITE, DONE);
    signal state, next_state : state_type := START;

    signal N, K : integer := 0;
    signal count, index : integer := 0;
    type array_type is array(0 to 1023) of std_logic_vector(7 downto 0);
    type array_type_out is array(0 to 1023) of std_logic_vector(7 downto 0);
    signal input_array : array_type; 
    signal result_array : array_type_out;
    signal somma : integer := 0;
    signal init : std_logic := '1';

begin

process(i_clk, i_rst)
    begin
    if i_rst = '1' then
        state <= START;
    elsif rising_edge(i_clk) then
        state <= next_state;
    end if;
    end process;

    process(state, i_start, count, index)
    begin
        next_state <= state;  

        if state = START then
            if i_start = '1' then
                next_state <= READ;
            end if;

        elsif state = READ then
            if count = 17 + K then
                next_state <= FILTER;
            end if;

        elsif state = FILTER then
            if index = K then
                next_state <= WRITE;
            end if;

        elsif state = WRITE then
            if count = 17 + 2*K then
                next_state <= DONE;
            end if;

        elsif state = DONE then
            if i_start = '0' then
                next_state <= START;
            end if;

        else
            next_state <= START;
        end if;
    end process;

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_mem_en <= '1';
            o_mem_we <= '0';
            o_mem_addr <= i_add;
            init <= '0';
            o_done <= '0';

            if state = START then
                    o_done <= '0';
                    count <= 0;

             elsif state = READ then
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + to_unsigned(count, 16));
                    input_array(count) <= i_mem_data;
                    if count = 1 then
                        K <= 256 * to_integer(unsigned(input_array(0))) + to_integer(unsigned(input_array(1)));
                    end if;
                    count <= count + 1;

              elsif state = WRITE then
                    o_mem_we <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + to_unsigned(count, 16));
                    o_mem_data <= result_array(count - (17+K));
                    count <= count + 1;
                    
                
            elsif state = DONE then
                     o_done <= '1';
                     o_mem_we <= '0';
                     o_mem_en <= '0';
  
            end if;
        end if;
    end process;

   
process(state, input_array, K, index, somma)
    begin
            if state = FILTER then
                index <= 0;
                somma <= 0;

                if input_array(2)(0) = '0' then
                    for i in -2 to 2 loop
                        if (index + i >= 0) and (index + i < K) then
                            somma <= somma + to_integer(signed(input_array(6 + i))) * to_integer(signed(input_array(17 + index + i)));
                        end if;
                    end loop;
                    if to_signed(somma, 16)(15) = '1' then
                        somma <= (to_integer(shift_right(to_signed(somma,16),4)) +
                                  to_integer(shift_right(to_signed(somma,16),6)) +
                                  to_integer(shift_right(to_signed(somma,16),8)) +
                                  to_integer(shift_right(to_signed(somma,16),10))) + 4;
                    else
                        somma <= (to_integer(shift_right(to_signed(somma,16),4)) +
                                  to_integer(shift_right(to_signed(somma,16),6)) +
                                  to_integer(shift_right(to_signed(somma,16),8)) +
                                  to_integer(shift_right(to_signed(somma,16),10)));
                    end if;

                else  
                    for i in -3 to 3 loop
                        if (index + i >= 0) and (index + i < K) then
                            somma <= somma + to_integer(signed(input_array(13 + i))) * to_integer(signed(input_array(17 + index + i)));
                        end if;
                    end loop;
                    if to_signed(somma, 16)(15) = '1' then
                        somma <= (to_integer(shift_right(to_signed(somma,16),6)) +
                                  to_integer(shift_right(to_signed(somma,16),10))) + 2;
                    else
                        somma <= (to_integer(shift_right(to_signed(somma,16),6)) +
                                  to_integer(shift_right(to_signed(somma,16),10)));
                    end if;
                end if;

                if somma > 127 then
                    result_array(index) <= std_logic_vector(to_signed(127, 8));
                elsif somma < -128 then
                    result_array(index) <= std_logic_vector(to_signed(-128, 8));
                else
                    result_array(index) <= std_logic_vector(to_signed(somma, 8));
                end if;

                index <= index + 1;
            end if;
    end process;

end Behavioral;
