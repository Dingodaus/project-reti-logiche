----------------------------------------------------------------------------------
-- Company: Politecnico di Milano
-- Engineer: Student
-- 
-- Create Date: 12.07.2025 21:58:14
-- Design Name: 
-- Module Name: 10855364_10842752 - Behavioral
-- Project Name: Progetto Reti Logiche 2024/2025
-- Target Devices: FPGA
-- Tool Versions: Vivado 202x
-- Description: Filtro differenziale con buffer circolare e pipeline a 2 stadi
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 1.0 - Timing Optimization (Pipelining)
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

architecture Behavioural of project_reti_logiche is

    type state_type is (
        START,
        SETUP_ADDR, SETUP_READ,             
        READ_ADDR, READ_WAIT, READ_VALUES,    
        FILTER_CALC,                        
        FILTER_NORM,                        
        WRITE,                              
        DONE
    );
    
    signal state, next_state : state_type := START;
    signal current_offset : integer range 0 to 65535 := 0;
    type setup_array_type is array(0 to 16) of std_logic_vector(7 downto 0);
    type filter_array_type is array(0 to 6) of std_logic_vector(7 downto 0);
    signal setup_array  : setup_array_type;
    signal filter_array : filter_array_type;
    signal somma        : integer := 0; 
    signal filter_shift : integer := 0; 
    signal K            : integer := 0; 

begin
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            state <= START;
        elsif rising_edge(i_clk) then
            state <= next_state;
        end if;
    end process;

    process(i_clk)
    begin
        next_state <= state;
        case state is
           
            when START =>
                if i_start = '1' then
                    next_state <= SETUP_READ;
                end if;

            when SETUP_READ =>
                if current_offset = 17 then            
                    next_state <= READ_ADDR;      
                else
                    next_state <= SETUP_ADDR;      
                end if;

            when SETUP_ADDR =>
                next_state <= SETUP_READ;

            when READ_ADDR =>
                next_state <= READ_WAIT; 
            
            when READ_WAIT =>
                next_state <= READ_VALUES; 

            when READ_VALUES =>
                if setup_array(2)(0) = '0' then 
                    if filter_shift = -2 then
                        next_state <= FILTER_CALC;
                    else
                        next_state <= READ_ADDR;
                    end if;
                else                         
                    if filter_shift = -3 then
                        next_state <= FILTER_CALC;
                    else
                        next_state <= READ_ADDR;
                    end if;
                end if;

            when FILTER_CALC =>
                next_state <= FILTER_NORM;

            when FILTER_NORM =>
                next_state <= WRITE;

            when WRITE =>
                if current_offset = 17 + K - 1 then
                    next_state <= DONE;
                else
                    next_state <= READ_ADDR;
                end if;

            when DONE =>
                if i_start = '0' then
                    next_state <= START;
                end if;

            when others =>
                next_state <= START;

        end case;
    end process;

    process(i_clk)
        variable sum_v  : integer;
        variable norm_v : integer;
    begin
        if rising_edge(i_clk) then

            o_done <= '0';
            o_mem_en <= '0';
            o_mem_we <= '0';

            case state is

                when START =>
                    setup_array     <= (others => (others => '0'));
                    filter_array    <= (others => (others => '0'));
                    o_mem_addr      <= (others => '0');
                    somma           <= 0;
                    K               <= 0;
                    filter_shift    <= 0;
                    current_offset  <= 0;   

                when SETUP_READ =>
                    o_mem_en <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + to_unsigned(current_offset, 16));

                     if (current_offset > 0) and (current_offset-1 <= 16) then
                       setup_array(current_offset-1) <= i_mem_data;
                     end if;
                    
                    if current_offset = 17 then
                    K <= 256 * to_integer(unsigned(setup_array(0)))+to_integer(unsigned(setup_array(1)));
                        if setup_array(2)(0) = '0' then
                            filter_shift <= 2;  
                        else
                            filter_shift <= 3;  
                        end if;
                    end if;

                when SETUP_ADDR =>
                    o_mem_en <= '1';
                    if current_offset < 17 then
                        current_offset <= current_offset + 1;
                    end if;

                when READ_ADDR =>
                    o_mem_en <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(i_add) + to_unsigned(current_offset + filter_shift, 16));

                when READ_WAIT =>
                    o_mem_en <= '1'; 
                    
                when READ_VALUES =>
                    o_mem_en <= '1';
                
                    filter_array(3 + filter_shift) <= i_mem_data;

                    if (current_offset + filter_shift < 17) or 
                       (current_offset + filter_shift > 17 + K - 1) then
                        filter_array(3 + filter_shift) <= (others => '0');
                    end if;
         
                    if setup_array(2)(0) = '0' then        
                        if filter_shift > -2 then
                            filter_shift <= filter_shift - 1;
                        end if;
                    else                                   
                        if filter_shift > -3 then
                            filter_shift <= filter_shift - 1;
                        end if;
                    end if;

                when FILTER_CALC =>
                    sum_v := 0;

                    if setup_array(2)(0) = '0' then
                      
                        for i in -2 to 2 loop
                            sum_v := sum_v
                                   + to_integer(signed(setup_array(6 + i))) 
                                   * to_integer(signed(filter_array(3 + i)));
                        end loop;
                    else
             
                        for i in -3 to 3 loop
                            sum_v := sum_v
                                   + to_integer(signed(setup_array(13 + i)))
                                   * to_integer(signed(filter_array(3 + i)));
                        end loop;
                    end if;
                    somma <= sum_v;

                when FILTER_NORM =>
                norm_v := 0;
                if setup_array(2)(0) = '0' then
                    if somma < 0 then
                        norm_v :=  (to_integer(shift_right(to_signed(somma, 24), 4)))
                                 + (to_integer(shift_right(to_signed(somma, 24), 6)))
                                 + (to_integer(shift_right(to_signed(somma, 24), 8)))
                                 + (to_integer(shift_right(to_signed(somma, 24), 10)))+4;
                    else
                        norm_v :=  to_integer(shift_right(to_signed(somma, 24), 4))
                                 + to_integer(shift_right(to_signed(somma, 24), 6))
                                 + to_integer(shift_right(to_signed(somma, 24), 8))
                                 + to_integer(shift_right(to_signed(somma, 24), 10));
                    end if;
                else
                    if somma < 0 then
                        norm_v :=  (to_integer(shift_right(to_signed(somma, 24), 6)))
                                 + (to_integer(shift_right(to_signed(somma, 24), 10)))+2;
                    else
                        norm_v :=  to_integer(shift_right(to_signed(somma, 24), 6))
                                 + to_integer(shift_right(to_signed(somma, 24), 10));
                    end if;
                end if;
                somma <= norm_v;

                when WRITE =>
                    o_mem_en <= '1';
                    o_mem_we <= '1';

                    o_mem_addr <= std_logic_vector(
                                      unsigned(i_add) 
                                    + to_unsigned(K + current_offset,16));

                    if somma > 127 then
                        o_mem_data <= std_logic_vector(to_signed(127, 8));
                    elsif somma < -128 then
                        o_mem_data <= std_logic_vector(to_signed(-128, 8));
                    else
                        o_mem_data <= std_logic_vector(to_signed(somma, 8));
                    end if;

                    if current_offset < 17 + K - 1 then
                        current_offset <= current_offset + 1;

                        if setup_array(2)(0) = '0' then
                            filter_shift <= 2;
                        else
                            filter_shift <= 3;
                        end if;
                    end if;

                when DONE =>
                    o_done <= '1';

            end case;
        end if;
    end process;
end Behavioural;