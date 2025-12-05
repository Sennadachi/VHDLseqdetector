----------------------------------------------------------------------------------
-- Company: Hockley Instruments
-- Engineer: William Hockley
-- 
-- Create Date: 29.11.2025 18:19:11
-- Design Name: VHDL sequence detector
-- Module Name: assignment - Behavioral
-- Project Name: VHDL sequence detector
-- Target Devices: Xilinx Artix-7 - Nexys Video
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity assignment is
    Port( 
        clk: in std_logic;
        btnc: in std_logic; --centre button, Reset
        btnl: in std_logic; --left button, 1
        btnu: in std_logic; --up button, 2
        btnr: in std_logic; --right button, 3
        btnd: in std_logic; -- down button, 4
        led: out std_logic_vector(7 downto 0) --LEDs
        
    );
end assignment;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity debounceMajority is
    port(
        clkSample  : in  std_logic;  -- slow clock
        noisyIn    : in  std_logic;  -- raw button input
        cleanOut   : out std_logic   -- debounced stable output
    );
end debounceMajority;


architecture Behavioral of debounceMajority is
    signal shiftReg : std_logic_vector(7 downto 0) := (others => '0');
begin

    -- shift register is sampled on slow clock
    process(clkSample)
        variable shiftReg_v : std_logic_vector(7 downto 0);
        variable ones       : integer range 0 to 8;
    begin
        if rising_edge(clkSample) then

            -- shift left and insert newest sample
            shiftReg_v := shiftReg(6 downto 0) & noisyIn;
            shiftReg   <= shiftReg_v;

            -- count how many bits are '1'
            ones := 0;
            for i in shiftReg_v'range loop
                if shiftReg_v(i) = '1' then
                    ones := ones + 1;
                end if;
            end loop;

            -- majority vote (4 out of 8)
            if ones >= 4 then
                cleanOut <= '1';
            else
                cleanOut <= '0';
            end if;
        end if;
    end process;

end Behavioral;

architecture Behavioral of assignment is
    signal symbol: integer range 0 to 4 := 0;
    type state_t is (S0, S1, S2, S3, S4, S5); --ty  pe describing states
    signal state: state_t; --Current FSM state, must store one of the values from state_t
    signal nextState: state_t; --Next FSM state,  must store one of the values from state_t
    signal count: integer range 0 to 10 := 0; --count for checking inputs
    signal nextCount: integer range 0 to 10 := 0;
    signal divCounter: integer range 0 to 500 := 0; --counter for LED flash
    signal ledState: std_logic := '0'; --Bit to flip when counter reaches 50,000,000 for LED flash
    signal lock: std_logic := '0';
    signal symbolValid: std_logic := '0';
    signal slowClk: std_logic := '0';
    signal clockCount: integer range 0 to 500000 := 0;

    --signals for debounce
    --signal btnLcount, btnUcount, btnRcount, btnDcount: integer range 0 to 50000;
