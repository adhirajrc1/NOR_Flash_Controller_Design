-----------------------------------------------------------------------------------------------------
-- Company			: Space Applications Centre, ISRO
-- Engineer			: Adhiraj Roy Chowdhury
-- Create Date		: 16:35:00 10/05/2022
-- Target Devices	: FPGA:RT4G150_ES, Controller for 3DFS256M04VS2801 NOR Flash memory

-- Controller 
------------------------------------------------------------------------------------------------------ 

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity Qspi_controller is
	port(
		clock	         :in  std_logic;                        --100MHZ
		reset            :in  std_logic;
		qspi_io_in       :in   std_logic_vector(3 downto 0);
		qspi_io_out      :out  std_logic_vector(3 downto 0);
		qspi_out_en      :out  std_logic;
		qspi_clk_out     :out  std_logic;                       --25MHZ
		qspi_cs          :out  std_logic;
		qspi_init_state  :out  std_logic;                       -- 1: init mode, 0: quad mode
		qspi_dummy_cycle :out std_logic;                        -- 1: dummy cycles, 0: no dummy	
		data_write       :in  std_logic_vector(31 downto 0);
		data_read        :out std_logic_vector(31 downto 0);
		address_data   :in  std_logic_vector(31 downto 0);
		command_data     :in  std_logic_vector(31 downto 0);
		send_data        :in  std_logic_vector(31 downto 0)										  
	);                                    
end Qspi_controller;

architecture arch of Qspi_controller is

-----Signals-----
signal qspi_clock                 :std_logic;
signal qspi_clock_cnt             :std_logic_vector(1 downto 0);
signal clock_en                   :std_logic;
signal clock_en_cnt               :std_logic_vector(1 downto 0);
signal clock_en_rising_edge       :std_logic;
signal clock_en_cnt_rising_edge   :std_logic_vector(1 downto 0);

-- read signals
signal qspi_io_in_sig  :std_logic_vector(31 downto 0);
signal data_in_counter :std_logic_vector(3 downto 0);
signal data_read_sig   :std_logic_vector(31 downto 0);

-- command
signal initiate_cmd         :std_logic;
signal start_cmd_out        :std_logic;
signal send_quad_cmd_done   :std_logic;
signal command_data_sig     :std_logic_vector(7 downto 0);
signal command_counter      :std_logic_vector(1 downto 0); 
signal qspi_dq_cmd_out      :std_logic_vector(3 downto 0);

-- address
signal initiate_add         :std_logic;
signal start_add_out        :std_logic;
signal send_quad_add_done   :std_logic;
signal address_data_sig   :std_logic_vector(23 downto 0);
signal address_counter      :std_logic_vector(2 downto 0); 
signal qspi_dq_add_out      :std_logic_vector(3 downto 0);

-- data
signal initiate_data        :std_logic;
signal start_data_out       :std_logic;
signal send_quad_data_done  :std_logic;
signal output_data_sig      :std_logic_vector(31 downto 0);
signal data_out_counter     :std_logic_vector(3 downto 0); 
signal qspi_dq_data_out     :std_logic_vector(3 downto 0);
signal initiate_nonvol        :std_logic;
signal start_nonvol_out       :std_logic;
signal send_quad_nonvol_done  :std_logic;
signal output_nonvol_sig      :std_logic_vector(15 downto 0);
signal nonvol_out_counter     :std_logic_vector(2 downto 0); 
signal qspi_dq_nonvol_out     :std_logic_vector(3 downto 0);

type main_state_m is (initial,read_command_data_register1,read_status_register,fast_read,write_enable,
                      read_command_data_register2,write_data_to_the_qspi,write_16bits_command,write_8bits_command,
					  sector_erase);
signal main_sm:main_state_m;

signal done_read :std_logic;
signal done_write :std_logic;

type initialization_state_m is (initial,send_command_we,wait_before_next_cmd,send_cmd_nonvol,send_single_data,done);
signal initialization_sm:initialization_state_m;

signal wait_counter             :std_logic_vector(7 downto 0);
signal command_we_singel        :std_logic_vector(7 downto 0);
signal counter_data             :std_logic_vector(7 downto 0);
signal qspi_singel_initial      :std_logic;
signal nonvol_reg_cmd           :std_logic_vector(7 downto 0);
signal nonvol_reg_singel        :std_logic_vector(15 downto 0);
signal initialization_sm_done   :std_logic;

-- state machines

type Read_status_reg_state_m is (initial,send_q_cmd_pr,read_data_pr,write_data_to_read_reg);
signal Read_status_reg_sm:Read_status_reg_state_m;

signal initiate_read_status     :std_logic;

type Fast_read_state_m is (initial,initiate_send_q_cmd_pr,initiate_send_q_addr_pr,wait_10_dummy_cycle,
                           initiate_read_d_pr,write_data_to_read_reg);
signal Fast_read_sm:Fast_read_state_m;

signal dummy_10_cycles_counter	 :std_logic_vector(3 downto 0);
signal Dummy_cycles_done      	 :std_logic;

