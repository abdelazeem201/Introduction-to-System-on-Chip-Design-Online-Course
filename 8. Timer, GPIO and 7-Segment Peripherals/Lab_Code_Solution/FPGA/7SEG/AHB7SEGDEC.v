//////////////////////////////////////////////////////////////////////////////////
//END USER LICENCE AGREEMENT                                                    //
//                                                                              //
//Copyright (c) 2012, ARM All rights reserved.                                  //
//                                                                              //
//THIS END USER LICENCE AGREEMENT (“LICENCE”) IS A LEGAL AGREEMENT BETWEEN      //
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


module AHB7SEGDEC(

	//Input
  input wire HCLK,
  input wire HRESETn,
  input wire [31:0] HADDR,
  input wire [31:0] HWDATA,
  input wire [1:0] HTRANS,
  input wire HWRITE,
  input wire HSEL,
  input wire HREADY,
 
	//Output
  output [31:0] HRDATA,
  output HREADYOUT,

	//7segment displa
  output [6:0] seg,
  output [3:0] an,
  output dp
  );

  localparam [3:0] DIGIT1_ADDR = 4'h0;
  localparam [3:0] DIGIT2_ADDR = 4'h4;
  localparam [3:0] DIGIT3_ADDR = 4'h8;
  localparam [3:0] DIGIT4_ADDR = 4'hC;


  reg last_HWRITE;
  reg [31:0] last_HADDR;
  reg last_HSEL;
  reg [1:0] last_HTRANS;

  reg [7:0] DIGIT1 = 8'hA;
  reg [7:0] DIGIT2 = 8'hB;
  reg [7:0] DIGIT3 = 8'hC; 
  reg [7:0] DIGIT4 = 8'hD;

  assign HREADYOUT = 1'b1; //Always ready

  always @(posedge HCLK)
    if(HREADY)
      begin
        last_HWRITE <= HWRITE;
        last_HSEL <= HSEL;
        last_HADDR <= HADDR;
        last_HTRANS <= HTRANS;
      end

  always @(posedge HCLK, negedge HRESETn)
  begin
    if(!HRESETn)
	 begin
      DIGIT1 <= 7'b0_0101;
		DIGIT2 <= 7'b0_1110;
		DIGIT3 <= 7'b0_0000;
		DIGIT4 <= 7'b0_0001;
	 end
    else if(last_HWRITE & last_HSEL & last_HTRANS[1])
	 begin
		if(last_HADDR[3:0] == DIGIT1_ADDR)
        	DIGIT1 <= HWDATA[7:0];
		else if(last_HADDR[3:0] == DIGIT2_ADDR)
			DIGIT2 <= HWDATA[7:0];
		else if(last_HADDR[3:0] == DIGIT3_ADDR)
			DIGIT3 <= HWDATA[7:0];
		else if(last_HADDR[3:0] == DIGIT4_ADDR)
			DIGIT4 <= HWDATA[7:0];
	 end
	end
	 
  assign HRDATA = (last_HADDR[3:0] == DIGIT1_ADDR) ? {24'h000_0000,DIGIT1} :
                  (last_HADDR[3:0] == DIGIT2_ADDR) ? {24'h000_0000,DIGIT2} :
                  (last_HADDR[3:0] == DIGIT3_ADDR) ? {24'h000_0000,DIGIT3} :
                  (last_HADDR[3:0] == DIGIT4_ADDR) ? {24'h000_0000,DIGIT4} :
                   32'h0000_0000;


  reg [31:0] counter;
  reg [3:0] ring = 4'b0001;

  wire [7:0] code;
  wire [6:0] seg_out;
  assign seg = ~seg_out;
  assign an = ~ring;

  always @(posedge HCLK or negedge HRESETn)
  begin
	if(!HRESETn)
		counter <= 32'h0000_0000;
	else
		counter <= counter + 1'b1;
  end

  always @(posedge counter[15] or negedge HRESETn)
  begin
	if(!HRESETn)
		ring <= 4'b0001;
	else
		ring <= {ring[2:0],ring[3]};
  end

  assign code =
	(ring == 4'b0001) ? DIGIT1[7:0] :
	(ring == 4'b0010) ? DIGIT2[7:0] :
	(ring == 4'b0100) ? DIGIT3[7:0] :
	(ring == 4'b1000) ? DIGIT4[7:0] :
		4'b1_1110;
		
	assign dp = ~code[7];

parameter A      = 7'b0000001;
parameter B      = 7'b0000010;
parameter C      = 7'b0000100;
parameter D      = 7'b0001000;
parameter E      = 7'b0010000;
parameter F      = 7'b0100000;
parameter G      = 7'b1000000;

assign seg_out =
    (code[6:0] == 7'h0) ? A|B|C|D|E|F :
    (code[6:0] == 7'h1) ? B|C :
    (code[6:0] == 7'h2) ? A|B|G|E|D :
    (code[6:0] == 7'h3) ? A|B|C|D|G :

    (code[6:0] == 7'h4) ? F|B|G|C :
    (code[6:0] == 7'h5) ? A|F|G|C|D : 
    (code[6:0] == 7'h6) ? A|F|G|C|D|E :
    (code[6:0] == 7'h7) ? A|B|C :

    (code[6:0] == 7'h8) ? A|B|C|D|E|F|G :
    (code[6:0] == 7'h9) ? A|B|C|D|F|G :
    (code[6:0] == 7'ha) ? A|F|B|G|E|C :
    (code[6:0] == 7'hb) ? F|G|C|D|E :

    (code[6:0] == 7'hc) ? G|E|D :
    (code[6:0] == 7'hd) ? B|C|G|E|D :
    (code[6:0] == 7'he) ? A|F|G|E|D :
    (code[6:0] == 7'hf) ? A|F|G|E :
    (code[6:0] == 7'hf) ? A|F|G|E :
    (code[6:0] == 7'h10) ? A|B|C|D|E|F|G :		
    (code[6:0] == 7'h11) ? G :				
    (code[6:0] == 7'h12) ? A :				
    (code[6:0] == 7'h13) ? D :				
        7'b000_0000;

endmodule
