----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:42:49 PM
-- Design Name: 
-- Module Name: controller_fsm - FSM
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
use IEEE.STD_LOGIC_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
 
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
 
entity controller_fsm is
    Port ( i_reset : in STD_LOGIC;
           i_adv : in STD_LOGIC;
           o_cycle : out STD_LOGIC_VECTOR (3 downto 0));
end controller_fsm;
 
architecture FSM of controller_fsm is
 
    type state is (state1, state2, state3, state4);
    signal next_state, current_state: state;
 
begin
 
    -- Next State Logic            
  	next_state  <= state1 when (current_state = state4) else
	               state'succ(current_state);
	with current_state select
	o_cycle <= "0001" when state1,
	           "0010" when state2,
	           "0100" when state3,
	           "1000" when state4,
	           "0001" when others;
	register_proc : process (i_reset, i_adv)
        begin
            if i_reset = '1' then
                current_state <= state1;
            elsif rising_edge(i_adv) then
                current_state <= next_state;                    
            end if;
        end process register_proc;
 
end FSM;