type write_d_to_qspi_state_m is (initial,initiate_send_q_cmd_pr,initiate_send_q_addr_pr,initiate_send_q_data_pr);
signal write_d_to_qspi_sm:write_d_to_qspi_state_m;

type write_16bits_command_state_m is (initial,initiate_send_q_cmd_pr,initiate_send_nonvol_d_pr);
signal write_16bits_command_sm:write_16bits_command_state_m;

type write_8bits_command_state_m is (initial,initiate_send_q_cmd_pr,initiate_send_q_data_pr);
signal write_8bits_command_sm:write_8bits_command_state_m;

signal initiate_8bits_data 		:std_logic;

type sector_erase_state_m is (initial,initiate_send_q_cmd_pr,initiate_send_q_addr_pr);
signal sector_erase_sm:sector_erase_state_m;

begin
qspi_clk_out <= qspi_clock;

process (clock, reset) is
begin
    if (reset = '0') then
        clock_en <= '0';
		clock_en_cnt <= "00";
	elsif(falling_edge (clock)) then
	    if (clock_en_cnt < "11") then
            clock_en_cnt <= clock_en_cnt +'1';
		    clock_en <= '0';
		else
		    clock_en_cnt <= clock_en_cnt +'1';
		    clock_en <= '1';
		end if;
	end if;
end process;

process (clock, reset) is
begin
    if (reset = '0') then
        clock_en_rising_edge <= '0';
		clock_en_cnt_rising_edge <= "00";
	elsif(falling_edge(clock)) then 
	    if (clock_en_cnt_rising_edge = "01") then
            clock_en_cnt_rising_edge <= clock_en_cnt_rising_edge +'1';
		    clock_en_rising_edge <= '1';
		else
		    clock_en_cnt_rising_edge <= clock_en_cnt_rising_edge +'1';
		    clock_en_rising_edge <= '0';
		end if;
	end if;
end process;

process (clock, reset) is
begin
    if (reset = '0') then
        qspi_clock <= '0';                     --25Mhz
		qspi_clock_cnt <= "00";
	elsif(falling_edge(clock)) then
	    if (qspi_clock_cnt < "10") then
            qspi_clock_cnt <= qspi_clock_cnt +'1';
		    qspi_clock <= '0';
		elsif (qspi_clock_cnt = "10" or qspi_clock_cnt = "11") then 
		    qspi_clock_cnt <= qspi_clock_cnt +'1';
		    qspi_clock <= '1';
		else
		    qspi_clock <= qspi_clock;
			qspi_clock_cnt <= qspi_clock_cnt;
		end if;
	end if;
end process;

-- Read process
process (clock, reset) is
begin
    if (reset = '0') then
	    qspi_io_in_sig <= (others=>'0');
	    data_in_counter <= (others=>'0');	
	elsif(falling_edge(clock)) then
	    if (clock_en_rising_edge = '1') then
	        if (Dummy_cycles_done = '1' and data_in_counter < X"8") then
		        data_in_counter <= data_in_counter + '1';
				if (data_in_counter = X"0") then
					qspi_io_in_sig(31 downto 28) <= qspi_io_in(3 downto 0);
				elsif (data_in_counter = X"1") then
					qspi_io_in_sig(27 downto 24) <= qspi_io_in(3 downto 0);
				elsif (data_in_counter = X"2") then
					qspi_io_in_sig(23 downto 20) <= qspi_io_in(3 downto 0);
				elsif (data_in_counter = X"3") then
					qspi_io_in_sig(19 downto 16) <= qspi_io_in(3 downto 0);
				elsif (data_in_counter = X"4") then
					qspi_io_in_sig(15 downto 12) <= qspi_io_in(3 downto 0);
				elsif (data_in_counter = X"5") then
					qspi_io_in_sig(11 downto 8) <= qspi_io_in(3 downto 0);
				elsif (data_in_counter = X"6") then
					qspi_io_in_sig(7 downto 4) <= qspi_io_in(3 downto 0);
				else
					qspi_io_in_sig(3 downto 0) <= qspi_io_in(3 downto 0);
				end if;
			elsif (initiate_read_status = '1' and data_in_counter < X"2") then
		        data_in_counter <= data_in_counter + '1';
				if (data_in_counter = X"0") then
					qspi_io_in_sig(7 downto 4) <= qspi_io_in(3 downto 0);
				else
					qspi_io_in_sig(3 downto 0) <= qspi_io_in(3 downto 0);
				end if;
		    	
		    else
		        data_in_counter <= (others=>'0');
		        qspi_io_in_sig <= qspi_io_in_sig;
		    end if;
		end if;
	end if;
end process;

