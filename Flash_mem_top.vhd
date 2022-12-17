-----------------------------------------------------------------------------------------------------
-- Company			: Space Applications Centre, ISRO
-- Engineer			: Adhiraj Roy Chowdhury
-- Create Date		: 16:35:00 10/05/2022
-- Target Devices	: FPGA:RT4G150_ES, Controller for 3DFS256M04VS2801 NOR Flash memory
------------------------------------------------------------------------------------------------------ 

library ieee ;
use ieee.std_logic_1164.all ;
use ieee.std_logic_unsigned.all;

Entity Flash_mem_top is                                            -- this is our top module
	port(
	
	--clock and reset from the user/testbench
	i_clk           :IN std_logic;                                 --100MHZ
    i_rst_n         :IN std_logic;
	
	--flash mem pins
	o_SCK          :OUT std_logic;
    o_Chip_en      :OUT std_logic;
    io             :INOUT std_logic_vector(3 downto 0);
	
	--User/TB register file pins
	i_data         :IN  std_logic_vector(31 downto 0);
	o_MOSI         :OUT std_logic_vector(31 downto 0);
	i_address      :IN  std_logic_vector(23  downto 0);
	i_wren         :IN  std_logic;  
	i_rden         :IN  std_logic  
);
end entity;

Architecture Flash_mem_top_arch of Flash_mem_top is

--components
component Qspi_controller
	port(
		clock	         :in  std_logic;                         --100MHZ
		reset            :in  std_logic;
		qspi_io_in       :in   std_logic_vector(3 downto 0);
		qspi_io_out      :out  std_logic_vector(3 downto 0);
		qspi_out_en      :out  std_logic;
		qspi_clk_out     :out  std_logic;                        --25MHZ
		qspi_cs          :out  std_logic;
		qspi_init_state  :out  std_logic;                        -- 1: init mode, 0: quad mode
		qspi_dummy_cycle :out std_logic;                         -- 1: dummy cycles, 0: no dummy
		data_write       :in  std_logic_vector(31 downto 0);
		data_read        :out std_logic_vector(31 downto 0);
		address_data     :in  std_logic_vector(31 downto 0);
		command_data     :in  std_logic_vector(31 downto 0);
		send_data        :in  std_logic_vector(31 downto 0)									  
	);                                    
end component;

component Registers_file
	port(
		clock	      :in std_logic;
		reset         :in std_logic;
	    i_data        :in  std_logic_vector(31 downto 0);
	    o_MOSI        :out std_logic_vector(31 downto 0);
	    i_address     :in  std_logic_vector(23  downto 0);
	    i_wren        :in  std_logic;
	    i_rden        :in  std_logic;
		data_write    :out std_logic_vector(31 downto 0);
		data_read     :in  std_logic_vector(31 downto 0);
		address_data  :out std_logic_vector(31 downto 0);
		command_data  :out std_logic_vector(31 downto 0);
		send_data     :out std_logic_vector(31 downto 0)
										  
	);                                    
end component;

--- flash signals
signal o_Chip_en_sig  		:std_logic;
signal qspi_io_in_sig       :std_logic_vector(3 downto 0);
signal qspi_io_out_sig      :std_logic_vector(3 downto 0);
signal qspi_out_en_sig      :std_logic;
signal qspi_init_state_sig  :std_logic; -- 1: init mode, 0: quad mode
signal qspi_dummy_cycle_sig :std_logic; -- 1: dummy cycles, 0: no dummy

--register file signals
signal data_write_sig       :std_logic_vector(31 downto 0);
signal data_read_sig        :std_logic_vector(31 downto 0);
signal address_data_sig     :std_logic_vector(31 downto 0);
signal command_data_sig     :std_logic_vector(31 downto 0);
signal send_data_sig        :std_logic_vector(31 downto 0);		

begin

o_Chip_en <= o_Chip_en_sig;
io(3 downto 0) <= qspi_io_out_sig when ((qspi_out_en_sig = '1') and (o_Chip_en_sig = '0') and (qspi_init_state_sig = '0')and (qspi_dummy_cycle_sig = '0')) 
                  else "1ZZ"&qspi_io_out_sig(0) when ((qspi_out_en_sig = '1') and (o_Chip_en_sig = '0') and (qspi_init_state_sig = '1')and (qspi_dummy_cycle_sig = '0'))
				  else "ZZZZ";   
qspi_io_in_sig<= io(3 downto 0) when ((qspi_out_en_sig = '0') and (o_Chip_en_sig = '0')) else "0000";


Qspi_controller_top: Qspi_controller
	port map(
		clock	         => i_clk,
		reset            => i_rst_n,
		qspi_io_in       => qspi_io_in_sig,
		qspi_io_out      => qspi_io_out_sig,
		qspi_out_en      => qspi_out_en_sig,
		qspi_clk_out     => o_SCK,
		qspi_cs          => o_Chip_en_sig,
		qspi_init_state  => qspi_init_state_sig,
		qspi_dummy_cycle => qspi_dummy_cycle_sig,
		data_write       => data_write_sig,
		data_read        => data_read_sig,
		address_data     => address_data_sig,
		command_data     => command_data_sig,
		send_data        => send_data_sig   									  
	);                                    

Registers_file_top: Registers_file
	port map(
		clock => i_clk,
		reset => i_rst_n,
	    i_data => i_data,
	    o_MOSI => o_MOSI,
	    i_address => i_address,   
	    i_wren => i_wren,
	    i_rden => i_rden,
		data_write => data_write_sig,
		data_read => data_read_sig,
		address_data => address_data_sig,
		command_data => command_data_sig,
		send_data => send_data_sig   										  
	);                                    

end Flash_mem_top_arch;