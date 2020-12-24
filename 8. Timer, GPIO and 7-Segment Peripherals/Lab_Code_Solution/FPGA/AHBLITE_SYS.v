//////////////////////////////////////////////////////////////////////////////////
//END USER LICENCE AGREEMENT                                                    //
//                                                                              //
//Copyright (c) 2012, ARM All rights reserved.                                  //
//                                                                              //
//THIS END USER LICENCE AGREEMENT ("LICENCE") IS A LEGAL AGREEMENT BETWEEN      //
//YOU AND ARM LIMITED ("ARM") FOR THE USE OF THE SOFTWARE EXAMPLE ACCOMPANYING  //
//THIS LICENCE. ARM IS ONLY WILLING TO LICENSE THE SOFTWARE EXAMPLE TO YOU ON   //
//CONDITION THAT YOU ACCEPT ALL OF THE TERMS IN THIS LICENCE. BY INSTALLING OR  //
//OTHERWISE USING OR COPYING THE SOFTWARE EXAMPLE YOU INDICATE THAT YOU AGREE   //
//TO BE BOUND BY ALL OF THE TERMS OF THIS LICENCE. IF YOU DO NOT AGREE TO THE   //
//TERMS OF THIS LICENCE, ARM IS UNWILLING TO LICENSE THE SOFTWARE EXAMPLE TO    //
//YOU AND YOU MAY NOT INSTALL, USE OR COPY THE SOFTWARE EXAMPLE.                //
//                                                                              //
//ARM hereby grants to you, subject to the terms and conditions of this Licence,//
//a non-exclusive, worldwide, non-transferable, copyright licence only to       //
//redistribute and use in source and binary forms, with or without modification,//
//for academic purposes provided the following conditions are met:              //
//a) Redistributions of source code must retain the above copyright notice, this//
//list of conditions and the following disclaimer.                              //
//b) Redistributions in binary form must reproduce the above copyright notice,  //
//this list of conditions and the following disclaimer in the documentation     //
//and/or other materials provided with the distribution.                        //
//                                                                              //
//THIS SOFTWARE EXAMPLE IS PROVIDED BY THE COPYRIGHT HOLDER "AS IS" AND ARM     //
//EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING     //
//WITHOUT LIMITATION WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR //
//PURPOSE, WITH RESPECT TO THIS SOFTWARE EXAMPLE. IN NO EVENT SHALL ARM BE LIABLE/
//FOR ANY DIRECT, INDIRECT, INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES OF ANY/
//KIND WHATSOEVER WITH RESPECT TO THE SOFTWARE EXAMPLE. ARM SHALL NOT BE LIABLE //
//FOR ANY CLAIMS, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, //
//TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE    //
//EXAMPLE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE EXAMPLE. FOR THE AVOIDANCE/
// OF DOUBT, NO PATENT LICENSES ARE BEING LICENSED UNDER THIS LICENSE AGREEMENT.//
//////////////////////////////////////////////////////////////////////////////////


module AHBLITE_SYS(
    //CLOCKS & RESET
    input       wire            CLK,
    input       wire            RESET, 
    
    //TO BOARD LEDs
    output      wire    [7:0]   LED,

	//VGA IO
	output	wire 	[2:0]		vgaRed,
	output 	wire	[2:0]		vgaGreen,
	output 	wire	[1:0]		vgaBlue,
	output 	wire				Hsync,     	//VGA Horizontal Sync
	output 	wire				Vsync,    	//VGA Vertical Sync

    //TO UART
	input 	wire				RsRx,
	output 	wire				RsTx,

	// Switch Inputs
    input 	wire	[7:0]		SW,
	
	// 7 Segment display
	output 	wire	[6:0]		seg,
	output 	wire				dp,
	output 	wire	[3:0]		an,

    // Debug
    input       wire            TCK_SWCLK,               // SWD Clk / JTAG TCK
    input       wire            TDI_NC,                  // NC      / JTAG TDI
    inout       wire            TMS_SWDIO,               // SWD I/O / JTAG TMS
    output      wire            TDO_SWO                  // SW  Out / JTAG TDO
);
 