-- send command process
process (clock, reset) is
begin
    if (reset = '0') then
		command_data_sig <= X"00";             -- 8 bit command
		command_counter <= "00";
		start_cmd_out <= '0';
		send_quad_cmd_done <= '0';
		qspi_dq_cmd_out <= (others=> '0');
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            if (initiate_cmd = '1') then
				if (command_counter = "00") then
				    command_data_sig <= command_data(7 downto 0);
					qspi_dq_cmd_out <= (others=> '0');
					start_cmd_out <= '1';
					send_quad_cmd_done <= '0';
					command_counter <= command_counter + '1';
				elsif (command_counter = "01") then
				    qspi_dq_cmd_out <= command_data_sig(7 downto 4);
				    start_cmd_out <= '1';
					send_quad_cmd_done <= '0';
					command_counter <= command_counter + '1';
				elsif (command_counter = "10") then
				    qspi_dq_cmd_out <= command_data_sig(3 downto 0);
				    start_cmd_out <= '0';
					send_quad_cmd_done <= '1';
					command_counter <= command_counter + '1';
				else
				    qspi_dq_cmd_out <= qspi_dq_cmd_out;
			        command_data_sig <= command_data_sig;
				    command_counter <= command_counter;
				    start_cmd_out <= start_cmd_out;
				    send_quad_cmd_done <= send_quad_cmd_done;
				end if;
			else
			    qspi_dq_cmd_out <= qspi_dq_cmd_out;
			    command_data_sig <= command_data_sig;
				command_counter <= "00";
				start_cmd_out <= '0';
				send_quad_cmd_done <= '0';
			end if;
		end if;
	end if;
end process;


--Send address process
process (clock, reset) is
begin
    if (reset = '0') then
		address_data_sig <= X"000000";  --24 bit address
		address_counter <= "000";
		start_add_out <= '0';
		send_quad_add_done <= '0';
		qspi_dq_add_out <= (others=> '0');
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            if (initiate_add = '1') then
				address_counter <= address_counter + '1';
				if (address_counter = "000") then
				    address_data_sig <= address_data(23 downto 0);
					qspi_dq_add_out <= (others=> '0');
					start_add_out <= '1';
					send_quad_add_done <= '0';
				elsif (address_counter >= "001" and address_counter <= "110" ) then
				    qspi_dq_add_out <= address_data_sig(23 downto 20);
					address_data_sig <= address_data_sig(19 downto 0)&address_data_sig(23 downto 20);
				    if (address_counter = "110") then
				        start_add_out <= '0';
					    send_quad_add_done <= '1';
					else
					   	start_add_out <= '1';
					    send_quad_add_done <= '0';
					end if;
				else
				    qspi_dq_add_out <= qspi_dq_add_out;
			        address_data_sig <= address_data_sig;
				    address_counter <= address_counter;
				    start_add_out <= start_add_out;
				    send_quad_add_done <= send_quad_add_done;
				end if;
			else
			    qspi_dq_add_out <= qspi_dq_add_out;
			    address_data_sig <= address_data_sig;
				address_counter <= "000";
				start_add_out <= '0';
				send_quad_add_done <= '0';
			end if;
		end if;
	end if;
end process;

--Send Quad data process
process (clock, reset) is
begin
    if (reset = '0') then
		output_data_sig <= X"00000000";  --32bit data
		data_out_counter <= "0000";
		start_data_out <= '0';
		send_quad_data_done <= '0';
		qspi_dq_data_out <= (others=> '0');
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            if (initiate_data = '1') then
				data_out_counter <= data_out_counter + '1';
				if (data_out_counter = "0000") then
				    output_data_sig <= data_write(31 downto 0);
					qspi_dq_data_out <= (others=> '0');
					start_data_out <= '1';
					send_quad_data_done <= '0';
				elsif (data_out_counter >= "0001" and data_out_counter <= "1000" ) then
				    qspi_dq_data_out <= output_data_sig(31 downto 28);
					output_data_sig <= output_data_sig(27 downto 0)&output_data_sig(31 downto 28);
				    if (data_out_counter = "1000") then
				        start_data_out <= '0';
					    send_quad_data_done <= '1';
					else
					   	start_data_out <= '1';
					    send_quad_data_done <= '0';
					end if;
				else
				    qspi_dq_data_out <= qspi_dq_data_out;
			        output_data_sig <= output_data_sig;
				    data_out_counter <= data_out_counter;
				    start_data_out <= start_data_out;
				    send_quad_data_done <= send_quad_data_done;
				end if;
				
			elsif(initiate_8bits_data = '1')then
				data_out_counter <= data_out_counter + '1';
				if (data_out_counter = "0000") then
				    output_data_sig <= data_write(31 downto 0);
					qspi_dq_data_out <= (others=> '0');
					start_data_out <= '1';
					send_quad_data_done <= '0';
				elsif (data_out_counter >= "0001" and data_out_counter <= "0010" ) then
				    qspi_dq_data_out <= output_data_sig(7 downto 4);
					output_data_sig <= output_data_sig(27 downto 0)&output_data_sig(31 downto 28);
				    if (data_out_counter = "0010") then
				        start_data_out <= '0';
					    send_quad_data_done <= '1';
					else
					   	start_data_out <= '1';
					    send_quad_data_done <= '0';
					end if;
				else
				    qspi_dq_data_out <= qspi_dq_data_out;
			        output_data_sig <= output_data_sig;
				    data_out_counter <= data_out_counter;
				    start_data_out <= start_data_out;
				    send_quad_data_done <= send_quad_data_done;
				end if;
			
			else
			    qspi_dq_data_out <= qspi_dq_data_out;
			    output_data_sig <= output_data_sig;
				data_out_counter <= "0000";
				start_data_out <= '0';
				send_quad_data_done <= '0';
			end if;
		end if;
	end if;
