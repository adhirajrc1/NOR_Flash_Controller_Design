/*
-----------------------------------------------------------------------------------------------------
-- Company			: Space Applications Centre, ISRO
-- Engineer			: Adhiraj Roy Chowdhury
-- Create Date		: 16:35:00 10/05/2022
-- Target Devices	: FPGA:RT4G150_ES, Controller for 3DFS256M04VS2801 NOR Flash memory
------------------------------------------------------------------------------------------------------ 
*/

module flash_module 
    (
    input USERA_CE_N, 
    input USERA_SCK, 
    inout USERA_IO3,
    inout USERA_IO0, 
    inout USERA_IO1,  
    inout USERA_IO2,
    input USERB_CE_N,
    input USERB_SCK, 
    inout USERB_IO3, 
    inout USERB_IO0, 
    inout USERB_IO1, 
    inout USERB_IO2 	
    ); 

FlashNor_3DFS256 DUT (USERA_CE_N, USERA_SCK, USERA_IO3, USERA_IO0, USERA_IO1, USERA_IO2, USERB_CE_N, USERB_SCK, USERB_IO3, USERB_IO0, USERB_IO1, USERB_IO2);

endmodule