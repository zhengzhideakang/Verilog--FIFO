/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2023-10-09 09:43:46
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-23 10:55:29
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: 异步FIFO, 支持输入输出数据不同位宽
* 思路:
1. 根据读写数据位宽的关系，分三种情况，当读位宽>写位宽时组合数据；当读位宽<写位宽时分解数据
2. 同步FIFO作为缓冲，深度固定为2，异步FIFO作为主体，深度为设定深度
3. 当读位宽>写位宽时，读端口逻辑无需关心，同步FIFO时钟与异步FIFO写时钟为同一时钟，只要同步FIFO中有数据就立刻读出，
    组合之后写入异步FIFO，所以写端口的full信号只会在异步FIFO满之后再写入两个数据才置高，
    此时不必担心同步FIFO因为深度为2会很快写满
4. 当读位宽==写位宽时，这就是普通异步FIFO，直接实例化一个异步FIFO即可
5. 当读位宽<写位宽时，写端口逻辑无需关心，同步FIFO时钟域异步FIFO读时钟为同一时钟，
    只要异步FIFO中有数据就分解之后写入到同步FIFO，所以读端口的empty信号只会在异步FIFO空之后置高，
    此时不必担心同步FIFO因为深度为2会很快读空
? 注意：
1. 因为模块主体仍是异步FIFO，所以异步FIFO的“假满”和“假空”问题仍然存在，不影响功能
2. FIFO实际容量总是比设定容量大，差值为两个小位宽（读/写）数据，不影响功能
3. 复位均为高电平复位，与Vivado中的FIFO IP核保持一致
4. 复位为异步复位，写复位和读复位可以公用一个信号，也可以分开
5. DIN_WIDTH与DOUT_WIDTH的倍数关系必须是2的n次方，如2倍、4倍、8倍，不能是3倍、6倍
6. FIFO深度通过WADDR_WIDTH来设置，所以FIFO的深度必然是2的指数，如8、16、32等
7. WADDR_WIDTH必须≥3，且RADDR_WIDTH =  WADDR_WIDTH + log2(DIN_WIDTH / DOUT_WIDTH)也必须≥3
    一种极限情况，DIN_WIDTH = 4，DOUT_WIDTH=16，WADDR_WIDTH=5，RADDR_WIDTH =5+log2(4/16)=3
8. MSB_FIFO用于设定高位/低位先进先出，它和一般讲的FIFO大端和小端模式不是一个概念
*/