end process;


--Send Quad nonvolatile data process (16 bits)
process (clock, reset) is
begin
    if (reset = '0') then
		output_nonvol_sig <= X"0000";  --16bit data nonvolatile register
		nonvol_out_counter <= "000";
		start_nonvol_out <= '0';
		send_quad_nonvol_done <= '0';
		qspi_dq_nonvol_out <= (others=> '0');
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            if (initiate_nonvol = '1') then
				nonvol_out_counter <= nonvol_out_counter + '1';
				if (nonvol_out_counter = "000") then
				    output_nonvol_sig <= data_write(15 downto 0);
					qspi_dq_nonvol_out <= (others=> '0');
					start_nonvol_out <= '1';
					send_quad_nonvol_done <= '0';
				elsif (nonvol_out_counter >= "001" and nonvol_out_counter <= "100" ) then
				    if (nonvol_out_counter = "001") then
					    qspi_dq_nonvol_out <= output_nonvol_sig(7 downto 4); --LSB
					elsif(nonvol_out_counter = "010") then
					    qspi_dq_nonvol_out <= output_nonvol_sig(3 downto 0);
					elsif(nonvol_out_counter = "011") then
						qspi_dq_nonvol_out <= output_nonvol_sig(15 downto 12); --MSB
					elsif(nonvol_out_counter = "100") then
						qspi_dq_nonvol_out <= output_nonvol_sig(11 downto 8);
						start_nonvol_out <= '0';
					    send_quad_nonvol_done <= '1';
					else
						qspi_dq_nonvol_out <= qspi_dq_nonvol_out;
						start_nonvol_out <= '1';
					    send_quad_nonvol_done <= '0';
					end if;
				else
				    qspi_dq_nonvol_out <= qspi_dq_nonvol_out;
			        output_nonvol_sig <= output_nonvol_sig;
				    nonvol_out_counter <= nonvol_out_counter;
				    start_nonvol_out <= start_nonvol_out;
				    send_quad_nonvol_done <= send_quad_nonvol_done;
				end if;
			else
			    qspi_dq_nonvol_out <= qspi_dq_nonvol_out;
			    output_nonvol_sig <= output_nonvol_sig;
				nonvol_out_counter <= "000";
				start_nonvol_out <= '0';
				send_quad_nonvol_done <= '0';
			end if;
		end if;
	end if;
end process;


--main state machine
process (clock, reset) is
begin
    if (reset = '0') then
        main_sm <= initial;
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case main_sm is
				when initial =>
				    if (Send_data(0) = '1' and initialization_sm_done = '1') then
						main_sm <= read_command_data_register1;
					else
						main_sm <= initial;
					end if;
					
				when read_command_data_register1 =>
				    if (command_data = X"05" or command_data = X"70") then
						main_sm <= read_status_register;
					elsif (command_data = X"0B") then
					    main_sm <= fast_read;
					elsif (command_data = X"06") then
					    main_sm <= write_enable;
					else
						main_sm <= read_command_data_register1;
					end if;
					
				when read_status_register =>
					if (done_read = '1') then
						main_sm <= initial;
					else
						main_sm <= read_status_register;
					end if;
				
				when fast_read =>
					if (fast_read_sm = write_data_to_read_reg) then
						main_sm <= initial;
					else
						main_sm <= fast_read;
					end if;
					
				when write_enable =>
				    if (Send_data(0) = '1' and send_quad_cmd_done = '1') then
						main_sm <= read_command_data_register2;
					else
						main_sm <= write_enable;
					end if;
				
				when read_command_data_register2 =>
					if (command_data = X"02" and send_data(0) = '1') then
						main_sm <= write_data_to_the_qspi;
					elsif (command_data = X"B1" and send_data(0) = '1') then --write nonvolatile register
					    main_sm <= write_16bits_command;
					elsif ((command_data = X"61" or command_data = X"81") and send_data(0) = '1') then --write volatile or enhanched volatile registers
					    main_sm <= write_8bits_command;
					elsif (command_data = X"D8" and send_data(0) = '1') then
					    main_sm <= sector_erase;
					else
						main_sm <= read_command_data_register2;
					end if;
				
				when write_data_to_the_qspi =>
					if (done_write = '1') then
						main_sm <= initial;
					else
						main_sm <= write_data_to_the_qspi;
					end if;
				when write_16bits_command =>
					if (done_write = '1') then
						main_sm <= initial;
					else
						main_sm <= write_16bits_command;
					end if;
				when write_8bits_command =>
					if (done_write = '1') then
						main_sm <= initial;
					else
						main_sm <= write_8bits_command;
					end if;
				when sector_erase =>
					if (done_write = '1') then
						main_sm <= initial;
					else
						main_sm <= sector_erase;
					end if;
					
				when others => main_sm <= initial;
				
			end case;		
		end if;
	end if;
