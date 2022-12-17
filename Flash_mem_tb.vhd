-----------------------------------------------------------------------------------------------------
-- Company			: Space Applications Centre, ISRO
-- Engineer			: Adhiraj Roy Chowdhury
-- Create Date		: 16:35:00 10/05/2022
-- Target Devices	: FPGA:RT4G150_ES, Controller for 3DFS256M04VS2801 NOR Flash memory
------------------------------------------------------------------------------------------------------ 

library ieee ;
use ieee.std_logic_1164.all ;
use ieee.std_logic_unsigned.all ;

Entity Flash_mem_tb is
end entity;

Architecture Flash_mem_tb_arch of Flash_mem_tb is

component Flash_mem_top
	port(
	i_clk      :IN std_logic;  
    i_rst_n    :IN std_logic;	
	o_SCK      :OUT std_logic;
    o_Chip_en  :OUT std_logic;
    io         :INOUT std_logic_vector(3 downto 0);
	i_data     :IN  std_logic_vector(31 downto 0);
	o_MOSI     :OUT std_logic_vector(31 downto 0);
	i_address  :IN  std_logic_vector(23  downto 0);
	i_wren     :IN  std_logic;  
	i_rden     :IN  std_logic  							  
);                                
end component;

component flash_module 
	port(
    USERA_CE_N       :IN    std_logic; 
    USERA_SCK        :IN    std_logic; 
    USERA_IO3        :INOUT std_logic;  
    USERA_IO0        :INOUT std_logic;   
    USERA_IO1        :INOUT std_logic;     
    USERA_IO2        :INOUT std_logic;  
    USERB_CE_N       :IN    std_logic;
    USERB_SCK        :IN    std_logic;
    USERB_IO3        :INOUT std_logic;
    USERB_IO0        :INOUT std_logic;
	USERB_IO1        :INOUT std_logic;
	USERB_IO2        :INOUT std_logic 
	);
end component;
	
signal	i_clk_sig      : std_logic:='0'; 
signal  i_rst_n_sig      : std_logic:='0';
signal	o_SCK_sig     : std_logic;
signal  o_Chip_en_sig      : std_logic;
signal  io_sig            : std_logic_vector(3 downto 0);		
signal	i_data_sig    : std_logic_vector(31 downto 0);
signal	o_MOSI_sig    : std_logic_vector(31 downto 0);
signal	i_address_sig       : std_logic_vector(23  downto 0);
signal  i_wren_sig      : std_logic;  
signal  i_rden_sig       : std_logic; 	
signal qspi_io_in_sig       :std_logic_vector(3 downto 0);
signal qspi_io_out_sig      :std_logic_vector(3 downto 0);
signal qspi_out_en_sig      :std_logic;
signal qspi_init_state_sig  :std_logic; 
signal qspi_dummy_cycle_sig :std_logic; 

begin

Flash_mem_top_tb: Flash_mem_top
	port map(
	i_clk      => i_clk_sig,
    i_rst_n    => i_rst_n_sig,
	o_SCK      => o_SCK_sig,
    o_Chip_en  => o_Chip_en_sig,
    io         => io_sig,
	i_data     => i_data_sig,
	o_MOSI     => o_MOSI_sig,
	i_address  => i_address_sig,
	i_wren     => i_wren_sig,  
	i_rden     => i_rden_sig    
);

flash_module_tb: flash_module 
	port map(
    USERA_CE_N       => o_Chip_en_sig,
    USERA_SCK        => o_SCK_sig,
    USERA_IO3        => io_sig(3), 
    USERA_IO0        => io_sig(0),  
    USERA_IO1        => io_sig(1),     
    USERA_IO2        => io_sig(2),
	USERB_CE_N       => o_Chip_en_sig,
	USERB_SCK        => o_SCK_sig,
	USERB_IO3        => io_sig(3), 
	USERB_IO0        => io_sig(0),  
	USERB_IO1        => io_sig(1),    
	USERB_IO2        => io_sig(2)	
	);

i_clk_sig <= not i_clk_sig after 5 ns; --100MHZ
i_rst_n_sig <= '0', '1' after 1 us;