--    signal btnLsync, btnUsync, btnRsync, btnDsync: std_logic_vector(1 downto 0);
    signal btnlPrev, btnuPrev, btnrPrev, btndPrev: std_logic := '0';
    signal btnlPress, btnuPress, btnrPress, btndPress: std_logic := '0';
    signal btnlClean, btnuClean, btnrClean, btndClean: std_logic := '0';
    
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if clockCount = 50000 then
                slowClk <= not slowClk;
                clockCount <= 0;
            else
                clockCount <= clockCount + 1;
            end if;
        end if;        
            
    end process;
    
    --debounce
        u_debounce_l: entity work.debounceMajority
        port map(
            clkSample => slowClk,
            noisyIn   => btnl,
            cleanOut  => btnlClean
        );
    
    u_debounce_u: entity work.debounceMajority
        port map(
            clkSample => slowClk,
            noisyIn   => btnu,
            cleanOut  => btnuClean
        );
    
    u_debounce_r: entity work.debounceMajority
        port map(
            clkSample => slowClk,
            noisyIn   => btnr,
            cleanOut  => btnrClean
        );
    
    u_debounce_d: entity work.debounceMajority
        port map(
            clkSample => slowClk,
            noisyIn   => btnd,
            cleanOut  => btndClean
        );
    
    process(slowClk)
    begin
        if rising_edge(slowClk) then
            -- Detect rising edges: 0 -> 1
            if (btnlClean = '1') and (btnlPrev = '0') then
                btnlPress <= '1';
            else
                btnlPress <= '0';
            end if;
    
            if (btnuClean = '1') and (btnuPrev = '0') then
                btnuPress <= '1';
            else
                btnuPress <= '0';
            end if;
    
            if (btnrClean = '1') and (btnrPrev = '0') then
                btnrPress <= '1';
            else
                btnrPress <= '0';
            end if;
    
            if (btndClean = '1') and (btndPrev = '0') then
                btndPress <= '1';
            else
                btndPress <= '0';
            end if;
    
            -- Store previous button states
            btnlPrev <= btnlClean;
            btnuPrev <= btnuClean;
            btnrPrev <= btnrClean;
            btndPrev <= btndClean;
        end if;
    end process;
    
    process(btnlPress, btnuPress, btnrPress, btndPress)
    begin 
        if btnlPress = '1' then
            symbol <= 1;
        elsif btnuPress = '1' then
            symbol <= 2;
        elsif btnrPress = '1' then 
            symbol <= 3;
        elsif btndPress = '1' then
            symbol <= 4;
        end if;
        
        symbolValid <= btnlPress or btnuPress or btnrPress or btndPress;
    end process;

   
   --FSM state register
    process(slowClk)
    begin
        if rising_edge(slowClk) then
           
            if symbolValid = '1' then --only advance when there is a new symbol
                state <= nextState;
                count <= nextCount;
            elsif btnc = '1' then
                state <= S0;
                count <= 0;    
            end if;
            
        end if;
    end process;
    
    --FSM next state logic
    process(state, symbol, count, symbolValid)
    begin
        --hold current values by default
        nextState <= state; 
        nextCount <= count;
        
        if symbolValid = '1' then
            if count < 10 then
                nextCount <= count + 1;
            else
                nextCount <= count;
            end if;        
        end if;    
        
        case state is
            when S0 =>
                if symbol = 4 then
                    nextState <= S1;
                else
                    nextState <= S0;
                end if;
            
            when S1 =>
                if symbol = 2 then
                    nextState <= S2;
                elsif symbol = 4 then
                    nextState <= S1;
                else
                    nextState <= S0;    
                end if;
             
             when S2 =>
                if symbol = 2 then
                    nextState <= S3;
                else
                    nextState <= S0; 
                end if;
                
            when S3 =>
                if symbol = 3 then
                    nextState <= S4;
                else
                    nextState <= S0;
                end if;
                
            when S4 =>
                if symbol = 1 then
                    nextState <= S5;
                else
                    nextState <= S0;
                end if;
            
            when S5 =>
                nextState <= S5;                   
        end case;                                                  
    end process;
    
    process(count)
    begin
        if count >= 10 then
            lock <= '1';
        else
            lock <= '0';
        end if;
    end process;   
    
    --LED logic
    process(slowClk)
    begin
        if rising_edge(slowClk) then
            if divCounter = 500 then
                divCounter <= 0; --Reset counter so it counts to 500 again
                ledState <= not ledState; --toggle LED state
            else
                divCounter <= divCounter + 1;
            end if;
            if lock = '1' then
                led <= "10101010";
            else
                case state is
                    when S0 =>
                        led <= "10000000";
                    when S1 =>
                        led <= "00000001";
                    when S2 =>
                        led <= "00000010";
                    when S3 =>
                        led <= "00000100";
                    when S4 =>
                        led <= "00001000";
                    when S5 =>
                        led <= (others => ledState); --sets all LEDs to value of ledState;
                end case;
            end if;
        end if;
    end process;
       
end Behavioral;