end process;


data_read <= data_read_sig;
--main state machine
process (clock, reset) is
begin
    if (reset = '0') then
        done_read <= '0';
		done_write <= '0';
		initiate_add <= '0';
		initiate_cmd <= '0';
		initiate_data <= '0';
		initiate_nonvol <= '0';
		initiate_8bits_data <= '0';
		qspi_io_out(3 downto 0) <= "0000";
		qspi_cs <= '1';
		qspi_out_en <= '1'; --write
		qspi_init_state <= '1'; -- init mode
		qspi_dummy_cycle <= '0';
		data_read_sig <= X"00000000";
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case main_sm is
				when initial =>
				    done_read <= '0';
		            done_write <= '0';
		            initiate_add <= '0';
		            initiate_cmd <= '0';
		            initiate_data <= '0';
		            initiate_nonvol <= '0';
					initiate_8bits_data <= '0';
					qspi_out_en <= '1'; --write
					qspi_dummy_cycle <= '0';
					data_read_sig <= data_read_sig;
				if ((initialization_sm = send_command_we) and (counter_data >= X"01" and counter_data <= X"09")) then
					qspi_io_out(0) <= qspi_singel_initial;
					qspi_io_out(2 downto 1) <= "00";
					qspi_io_out(3) <= '1';
					qspi_init_state <= '1'; -- init mode
					qspi_cs <= '0';
				elsif ((initialization_sm = send_cmd_nonvol) and (counter_data >= X"01" and counter_data <= X"08")) then
					qspi_io_out(0) <= qspi_singel_initial;
					qspi_io_out(2 downto 1) <= "00";
					qspi_io_out(3) <= '1';
					qspi_init_state <= '1'; -- init mode
					qspi_cs <= '0';
				elsif ((initialization_sm = send_single_data) and (counter_data >= X"09" and counter_data <= X"18")) then
					qspi_io_out(0) <= qspi_singel_initial;
					qspi_io_out(2 downto 1) <= "00";
					qspi_io_out(3) <= '1';
					qspi_init_state <= '1'; -- init mode
					qspi_cs <= '0';
				else
				    qspi_io_out <= "0000";
					qspi_init_state <= '0'; -- quad mode
				    qspi_cs <= '1';
				end if;
				
				when read_command_data_register1 =>
				    qspi_io_out <= "0000";
				    qspi_cs <= '1';
				    qspi_out_en <= '1'; --write
				
				when read_status_register =>
					if (Read_status_reg_sm = initial) then
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
					elsif (Read_status_reg_sm = send_q_cmd_pr) then
					    qspi_io_out <= qspi_dq_cmd_out;
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
						if (command_counter >= "10") then
							qspi_cs <= '0';
						else
							qspi_cs <= '1';
						end if;
					elsif (Read_status_reg_sm = read_data_pr) then
					    initiate_cmd <= '0';
					    qspi_io_out <= "0000";
				        qspi_cs <= '0';
				        qspi_out_en <= '0'; --read
						if (data_in_counter = X"02") then
							done_read <= '1';
							qspi_cs <= '1';
						end if;
					elsif (Read_status_reg_sm = write_data_to_read_reg) then
					    data_read_sig <= X"000000"&qspi_io_in_sig(7 downto 0);
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						done_read <= '1';
					else
					    qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
					end if;

				when fast_read =>
					if (Fast_read_sm = initial) then
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
					elsif (Fast_read_sm = initiate_send_q_cmd_pr) then
					    qspi_io_out <= qspi_dq_cmd_out;
				        qspi_out_en <= '1'; --write
						if (command_counter >= "01") then
							initiate_add <= '1';
						else
						    initiate_add <= '0';
						end if;
						if (command_counter >= "10") then
							qspi_cs <= '0';
						else
							qspi_cs <= '1';
						end if;
					elsif (Fast_read_sm = initiate_send_q_addr_pr) then
					    qspi_io_out <= qspi_dq_add_out;
				        qspi_cs <= '0';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '0';
					elsif (Fast_read_sm = wait_10_dummy_cycle) then
						initiate_add <= '0';
						qspi_io_out <= "0000";
				        qspi_cs <= '0';
						qspi_dummy_cycle <= '1';
						
						if (dummy_10_cycles_counter >= X"A") then
							qspi_out_en <= '0'; --read
						else
							qspi_out_en <= '1'; --write
						end if;
					elsif (Fast_read_sm = initiate_read_d_pr) then
						qspi_io_out <= "0000";
				        qspi_cs <= '0';
				        qspi_out_en <= '0'; --read
						
					elsif (Fast_read_sm = write_data_to_read_reg) then
						data_read_sig <= qspi_io_in_sig;
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						done_read <= '1';
					else
					    qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
					end if;
				
				when write_enable =>
					if (send_data(0) = '1' and send_quad_cmd_done = '1') then
						initiate_cmd <= '0';
						qspi_io_out <= qspi_dq_cmd_out;
						qspi_cs <= '0';
					else
						initiate_cmd <= '1';
						qspi_out_en <= '1'; --write
						if (command_counter = "10") then
							qspi_io_out <= qspi_dq_cmd_out;
							qspi_cs <= '0';
						else
							qspi_io_out <= "0000";
							qspi_cs <= '1';
						end if;
					end if;
					
				when read_command_data_register2 =>
					qspi_io_out <= "0000";
				    qspi_cs <= '1';
				    qspi_out_en <= '1'; --write
				
				when write_data_to_the_qspi =>
					if (write_d_to_qspi_sm = initial) then
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
						done_write <= '0';
					elsif (write_d_to_qspi_sm = initiate_send_q_cmd_pr) then
				        qspi_out_en <= '1'; --write
					    qspi_io_out <= qspi_dq_cmd_out;
						if (command_counter >= "01") then
							initiate_add <= '1';
						else
							initiate_add <= '0';
						end if;
						if (command_counter >= "10") then
							qspi_cs <= '0';
						else
							qspi_cs <= '1';
						end if;
					elsif (write_d_to_qspi_sm = initiate_send_q_addr_pr) then
					    qspi_io_out <= qspi_dq_add_out;
				        qspi_cs <= '0';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '0';
						if (address_counter >= "101") then
							initiate_data <= '1';
						else
						    initiate_data <= '0';
						end if;
					elsif (write_d_to_qspi_sm = initiate_send_q_data_pr) then
						qspi_io_out <= qspi_dq_data_out;
				        qspi_cs <= '0';
				        qspi_out_en <= '1'; --write
						initiate_add <= '0';
						if (data_out_counter = "1001") then
							initiate_data <= '0';
							done_write <= '1';
						else
							initiate_data <= '1';
						end if;
					else
					    qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
					end if;
					
				when write_16bits_command =>
					if (write_16bits_command_sm = initial) then
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
						done_write <= '0';
					elsif (write_16bits_command_sm = initiate_send_q_cmd_pr) then
					    qspi_io_out <= qspi_dq_cmd_out;
				        qspi_out_en <= '1'; --write
						if (command_counter >= "01") then
							initiate_nonvol <= '1';
						else
						    initiate_nonvol <= '0';
						end if;
						if (command_counter >= "10") then
							qspi_cs <= '0';
						else
							qspi_cs <= '1';
						end if;
					elsif (write_16bits_command_sm = initiate_send_nonvol_d_pr) then
						qspi_io_out <= qspi_dq_nonvol_out;
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '0';
						qspi_cs <= '0';
						if (nonvol_out_counter = "101") then
							initiate_nonvol <= '0';
							done_write <= '1';
						else
							initiate_nonvol <= '1';
						end if;
					else
					    qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
					end if;
				
				when write_8bits_command =>
					if (write_8bits_command_sm = initial) then
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
						done_write <= '0';
					elsif (write_8bits_command_sm = initiate_send_q_cmd_pr) then
					    qspi_io_out <= qspi_dq_cmd_out;
				        qspi_out_en <= '1'; --write
						if (command_counter >= "01") then
							initiate_8bits_data <= '1';
						else
						    initiate_8bits_data <= '0';
						end if;
						if (command_counter >= "10") then
							qspi_cs <= '0';
						else
							qspi_cs <= '1';
						end if;
					elsif (write_8bits_command_sm = initiate_send_q_data_pr) then
						qspi_io_out <= qspi_dq_data_out;
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '0';
						qspi_cs <= '0';
						if (data_out_counter = "0011") then
							initiate_8bits_data <= '0';
							done_write <= '1';
						else
							
							initiate_8bits_data <= '1';
						end if;
					else
					    qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
					end if;
				
				when sector_erase =>
					if (sector_erase_sm = initial) then
						qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '1';
						done_write <= '0';
					elsif (sector_erase_sm = initiate_send_q_cmd_pr) then
					    qspi_io_out <= qspi_dq_cmd_out;
				        qspi_out_en <= '1'; --write
						if (command_counter >= "01") then
							initiate_add <= '1';
						else
						    initiate_add <= '0';
						end if;
						if (command_counter >= "10") then
							qspi_cs <= '0';
						else
							qspi_cs <= '1';
						end if;
					elsif (sector_erase_sm = initiate_send_q_addr_pr) then
						qspi_io_out <= qspi_dq_add_out;
				        qspi_out_en <= '1'; --write
						initiate_cmd <= '0';
						qspi_cs <= '0';
						if (address_counter >= "111") then
							initiate_add <= '0';
							done_write <= '1';
						else
							initiate_add <= '1';
						end if;
					else
					    qspi_io_out <= "0000";
				        qspi_cs <= '1';
				        qspi_out_en <= '1'; --write
					end if;
				
				
				when others =>  qspi_io_out <= "0000";
								qspi_cs <= '1';
								qspi_out_en <= '1'; --write
							
			end case;
		end if;
	end if;