i_data_sig <= X"00000000", X"00000070" after 50 us,
					X"00000001" after 52 us,X"00000000"  after 53.1 us,
					X"00000006" after 80 us,X"00000001"  after 82 us,X"00000000"  after 83 us,
					X"12345678"  after 100 us,X"00800006"  after 102 us,X"00000002"  after 103 us,
					X"00000001"  after 110 us,X"00000000" after 120 us,X"0000000B" after 1500 us,
					X"00000006" after 1550 us,X"00000001"  after 1560 us,X"00000000"  after 1561 us,
					X"000000B1" after 1600 us,X"0000BFF7" after 1610 us,
					X"00000001"  after 1620 us,X"00000000"  after 1620.2 us,
					X"00000006" after 1950 us,X"00000001"  after 1960 us,X"00000000"  after 1961 us,
					X"00000081"  after 2000 us,X"000000BC" after 2010 us,
					X"00000001"  after 2020 us,X"00000000"  after 2020.2 us,
					X"00000006" after 2050 us,X"00000001"  after 2060 us,X"00000000"  after 2061 us,
					X"000000D8"  after 2100 us,X"00800006" after 2110 us,
					X"00000001"  after 2120 us,X"00000000"  after 2120.2 us;



i_address_sig <= X"000000", X"00000C" after 50 us,
					 X"000010" after 52 us, X"00000C" after 80 us,X"000010" after 82 us,X"000010" after 83 us,
					 X"000000" after 100 us,X"000008" after 102 us,X"00000C" after 103 us,X"000010" after 110 us,
					 X"00000C" after 1500 us,X"00000C" after 1550 us,X"000010" after 1560 us,X"00000C" after 1600 us,
					 X"000000" after 1610 us,X"000010" after 1620 us,
					 X"00000C" after 1950 us,X"000010" after 1960 us,
					 X"00000C" after 2000 us,X"000000" after 2010 us,
					 X"000010" after 2020 us,
					 X"00000C" after 2050 us,X"000010" after 2060 us,
					 X"00000C" after 2100 us,X"000008" after 2110 us,
					 X"000010" after 2120 us;


i_wren_sig <= '0', '1' after 51 us, '0' after 52 us,
					  '1' after 53 us, '0' after 53.1 us, '1' after 53.2 us, '0' after 54 us,
					  '1' after 81 us, '0' after 81.1 us,'1' after 82.1 us, '0' after 82.2 us,
					  '1' after 83 us, '0' after 83.1 us,
					  '1' after 100 us, '0' after 100.1 us,
					  '1' after 102 us, '0' after 102.1 us, 
					  '1' after 103 us, '0' after 103.1 us, 
					  '1' after 110 us, '0' after 110.1 us, 
					  '1' after 120 us, '0' after 120.1 us, 
					  '1' after 1500 us, '0' after 1500.1 us,
					  '1' after 1550 us, '0' after 1550.1 us,
					  '1' after 1560 us, '0' after 1560.1 us,
					  '1' after 1561 us, '0' after 1561.1 us,
					  '1' after 1600 us, '0' after 1600.1 us,
					  '1' after 1610 us, '0' after 1610.1 us,
					  '1' after 1620 us, '0' after 1620.1 us,
					  '1' after 1620.2 us, '0' after 1620.3 us,
					  '1' after 1950 us, '0' after 1950.1 us,
					  '1' after 1960 us, '0' after 1960.1 us,
					  '1' after 1961 us, '0' after 1961.1 us,
					  '1' after 2000 us, '0' after 2000.1 us,
					  '1' after 2010 us, '0' after 2010.1 us,
					  '1' after 2020 us, '0' after 2020.1 us,
					  '1' after 2020.2 us, '0' after 2020.3 us,
					  '1' after 2050 us, '0' after 2050.1 us,
					  '1' after 2060 us, '0' after 2060.1 us,
					  '1' after 2061 us, '0' after 2061.1 us,
					  '1' after 2100 us, '0' after 2100.1 us,
					  '1' after 2110 us, '0' after 2110.1 us,
					  '1' after 2120 us, '0' after 2120.1 us,
					  '1' after 2120.2 us, '0' after 2120.3 us;
					  
i_rden_sig <= '0', '1' after 60 us, '0' after 61 us; 


end Flash_mem_tb_arch;