//AHB-LITE SIGNALS 
//Gloal Signals
wire 			HCLK;
wire 			HRESETn;
//Address, Control & Write Data Signals
wire [31:0]		HADDR;
wire [31:0]		HWDATA;
wire 			HWRITE;
wire [1:0] 		HTRANS;
wire [2:0] 		HBURST;
wire 			HMASTLOCK;
wire [3:0] 		HPROT;
wire [2:0] 		HSIZE;
//Transfer Response & Read Data Signals
wire [31:0] 	HRDATA;
wire 			HRESP;
wire 			HREADY;

//SELECT SIGNALS
wire [3:0] 		MUX_SEL;

wire 				HSEL_MEM;
wire 				HSEL_VGA;
wire 				HSEL_UART;
wire 				HSEL_GPIO;
wire 				HSEL_TIMER;
wire 				HSEL_7SEG;

//SLAVE READ DATA
wire [31:0] 	HRDATA_MEM;
wire [31:0] 	HRDATA_VGA;
wire [31:0] 	HRDATA_UART;
wire [31:0] 	HRDATA_GPIO;
wire [31:0] 	HRDATA_TIMER;
wire [31:0] 	HRDATA_7SEG;

//SLAVE HREADYOUT
wire 				HREADYOUT_MEM;
wire 				HREADYOUT_VGA;
wire 				HREADYOUT_UART;
wire 				HREADYOUT_GPIO;
wire 				HREADYOUT_TIMER;
wire 				HREADYOUT_7SEG;

//CM0-DS Sideband signals
wire [31:0]		IRQ;

// CM-DS Sideband signals
wire            lockup;
wire            lockup_reset_req;
wire            sys_reset_req;

//SYSTEM GENERATES NO ERROR RESPONSE
assign 			HRESP = 1'b0;

// Interrupt signals
assign          IRQ = 32'h00000000;

// Clock
wire            fclk;                 // Free running clock
// Reset
wire            reset_n = RESET;

// Clock divider, divide the frequency by two, hence less time constraint 
reg clk_div;
always @(posedge CLK)
begin
    clk_div=~clk_div;
end
BUFG BUFG_CLK (
    .O(fclk),
    .I(clk_div)
);