end process;




--initialization state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    initialization_sm <= initial;
        wait_counter <= X"00";
		counter_data <= X"00";
		qspi_singel_initial <= '0';
		command_we_singel <= X"06"; --write enable command
		nonvol_reg_cmd <= X"B1"; --write nonvolatile register
		nonvol_reg_singel <= X"F7AF"; --sending AFF7h to the nonvol reg 
	    initialization_sm_done <= '0';
		
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case initialization_sm is
				when initial =>
                    if (wait_counter >= X"DF" and wait_counter < X"FF") then
						
						initialization_sm <= initial;
					    wait_counter <= wait_counter + '1';
                    elsif (wait_counter = X"FF") then
						
					    wait_counter <= X"00";
					    initialization_sm <= send_command_we;
					else
					    initialization_sm <= initial;
					    wait_counter <= wait_counter + '1';
						
					end if;
					
				when send_command_we =>
					if (counter_data = X"09") then
					    initialization_sm <= wait_before_next_cmd;
						counter_data <= X"00";
						qspi_singel_initial <= '0';
					else
					    qspi_singel_initial <= command_we_singel(7);
						command_we_singel <= command_we_singel(6 downto 0)& command_we_singel(7);
						counter_data <= counter_data + '1';
						initialization_sm <= send_command_we;
					end if;
					
				when wait_before_next_cmd =>
				    qspi_singel_initial <= '0';
                    if (wait_counter = X"B0") then
					    wait_counter <= X"00";
					    initialization_sm <= send_cmd_nonvol;
					else
					    initialization_sm <= wait_before_next_cmd;
					    wait_counter <= wait_counter + '1';
					end if;
					
				when send_cmd_nonvol =>
					if (counter_data = X"08") then
					    initialization_sm <= send_single_data;
						counter_data <= counter_data + '1';
						qspi_singel_initial <= nonvol_reg_singel(15);
						nonvol_reg_singel <= nonvol_reg_singel(14 downto 0)& nonvol_reg_singel(15);
					else -- counter_data < X"09"
					    qspi_singel_initial <= nonvol_reg_cmd(7);
						nonvol_reg_cmd <= nonvol_reg_cmd(6 downto 0)& nonvol_reg_cmd(7);
						counter_data <= counter_data + '1';
						initialization_sm <= send_cmd_nonvol;
					end if;
				
				when send_single_data =>
					if (counter_data = X"18") then
					    initialization_sm <= done;
						counter_data <= X"00";
						qspi_singel_initial <= '0';
					else -- counter_data < X"10"
					    qspi_singel_initial <= nonvol_reg_singel(15);
						nonvol_reg_singel <= nonvol_reg_singel(14 downto 0)& nonvol_reg_singel(15);
						counter_data <= counter_data + '1';
						initialization_sm <= send_single_data;
					end if;
				
				when done =>
				
					if (wait_counter >= X"00" and wait_counter <= X"0F") then
						wait_counter <= wait_counter + '1';
						
						qspi_singel_initial <= '0';
						initialization_sm <= done;
						initialization_sm_done <= '0';
					elsif (wait_counter > X"0F" and wait_counter <= X"B0") then
						wait_counter <= wait_counter + '1';
						
						qspi_singel_initial <= '0';
						initialization_sm <= done;
						initialization_sm_done <= '0';
					else
						wait_counter <= wait_counter;
						
                        initialization_sm <= done;
						qspi_singel_initial <= '0';
						initialization_sm_done <= '1';
					end if;
				when others => initialization_sm <= done;
							
			end case;
		end if;
	end if;
