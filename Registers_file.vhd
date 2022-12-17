-----------------------------------------------------------------------------------------------------
-- Company			: Space Applications Centre, ISRO
-- Engineer			: Adhiraj Roy Chowdhury
-- Create Date		: 16:35:00 10/05/2022
-- Target Devices	: FPGA:RT4G150_ES, Controller for 3DFS256M04VS2801 NOR Flash memory
------------------------------------------------------------------------------------------------------ 

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity Registers_file is
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
end Registers_file;

architecture registers_file_arch of registers_file is

signal data_write_sig      :std_logic_vector(31 downto 0);
signal data_read_sig       :std_logic_vector(31 downto 0);
signal address_data_sig    :std_logic_vector(31 downto 0);
signal command_data_sig    :std_logic_vector(31 downto 0);
signal send_data_sig       :std_logic_vector(31 downto 0);

begin

data_write <= data_write_sig;  
data_read_sig <= data_read;  
address_data <= address_data_sig;
command_data <= command_data_sig;
send_data <= send_data_sig;   

process(reset,clock,i_rden,data_write_sig,data_read_sig,address_data_sig,command_data_sig,send_data_sig) --read registers
begin
    if(reset = '0') then
	    o_MOSI <= (others=>'0');
	elsif(rising_edge(clock)) then
	    if(i_rden = '1') then
		    case i_address is
				when x"000000" => o_MOSI <= data_write_sig  ;
				when x"000004" => o_MOSI <= data_read_sig   ;
				when x"000008" => o_MOSI <= address_data_sig;
				when x"00000C" => o_MOSI <= command_data_sig;
				when x"000010" => o_MOSI <= send_data_sig   ;
				
				when others=> o_MOSI <= x"12345678";
			end case;
		end if;
	end if;
end process;

process(reset,clock,i_wren) --write registers
begin
    if(reset = '0') then
	    data_write_sig   <= (others=>'0');  
	    address_data_sig <= (others=>'0');
	    command_data_sig <= (others=>'0');
	    send_data_sig    <= (others=>'0');
	
	
	elsif(rising_edge(clock)) then
	    if(i_wren = '1') then
		    case i_address is
				when x"000000" => data_write_sig   <= i_data;
				when x"000008" => address_data_sig <= i_data;
				when x"00000C" => command_data_sig <= i_data;
				when x"000010" => send_data_sig    <= i_data;
				
				when others=> null;
			end case;
		end if;
	end if;
end process;

end registers_file_arch;