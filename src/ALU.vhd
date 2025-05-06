----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:50:18 PM
-- Design Name: 
-- Module Name: ALU - Behavioral
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

entity ALU is
    Port ( i_A : in STD_LOGIC_VECTOR (7 downto 0);
           i_B : in STD_LOGIC_VECTOR (7 downto 0);
           i_op : in STD_LOGIC_VECTOR (2 downto 0);
           o_result : out STD_LOGIC_VECTOR (7 downto 0);
           o_flags : out STD_LOGIC_VECTOR (3 downto 0));
end ALU;

architecture Behavioral of ALU is

    component ripple_adder is
        Port ( A : in  std_logic_vector;
               B : in  std_logic_vector;
               Cin : in  STD_LOGIC;
               S : out  std_logic_vector;
               Cout : out  STD_LOGIC);
    end component ripple_adder;

    signal w_sum : STD_LOGIC_VECTOR (7 downto 0);
    signal w_cout : STD_LOGIC;
    signal w_B : STD_LOGIC_VECTOR (7 downto 0);
    signal w_and : STD_LOGIC_VECTOR (7 downto 0);
    signal w_or : STD_LOGIC_VECTOR (7 downto 0);
    signal w_result : STD_LOGIC_VECTOR (7 downto 0);


begin
    with i_op(0) select
        w_B <= i_B when ('0'),
                  (not i_B) when ('1'),
                  i_B when others;
    
    ripple_adder_inst : ripple_adder
        port map (
            A => i_A,
            B => w_B,
            Cin => '0',
            S => w_sum,
            Cout => w_cout
        ); 
    
    w_and <= i_A and i_B;
    w_or <= i_A or i_B;
    
    with i_op select
        w_result <= w_sum when ("000"),
                    w_sum when ("001"),
                    w_and when ("010"),
                    w_or when ("011"),
                    w_sum when others;
                    
    o_result <= w_result;
    
    -- Overflow flag
    o_flags (0) <= (not(i_op(0) xor i_A(7) xor i_B(7))) and (i_A(7) xor w_sum(7)) and (not i_op(1));
    -- Carry-out flag
    o_flags (1) <= (not i_op(1)) and (w_cout);
    -- Negative flag
    o_flags (3) <= w_result(7);
    -- Zero flag
    o_flags (2) <= (not w_result(7)) and (not w_result(7)) and
                   (not w_result(6)) and (not w_result(6)) and
                   (not w_result(5)) and (not w_result(5)) and
                   (not w_result(4)) and (not w_result(4)) and
                   (not w_result(3)) and (not w_result(3)) and
                   (not w_result(2)) and (not w_result(2)) and
                   (not w_result(1)) and (not w_result(1)) and
                   (not w_result(0)) and (not w_result(0));

end Behavioral;