end process;





--Read status register state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    Read_status_reg_sm <= initial;
        initiate_read_status <= '0';
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case Read_status_reg_sm is
				when initial =>
					if (main_sm = read_status_register) then
						Read_status_reg_sm <= send_q_cmd_pr;
				    else
						Read_status_reg_sm <= initial;
					end if;
					
				when send_q_cmd_pr =>
					if (command_counter = "11") then
						Read_status_reg_sm <= read_data_pr;
				    else
						Read_status_reg_sm <= send_q_cmd_pr;
					end if;
				
				when read_data_pr =>
					if (data_in_counter = X"2") then
						Read_status_reg_sm <= write_data_to_read_reg;
						initiate_read_status <= '0';
				    else
					    initiate_read_status <= '1';
						Read_status_reg_sm <= read_data_pr;
					end if;
				
				when write_data_to_read_reg =>
                    Read_status_reg_sm <= initial;

				when others => Read_status_reg_sm <= initial;

			end case;
		end if;
	end if;
end process;


--Fast Read state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    Fast_read_sm <= initial;
		Dummy_cycles_done <= '0';
		dummy_10_cycles_counter <= "0000";
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case Fast_read_sm is
				when initial =>
					Dummy_cycles_done <= '0';
					dummy_10_cycles_counter <= "0000";
					if (main_sm = fast_read) then
						Fast_read_sm <= initiate_send_q_cmd_pr;
					else
					    Fast_read_sm <= initial;
					end if;
				
				when initiate_send_q_cmd_pr =>
					if (command_counter = "11") then
						Fast_read_sm <= initiate_send_q_addr_pr;
				    else
						Fast_read_sm <= initiate_send_q_cmd_pr;
					end if;
				
				when initiate_send_q_addr_pr =>
					if (address_counter = "111") then
					    Fast_read_sm <= wait_10_dummy_cycle;
					else
					    Fast_read_sm <= initiate_send_q_addr_pr;
					end if;
				
				when wait_10_dummy_cycle =>
					dummy_10_cycles_counter <= dummy_10_cycles_counter + '1';
					if (dummy_10_cycles_counter = "1010") then
						Fast_read_sm <= initiate_read_d_pr;
						Dummy_cycles_done <= '1';
					else
						Fast_read_sm <= wait_10_dummy_cycle;
						Dummy_cycles_done <= '0';
					end if;
				when initiate_read_d_pr =>
					Dummy_cycles_done <= '1';
					if (data_in_counter = X"7") then
					    Fast_read_sm <= write_data_to_read_reg;
					else
					    Fast_read_sm <= initiate_read_d_pr;
					end if; 
				
				when write_data_to_read_reg =>
					Dummy_cycles_done <= '0';
					Fast_read_sm <= initial;

				when others => Fast_read_sm <= initial;
			
			end case;
		end if;
	end if;