`default_nettype none

module asyncFIFO_diffWidth
#(
  parameter DIN_WIDTH = 8, // 输入数据位宽, 可取1, 2, 3, ... , 默认为8
  parameter DOUT_WIDTH = 8, // 输出数据位宽, 可取1, 2, 3, ... , 默认为8
  parameter WADDR_WIDTH = 4, // 写入地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
  parameter RAM_STYLE = "distributed", // RAM类型, 可选"block", "distributed"(默认)
  parameter [0:0] FWFT_EN = 1, // 首字直通特性使能, 默认为1, 表示使能首字直通
  parameter [0:0] MSB_FIFO = 1 // 1(默认)表示高位先进先出,同Vivado FIFO一致; 0表示低位先进先出
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


//++ 写与读位宽转换 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
generate
if (DOUT_WIDTH == DIN_WIDTH) begin //~ 如果读位宽等于写位宽，那么这就是普通的异步FIFO
  asyncFIFO # (
    .DATA_WIDTH (DIN_WIDTH  ),
    .ADDR_WIDTH (WADDR_WIDTH),
    .RAM_STYLE  (RAM_STYLE  ),
    .FWFT_EN    (FWFT_EN    )
  ) asyncFIFO_u0 (
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
else if (DOUT_WIDTH > DIN_WIDTH) begin //~ 如果读位宽大于写位宽，则需要组合数据，组合成一个数据就写入到读取侧FIFO中
  wire [DIN_WIDTH-1:0] wdata;
  wire wdata_rd_en;
  wire wdata_empty;
  wire [DOUT_WIDTH-1:0] rdata;
  wire rdata_wr_en;
  wire rdata_full;
  wire clk = wr_clk;
  wire rst = wr_rst;
  wire wdata_almost_full;
  syncFIFO #(
    .DATA_WIDTH (DIN_WIDTH),
    .ADDR_WIDTH (1        ),
    .RAM_STYLE  (RAM_STYLE),
    .FWFT_EN    (1        )
  ) syncFIFO_u0 (
    .din          (din        ),
    .wr_en        (wr_en      ),
    .full         (full       ),
    .almost_full  (wdata_almost_full),
    .dout         (wdata      ),
    .rd_en        (wdata_rd_en),
    .empty        (wdata_empty),
    .almost_empty (           ),
    .clk          (clk        ),
    .rst          (rst        )
  );

  assign almost_full = (wdata_almost_full && rdata_full) || full;

  localparam RADDR_WIDTH = $clog2(2**WADDR_WIDTH * DIN_WIDTH / DOUT_WIDTH);
  asyncFIFO #(
    .DATA_WIDTH (DOUT_WIDTH ),
    .ADDR_WIDTH (RADDR_WIDTH),
    .RAM_STYLE  (RAM_STYLE  ),
    .FWFT_EN    (FWFT_EN    )
  ) asyncFIFO_u0 (
    .din          (rdata       ),
    .wr_en        (rdata_wr_en ),
    .full         (rdata_full  ),
    .almost_full  (            ),
    .wr_clk       (clk         ),
    .wr_rst       (rst         ),
    .dout         (dout        ),
    .rd_en        (rd_en       ),
    .empty        (empty       ),
    .almost_empty (almost_empty),
    .rd_clk       (rd_clk      ),
    .rd_rst       (rd_rst      )
  );

  // 在读取侧FIFO未满，而写入侧FIFO非空时去读取写入侧FIFO
  assign wdata_rd_en = ~rdata_full && ~wdata_empty;

  reg [DOUT_WIDTH-1:0] rdata_r;
  if (MSB_FIFO == 1) begin
    always @(posedge clk or posedge rst) begin
      if (rst)
        rdata_r <= 'd0;
      else if (wdata_rd_en)
        rdata_r <= {rdata_r[DOUT_WIDTH-DIN_WIDTH-1:0], wdata}; // 先进的为高位
      else
        rdata_r <= rdata_r;
    end

    assign rdata = {rdata_r[DOUT_WIDTH-DIN_WIDTH-1:0], wdata}; // 先进的为高位
  end
  else begin
    always @(posedge clk or posedge rst) begin
      if (rst)
        rdata_r <= 'd0;
      else if (wdata_rd_en)
        rdata_r <= {wdata, rdata_r[DOUT_WIDTH-1 : DIN_WIDTH]}; // 先进的为低位
      else
        rdata_r <= rdata_r;
    end

    assign rdata = {wdata, rdata_r[DOUT_WIDTH-1 : DIN_WIDTH]}; // 先进的为低位
  end

  localparam WDATA_RD_EN_CNT_MAX = DOUT_WIDTH / DIN_WIDTH - 1;
  reg [$clog2(WDATA_RD_EN_CNT_MAX+1)-1 : 0] wdata_rd_en_cnt;
  always @(posedge clk or posedge rst) begin
    if (rst)
      wdata_rd_en_cnt <= 'd0;
    else if (wdata_rd_en)
      wdata_rd_en_cnt <= wdata_rd_en_cnt + 1'b1;
    else
      wdata_rd_en_cnt <= wdata_rd_en_cnt;
  end

  assign rdata_wr_en = wdata_rd_en && wdata_rd_en_cnt == WDATA_RD_EN_CNT_MAX;
end
else begin //~ 如果读位宽小于写位宽，则需要分解数据，写入的数据分解成几个数据写入到读取侧FIFO中
  wire [DIN_WIDTH-1:0] wdata;
  wire wdata_rd_en;
  wire wdata_empty;
  wire [DOUT_WIDTH-1:0] rdata;
  wire rdata_wr_en;
  wire rdata_full;
  wire clk = rd_clk;
  wire rst = rd_rst;
  asyncFIFO #(
    .DATA_WIDTH (DIN_WIDTH  ),
    .ADDR_WIDTH (WADDR_WIDTH),
    .RAM_STYLE  (RAM_STYLE  ),
    .FWFT_EN    (1          )
  ) asyncFIFO_u0 (
    .din          (din        ),
    .wr_en        (wr_en      ),
    .full         (full       ),
    .almost_full  (almost_full),
    .wr_clk       (wr_clk     ),
    .wr_rst       (wr_rst     ),
    .dout         (wdata      ),
    .rd_en        (wdata_rd_en),
    .empty        (wdata_empty),
    .almost_empty (           ),
    .rd_clk       (clk        ),
    .rd_rst       (rst        )
  );

  wire rdata_almost_empty;
  syncFIFO #(
    .DATA_WIDTH (DOUT_WIDTH),
    .ADDR_WIDTH (1         ),
    .RAM_STYLE  (RAM_STYLE ),
    .FWFT_EN    (FWFT_EN   )
  ) syncFIFO_u0 (
    .din          (rdata             ),
    .wr_en        (rdata_wr_en       ),
    .full         (rdata_full        ),
    .almost_full  (                  ),
    .dout         (dout              ),
    .rd_en        (rd_en             ),
    .empty        (empty             ),
    .almost_empty (rdata_almost_empty),
    .clk          (clk               ),
    .rst          (rst               )
  );
  assign almost_empty = (wdata_empty && rdata_almost_empty) || empty;

  // 先写入写数据的高位，再写入低位，当写入到最低位时，读取写入侧FIFO
  localparam RDATA_WR_EN_CNT_MAX = DIN_WIDTH/ DOUT_WIDTH - 1;
  reg [$clog2(RDATA_WR_EN_CNT_MAX+1)-1 : 0] rdata_wr_en_cnt;
  always @(posedge clk or posedge rst) begin
    if (rst)
      rdata_wr_en_cnt <= 'd0;
    else if (rdata_wr_en)
      rdata_wr_en_cnt <= rdata_wr_en_cnt + 1'b1;
    else
      rdata_wr_en_cnt <= rdata_wr_en_cnt;
  end

  if (MSB_FIFO == 1) begin
    wire [DIN_WIDTH-1:0] wdata_r = wdata << (rdata_wr_en_cnt * DOUT_WIDTH);
    assign rdata = wdata_r[DIN_WIDTH-1 : DIN_WIDTH-DOUT_WIDTH];
  end
  else begin
    wire [DIN_WIDTH-1:0] wdata_r = wdata >> (rdata_wr_en_cnt * DOUT_WIDTH);
    assign rdata = wdata_r[DOUT_WIDTH-1 : 0];
  end

  // 在读取侧FIFO非满，而写入侧FIFO非空时去写入读取侧FIFO
  assign rdata_wr_en = ~rdata_full && ~wdata_empty;
  assign wdata_rd_en = rdata_wr_en && rdata_wr_en_cnt == RDATA_WR_EN_CNT_MAX;
end
endgenerate
//-- 写与读位宽转换 ------------------------------------------------------------


endmodule
`resetall