// Reset synchronizer
reg  [4:0]     reset_sync_reg;
assign lockup_reset_req = 1'b0;
always @(posedge fclk or negedge reset_n)
begin
    if (!reset_n)
        reset_sync_reg <= 5'b00000;
    else
    begin
        reset_sync_reg[3:0] <= {reset_sync_reg[2:0], 1'b1};
        reset_sync_reg[4] <= reset_sync_reg[2] &
                            (~(sys_reset_req | (lockup & lockup_reset_req)));
    end
end

// CPU System Bus
assign HCLK = fclk;
assign HRESETn = reset_sync_reg[4];

// Debug signals (DesignStart Cortex-M0 supports only SWD)
wire dbg_swdo_en;
wire dbg_swdo;
wire dbg_swdi;
assign TMS_SWDIO = dbg_swdo_en ? dbg_swdo : 1'bz;
assign dbg_swdi = TMS_SWDIO;
wire cdbgpwrupreq2ack;

// DesignStart simplified integration level
CORTEXM0INTEGRATION u_CORTEXM0INTEGRATION (
    // CLOCK AND RESETS
    .FCLK          (fclk),
    .SCLK          (fclk),
    .HCLK          (fclk),
    .DCLK          (fclk),
    .PORESETn      (reset_sync_reg[2]),
    .DBGRESETn     (reset_sync_reg[3]),
    .HRESETn       (HRESETn),
    .SWCLKTCK      (TCK_SWCLK),
    .nTRST         (1'b1),

    // AHB-LITE MASTER PORT
    .HADDR         (HADDR),
    .HBURST        (HBURST),
    .HMASTLOCK     (HMASTLOCK),
    .HPROT         (HPROT),
    .HSIZE         (HSIZE),
    .HTRANS        (HTRANS),
    .HWDATA        (HWDATA),
    .HWRITE        (HWRITE),
    .HRDATA        (HRDATA),
    .HREADY        (HREADY),
    .HRESP         (HRESP),
    .HMASTER       (),

    // CODE SEQUENTIALITY AND SPECULATION
    .CODENSEQ      (),
    .CODEHINTDE    (),
    .SPECHTRANS    (),

    // DEBUG
    .SWDITMS       (dbg_swdi),
    .TDI           (TDI_NS),
    .SWDO          (dbg_swdo),
    .SWDOEN        (dbg_swdo_en),
    .TDO           (TDO_SWO),
    .nTDOEN        (),
    .DBGRESTART    (1'b0),
    .DBGRESTARTED  (),
    .EDBGRQ        (1'b0),               // External Debug request to CPU
    .HALTED        (),

    // MISC
    .NMI           (1'b0),               // Non-maskable interrupt input
    .IRQ           (IRQ),                // Interrupt request inputs
    .TXEV          (),                   // Event output (SEV executed)
    .RXEV          (1'b0),               // Event input
    .LOCKUP        (lockup),             // Core is locked-up
    .SYSRESETREQ   (sys_reset_req),      // System reset request
    .STCALIB       ({1'b1,               // No alternative clock source
                     1'b0,               // Exact multiple of 10ms from FCLK
                     24'h007A11F}),      // Calibration value for SysTick for 50 MHz source
    .STCLKEN       (1'b0),               // SysTick SCLK clock disable
    .IRQLATENCY    (8'h00),
    .ECOREVNUM     (28'h0),

    // POWER MANAGEMENT
    .GATEHCLK      (),
    .SLEEPING      (),                   // Core and NVIC sleeping
    .SLEEPDEEP     (),
    .WAKEUP        (),
    .WICSENSE      (),
    .SLEEPHOLDREQn (1'b1),
    .SLEEPHOLDACKn (),
    .WICENREQ      (1'b0),
    .WICENACK      (),
    .CDBGPWRUPREQ  (cdbgpwrupreq2ack),
    .CDBGPWRUPACK  (cdbgpwrupreq2ack),

    // SCAN IO
    .SE            (1'b0),
    .RSTBYPASS     (1'b0)
);

//Address Decoder 

AHBDCD uAHBDCD (
    .HADDR(HADDR[31:0]),
     
	.HSEL_S0(HSEL_MEM),
	.HSEL_S1(HSEL_VGA),
    .HSEL_S2(HSEL_UART),
    .HSEL_S3(HSEL_TIMER),
    .HSEL_S4(HSEL_GPIO),
    .HSEL_S5(HSEL_7SEG),
    .HSEL_S6(),
    .HSEL_S7(),
    .HSEL_S8(),
    .HSEL_S9(),
    .HSEL_NOMAP(),
     
	.MUX_SEL(MUX_SEL[3:0])
);

//Slave to Master Mulitplexor

AHBMUX uAHBMUX (
	.HCLK(HCLK),
	.HRESETn(HRESETn),
	.MUX_SEL(MUX_SEL[3:0]),
	 
	.HRDATA_S0(HRDATA_MEM),
	.HRDATA_S1(HRDATA_VGA),
	.HRDATA_S2(HRDATA_UART),
	.HRDATA_S3(HRDATA_TIMER),
	.HRDATA_S4(HRDATA_GPIO),
	.HRDATA_S5(HRDATA_7SEG),
	.HRDATA_S6(32'h00000000),
	.HRDATA_S7(32'h00000000),
	.HRDATA_S8(32'h00000000),
	.HRDATA_S9(32'h00000000),
	.HRDATA_NOMAP(32'hDEADBEEF),
	 
	.HREADYOUT_S0(HREADYOUT_MEM),
	.HREADYOUT_S1(HREADYOUT_VGA),
	.HREADYOUT_S2(HREADYOUT_UART),
	.HREADYOUT_S3(HREADYOUT_TIMER),
	.HREADYOUT_S4(HREADYOUT_GPIO),
	.HREADYOUT_S5(HREADYOUT_7SEG),
	.HREADYOUT_S6(1'b1),
	.HREADYOUT_S7(1'b1),
	.HREADYOUT_S8(1'b1),
	.HREADYOUT_S9(1'b1),
	.HREADYOUT_NOMAP(1'b1),
    
	.HRDATA(HRDATA[31:0]),
	.HREADY(HREADY)
);

// AHBLite Peripherals


// AHB-Lite RAM
AHB2MEM uAHB2MEM (
	//AHBLITE Signals
	.HSEL(HSEL_MEM),
	.HCLK(HCLK), 
	.HRESETn(HRESETn), 
	.HREADY(HREADY),     
	.HADDR(HADDR),
	.HTRANS(HTRANS[1:0]), 
	.HWRITE(HWRITE),
	.HSIZE(HSIZE),
	.HWDATA(HWDATA[31:0]), 
	
	.HRDATA(HRDATA_MEM), 
	.HREADYOUT(HREADYOUT_MEM)
);

// AHBLite VGA Peripheral
AHBVGA uAHBVGA (
    .HCLK(HCLK), 
    .HRESETn(HRESETn), 
    .HADDR(HADDR), 
    .HWDATA(HWDATA), 
    .HREADY(HREADY), 
    .HWRITE(HWRITE), 
    .HTRANS(HTRANS), 
    .HSEL(HSEL_VGA), 
    .HRDATA(HRDATA_VGA), 
    .HREADYOUT(HREADYOUT_VGA), 
    .hsync(Hsync), 
    .vsync(Vsync), 
    .rgb({vgaRed,vgaGreen,vgaBlue})
    );

AHBUART uAHBUART(
	.HCLK(HCLK),
	.HRESETn(HRESETn),
	.HADDR(HADDR),
	.HWDATA(HWDATA),
	.HREADY(HREADY),
	.HWRITE(HWRITE),
	.HTRANS(HTRANS),
	.HSEL(HSEL_UART),
	.HRDATA(HRDATA_UART),
	.HREADYOUT(HREADYOUT_UART),
	
	.RsRx(RsRx),
	.RsTx(RsTx)
//	.uart_irq(UART_IRQ)
    );
    
// AHBLite 7-segment Pheripheral	 
AHB7SEGDEC uAHB7SEGDEC(
	.HCLK(HCLK),
	.HRESETn(HRESETn),
	.HADDR(HADDR),
	.HWDATA(HWDATA),
	.HREADY(HREADY),
	.HWRITE(HWRITE),
	.HTRANS(HTRANS),
    
	.HSEL(HSEL_7SEG),
	.HRDATA(HRDATA_7SEG),
	.HREADYOUT(HREADYOUT_7SEG),
	 
	.seg(seg),
	.an(an),
	.dp(dp)
	);	
		
// AHBLite timer
AHBTIMER uAHBTIMER(
	.HCLK(HCLK),
	.HRESETn(HRESETn),
	.HADDR(HADDR),
	.HWDATA(HWDATA),
	.HREADY(HREADY),
	.HWRITE(HWRITE),
	.HTRANS(HTRANS),
    
	.HSEL(HSEL_TIMER),
	.HRDATA(HRDATA_TIMER[31:0]),
	.HREADYOUT(HREADYOUT_TIMER)
    
//	.timer_irq(TIMER_IRQ)
	);

// AHBLite GPIO	
AHBGPIO uAHBGPIO(
	.HCLK(HCLK),
	.HRESETn(HRESETn),
	.HADDR(HADDR),
	.HWDATA(HWDATA),
	.HREADY(HREADY),
	.HWRITE(HWRITE),
	.HTRANS(HTRANS),

	.HSEL(HSEL_GPIO),
	.HRDATA(HRDATA_GPIO),
	.HREADYOUT(HREADYOUT_GPIO),
    
	.GPIOIN({8'b00000000,SW[7:0]}),
	.GPIOOUT(LED[7:0])
	);
	
endmodule
