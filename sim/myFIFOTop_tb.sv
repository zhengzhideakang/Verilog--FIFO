/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2024-09-12 09:27:18
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-23 15:36:23
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: 仿真验证myFIFO的功能是否正确, 与Vivado FIFO IP进行对比
* 思路:
  1.通过参数选择同步FIFO和异步FIFO, 同时要更改Vivado FIFO IP的设置
  2.更改输入/输出数据位宽, 更改FIFO深度
*/

module myFIFO_tb();

timeunit 1ns;
timeprecision 10ps;


//++ 实例化myFIFO模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
parameter [0 : 0] IS_ASYNC    = 1; // 1表示异步FIFO, 0(默认)表示同步FIFO
parameter         DIN_WIDTH   = 8; // 输入数据位宽, 可取1, 2, 3, ... , 默认为8
parameter         DOUT_WIDTH  = 8; // 输出数据位宽, 可取1, 2, 3, ... , 默认为8
parameter         WADDR_WIDTH = 4; // 写入地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
parameter RAM_STYLE = "distributed"; // RAM类型, 可选"block", "distributed"(默认)
parameter [0 : 0] FWFT_EN     = 1; // 首字直通特性使能, 默认为1, 表示使能首字直通
parameter [0 : 0] MSB_FIFO    = 1; // 1(默认)表示高位先进先出,同Vivado FIFO一致; 0表示低位先进先出

logic [DIN_WIDTH-1:0] din;
logic                 wr_en;
logic                 full;
logic                 almost_full;
logic                 wr_clk;
logic                 wr_rst;

logic [DOUT_WIDTH-1:0] dout;
logic                  rd_en;
logic                  empty;
logic                  almost_empty;
logic                  rd_clk;
logic                  rd_rst;

myFIFO #(
  .IS_ASYNC    (IS_ASYNC   ),
  .DIN_WIDTH   (DIN_WIDTH  ),
  .DOUT_WIDTH  (DOUT_WIDTH ),
  .WADDR_WIDTH (WADDR_WIDTH),
  .RAM_STYLE   (RAM_STYLE  ),
  .FWFT_EN     (FWFT_EN    ),
  .MSB_FIFO    (MSB_FIFO   )
) myFIFO_u0 (.*);
//-- 实例化myFIFO模块 ------------------------------------------------------------


//++ 实例化Vivado FIFO IP ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
logic [DOUT_WIDTH-1:0] vivado_fifo_dout;
logic                  vivado_fifo_full;
logic                  vivado_fifo_empty;
logic                  vivado_fifo_almost_full;
logic                  vivado_fifo_almost_empty;

fifo_generator_0 fifo_generator_0_u0 (
  .wr_clk       (wr_clk                 ), // input wire wr_clk
  .wr_rst       (wr_rst                 ), // input wire wr_rst
  .rd_clk       (rd_clk                 ), // input wire rd_clk
  .rd_rst       (rd_rst                 ), // input wire rd_rst
  .din          (din                    ), // input wire [7 : 0] din
  .wr_en        (wr_en                  ), // input wire wr_en
  .rd_en        (rd_en                  ), // input wire rd_en
  .dout         (vivado_fifo_dout       ), // output wire [7: 0] dout
  .full         (vivado_fifo_full       ), // output wire full
  .almost_full  (vivado_fifo_almost_full), // output wire almost_full
  .empty        (vivado_fifo_empty      ), // output wire empty
  .almost_empty (vivado_fifo_almost_empty)  // output wire almost_empty
);
//-- 实例化Vivado FIFO IP ------------------------------------------------------------


//++ 生成时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam WR_CLKT = 2;
initial begin
  wr_clk = 0;
  forever #(WR_CLKT / 2) wr_clk = ~wr_clk;
end

localparam RD_CLKT = 4;
initial begin
  rd_clk = 0;
  #0.1;
  forever #(RD_CLKT / 2) rd_clk = ~rd_clk;
end
//-- 生成时钟 ------------------------------------------------------------


//++ 仿真逻辑主体 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
initial begin
  // 模块复位
  wr_en = 0;
  rd_en = 0;
  wr_rst = 1;
  rd_rst = 1;
  #(WR_CLKT * 10)
  wr_rst = 0;
  rd_rst = 0;

  #(WR_CLKT * 2)
  wait(~full && ~vivado_fifo_full); // 两个FIFO都从复位态恢复时开始写

  // 写入一个数据
  wr_en = 1;
  #(WR_CLKT) wr_en = 0;

  // 读出一个数据
  wait(~empty && ~vivado_fifo_empty);// 两个FIFO都非空时开始读，比较读数据和empty信号是否有差异
  rd_en = 1;
  #(RD_CLKT * 1) rd_en = 0;

  // 写满
  wr_en = 1;
  wait(full && vivado_fifo_full); // 两个FIFO都满时停止写，如果两者不同时满，则先满的一方会有写满的情况发生，但对功能无影响
  // vivado FIFO IP在FWFT模式时, 设定深度16时实际深度为17, 但仿真显示full会在写入15个数据后置高, 过几个时钟后后拉低,
  // 再写入一个数据, full又置高; 然后过几个时钟又拉低, 再写入一个数据置高, 如此才能写入17个数据
  // 所以这里多等待12个wclk周期, 就是为了能真正写满vivado FWFT FIFO
  wr_en = 0;

  // 读空
  wait(~empty && ~vivado_fifo_empty);
  rd_en = 1;
  wait(empty && vivado_fifo_empty); // 两个FIFO都空时停止读，如果两者不同时空，则先空的一方会有读空的情况发生，但对功能无影响
  rd_en = 0;

  #(WR_CLKT * 10)
  $stop;
end


always @(posedge wr_clk) begin
  if (wr_rst)
    din <= 0;
  else if (wr_en && ~full && ~vivado_fifo_full)
    din <= din + 1;
end
//-- 仿真逻辑主体 ------------------------------------------------------------


endmodule