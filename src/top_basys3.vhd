--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
 
 
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(7 downto 0); -- operands and opcode
        btnU    :   in std_logic; -- reset
        btnC    :   in std_logic; -- fsm cycle
        btnL    :   in std_logic; -- clock divider reset
        btnR    :   in std_logic; -- controller asynchronous reset
        btnD    :   in std_logic; -- TDM asynchronous reset
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;
 
architecture top_basys3_arch of top_basys3 is 
	-- declare components and signals
	
component button_debounce is
    Port(	clk: in  STD_LOGIC;
			reset : in  STD_LOGIC;
			button: in STD_LOGIC;
			action: out STD_LOGIC);
end component button_debounce;
	
component controller_fsm is
    Port ( i_reset : in STD_LOGIC;
           i_adv : in STD_LOGIC;
           o_cycle : out STD_LOGIC_VECTOR (3 downto 0));
end component controller_fsm;
 
 
component clock_divider is
	generic ( constant k_DIV : natural := 50000	); -- How many clk cycles until slow clock toggles
											   -- Effectively, you divide the clk double this 
											   -- number (e.g., k_DIV := 2 --> clock divider of 4)
	port ( 	i_clk    : in std_logic;
			i_reset  : in std_logic;		   -- asynchronous
			o_clk    : out std_logic		   -- divided (slow) clock
	);
end component clock_divider;
 
 
component ALU is
    Port ( i_A : in STD_LOGIC_VECTOR (7 downto 0);
           i_B : in STD_LOGIC_VECTOR (7 downto 0);
           i_op : in STD_LOGIC_VECTOR (2 downto 0);
           o_result : out STD_LOGIC_VECTOR (7 downto 0);
           o_flags : out STD_LOGIC_VECTOR (3 downto 0));
end component ALU;
 
 
component twos_comp is
    port (
        i_bin: in std_logic_vector(7 downto 0);
        o_sign: out std_logic;
        o_hund: out std_logic_vector(3 downto 0);
        o_tens: out std_logic_vector(3 downto 0);
        o_ones: out std_logic_vector(3 downto 0)
    );
end component twos_comp;
 
 
component TDM4 is
	generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
    Port ( i_clk		: in  STD_LOGIC;
           i_reset		: in  STD_LOGIC; -- asynchronous
           i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	);
end component TDM4;
 
 
component sevenseg_decoder is
    Port ( i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
           o_seg_n : out STD_LOGIC_VECTOR (6 downto 0));
end component sevenseg_decoder;
 
 
component register_store is 
  port(
	i_operand : in std_logic_vector (7 downto 0);
	i_state : in std_logic;
	o_operand : out std_logic_vector (7 downto 0)	-- output
  );
end component register_store;

signal w_adv : std_logic;
 
signal w_slowclock : std_logic;
signal w_cycle : std_logic_vector(3 downto 0);
signal w_result : std_logic_vector(7 downto 0);
signal w_display : std_logic_vector(7 downto 0);

signal w_sign : std_logic;
signal w_hund : std_logic_vector(3 downto 0);
signal w_tens : std_logic_vector(3 downto 0);
signal w_ones : std_logic_vector(3 downto 0);
signal w_D3 : std_logic_vector(3 downto 0);

signal w_data : std_logic_vector(3 downto 0);
signal w_seg_decoder : std_logic_vector(6 downto 0);
signal w_seg_out : std_logic_vector(6 downto 0);
signal w_sel : std_logic_vector(3 downto 0);
--signal w_an : std_logic_vector(3 downto 0);

signal w_seg : std_logic_vector(6 downto 0);
 
signal op_A : std_logic_vector(7 downto 0);
signal op_A_next : std_logic_vector(7 downto 0);
signal op_B : std_logic_vector(7 downto 0);
signal op_B_next : std_logic_vector(7 downto 0);
 
 
begin
	-- PORT MAPS ----------------------------------------
	controller_inst: controller_fsm
	port map(
	   i_reset => btnU,
	   i_adv => w_adv,
	   o_cycle => w_cycle
	);
	
	debounce_inst: button_debounce
	port map(
	   clk => clk,
	   reset => btnU,
	   button => btnC,
	   action => w_adv
    );
	
	clkdiv_inst : clock_divider
	port map(
	   i_clk => clk,
	   i_reset => btnU,
	   o_clk => w_slowclock
	);

	ALU_inst : ALU
	port map(
	   i_A => op_A,
	   i_B => op_B,
	   i_op => sw(2 downto 0),
	   o_result => w_result,
	   o_flags => led(15 downto 12)
	);
	
	with w_cycle select
        w_display <= op_A when ("0010"),
                    op_B when ("0100"),
                    w_result when ("1000"),
 
                    x"FF" when others;
	
	twos_comp_inst : twos_comp
	port map(
	   i_bin => w_display,
	   o_sign => w_sign,
	   o_hund => w_hund,
	   o_tens => w_tens,
	   o_ones => w_ones
	);
	
	with w_sign select
	   w_D3 <= x"E" when '1',
	           x"F" when others;
	
	TDM4_inst : TDM4
	port map(
	   i_clk => w_slowclock,
	   i_reset => btnU,
	   i_D3 => w_D3,
	   i_D2 => w_hund,
	   i_D1 => w_tens,
	   i_D0 => w_ones,
	   o_data => w_data,
	   o_sel => w_sel
	);
	seveseg_decoder_inst : sevenseg_decoder
	port map(
	   i_Hex => w_data,
	   o_seg_n => w_seg_decoder
	);
	
	w_seg <= "0111111" when ((w_seg_decoder = "0000110") ) else
	         "1111111" when ((w_seg_decoder = "0001110") ) else
	         w_seg_decoder;
	
	-- CONCURRENT STATEMENTS ----------------------------
	op_A_next <= sw(7 downto 0);
	op_B_next <= sw(7 downto 0);

    seg(6 downto 0) <= w_seg;
    an(3 downto 0) <= x"F" when (w_cycle = "0001") else
                       w_sel;
    led(3 downto 0) <= w_cycle;
    led(11 downto 4) <= "00000000";

    register_proc1 : process (w_cycle)
        begin
            if rising_edge(w_cycle(1)) then
                op_A <= op_A_next;                 
            end if;
        end process register_proc1;
        
    register_proc2 : process (w_cycle)
        begin
            if rising_edge(w_cycle(2)) then
                op_B <= op_B_next;                 
            end if;
        end process register_proc2;
end top_basys3_arch;