/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2024-01-17 00:13:47
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-23 11:03:23
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: 全功能版FIFO, 支持同步/异步, 支持位宽变换, 支持almost full和almost empty
* 思路:
  1.
*/

`default_nettype none

module myFIFO
#(
  parameter [0 : 0] IS_ASYNC    = 0, // 1表示异步FIFO, 0(默认)表示同步FIFO
  parameter         DIN_WIDTH   = 8, // 输入数据位宽, 可取1, 2, 3, ... , 默认为8
  parameter         DOUT_WIDTH  = 8, // 输出数据位宽, 可取1, 2, 3, ... , 默认为8
  parameter         WADDR_WIDTH = 4, // 写入地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
  parameter RAM_STYLE = "distributed", // RAM类型, 可选"block", "distributed"(默认)
  parameter [0 : 0] FWFT_EN     = 1, // 首字直通特性使能, 默认为1, 表示使能首字直通
  parameter [0 : 0] MSB_FIFO    = 1  // 1(默认)表示高位先进先出,同Vivado FIFO一致; 0表示低位先进先出
)(
  input  wire [DIN_WIDTH-1:0] din,
  input  wire                 wr_en,
  output wire                 full,
  output wire                 almost_full,
  input  wire                 wr_clk,
  input  wire                 wr_rst,

  output wire [DOUT_WIDTH-1:0] dout,
  input  wire                  rd_en,
  output wire                  empty,
  output wire                  almost_empty,
  input  wire                  rd_clk,
  input  wire                  rd_rst
);


generate
if (IS_ASYNC == 1) begin
  asyncFIFO_diffWidth #(
    .DIN_WIDTH   (DIN_WIDTH  ),
    .DOUT_WIDTH  (DOUT_WIDTH ),
    .WADDR_WIDTH (WADDR_WIDTH),
    .RAM_STYLE   (RAM_STYLE  ),
    .FWFT_EN     (FWFT_EN    ),
    .MSB_FIFO    (MSB_FIFO   )
  ) asyncFIFO_diffWidth_u0 (
    .din          (din         ),
    .wr_en        (wr_en       ),
    .full         (full        ),
    .almost_full  (almost_full ),
    .wr_clk       (wr_clk      ),
    .wr_rst       (wr_rst      ),
    .dout         (dout        ),
    .rd_en        (rd_en       ),
    .empty        (empty       ),
    .almost_empty (almost_empty),
    .rd_clk       (rd_clk      ),
    .rd_rst       (rd_rst      )
  );
end
else begin
  syncFIFO_diffWidth #(
    .DIN_WIDTH   (DIN_WIDTH  ),
    .DOUT_WIDTH  (DOUT_WIDTH ),
    .WADDR_WIDTH (WADDR_WIDTH),
    .RAM_STYLE   (RAM_STYLE  ),
    .FWFT_EN     (FWFT_EN    ),
    .MSB_FIFO    (MSB_FIFO   )
  ) syncFIFO_diffWidth_u0 (
    .din          (din         ),
    .wr_en        (wr_en       ),
    .full         (full        ),
    .almost_full  (almost_full ),
    .dout         (dout        ),
    .rd_en        (rd_en       ),
    .empty        (empty       ),
    .almost_empty (almost_empty),
    .clk          (wr_clk      ),
    .rst          (wr_rst      )
  );
end
endgenerate


endmodule
`resetall