end process;



--Write quad data to the qspi state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    write_d_to_qspi_sm <= initial;

	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case write_d_to_qspi_sm is
				when initial =>
					if (main_sm = write_data_to_the_qspi) then
						write_d_to_qspi_sm <= initiate_send_q_cmd_pr;
					else
					    write_d_to_qspi_sm <= initial;
					end if;
				
				when initiate_send_q_cmd_pr =>
					if (command_counter = "11") then
						write_d_to_qspi_sm <= initiate_send_q_addr_pr;
				    else
						write_d_to_qspi_sm <= initiate_send_q_cmd_pr;
					end if;
				
				when initiate_send_q_addr_pr =>
					if (address_counter = "111") then
					    write_d_to_qspi_sm <= initiate_send_q_data_pr;
					else
					    write_d_to_qspi_sm <= initiate_send_q_addr_pr;
					end if;
					
				when initiate_send_q_data_pr =>
					if (data_out_counter = "1001") then
					    write_d_to_qspi_sm <= initial;
					else
					    write_d_to_qspi_sm <= initiate_send_q_data_pr;
					end if;

				when others => write_d_to_qspi_sm <= initial;

			end case;
		end if;
	end if;
end process;


--write 16 bits to qspi state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    write_16bits_command_sm <= initial;
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case write_16bits_command_sm is
				when initial =>
					if (main_sm = write_16bits_command) then
						write_16bits_command_sm <= initiate_send_q_cmd_pr;
					else
					    write_16bits_command_sm <= initial;
					end if;
				
				when initiate_send_q_cmd_pr =>
					if (command_counter = "11") then
						write_16bits_command_sm <= initiate_send_nonvol_d_pr;
				    else
						write_16bits_command_sm <= initiate_send_q_cmd_pr;
					end if;
				
				when initiate_send_nonvol_d_pr =>
					if (nonvol_out_counter = "101") then
					    write_16bits_command_sm <= initial;
					else
					    write_16bits_command_sm <= initiate_send_nonvol_d_pr;
					end if;

				when others => write_16bits_command_sm <= initial;
			end case;
		end if;
	end if;
end process;



--write 8 bits to qspi state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    write_8bits_command_sm <= initial;
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case write_8bits_command_sm is
				when initial =>
					if (main_sm = write_8bits_command) then
						write_8bits_command_sm <= initiate_send_q_cmd_pr;
					else
					    write_8bits_command_sm <= initial;
					end if;
				
				when initiate_send_q_cmd_pr =>
					if (command_counter = "11") then
						write_8bits_command_sm <= initiate_send_q_data_pr;
				    else
						write_8bits_command_sm <= initiate_send_q_cmd_pr;
					end if;
				
				when initiate_send_q_data_pr =>
					if (data_out_counter = "0011") then
					    write_8bits_command_sm <= initial;
					else
					    write_8bits_command_sm <= initiate_send_q_data_pr;
					end if;

				when others => write_8bits_command_sm <= initial;
				
			end case;
		end if;
	end if;
end process;




--sector erase state machine
process (clock, reset) is
begin
    if (reset = '0') then
	    sector_erase_sm <= initial;
	elsif(falling_edge(clock)) then
	    if (clock_en = '1') then
            case sector_erase_sm is
				when initial =>
					if (main_sm = sector_erase) then
						sector_erase_sm <= initiate_send_q_cmd_pr;
					else
					    sector_erase_sm <= initial;
					end if;
				
				when initiate_send_q_cmd_pr =>
					if (command_counter = "11") then
						sector_erase_sm <= initiate_send_q_addr_pr;
				    else
						sector_erase_sm <= initiate_send_q_cmd_pr;
					end if;
				
				when initiate_send_q_addr_pr =>
					if (address_counter = "111") then
					    sector_erase_sm <= initial;
					else
					    sector_erase_sm <= initiate_send_q_addr_pr;
					end if;

				when others => sector_erase_sm <= initial;
				
			end case;
		end if;
	end if;
end process;






end arch;
