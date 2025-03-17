/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2023-10-09 09:43:46
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-23 10:35:24
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: 同步FIFO, 支持输入输出数据不同位宽
* 思路:
1. 根据读写数据位宽的关系，分两种情况，当读位宽>写位宽时组合数据；当读位宽<写位宽时分解数据
? 注意：
1. 同步FIFO不存在“假满”和“假空”问题
2. FIFO实际容量总是比设定容量大，差值为两个小位宽（读/写）数据，不影响功能
3. 复位均为高电平复位，与Vivado中的FIFO IP核保持一致
4. 复位为异步复位，写复位和读复位可以共用一个信号，也可以分开
5. DIN_WIDTH与DOUT_WIDTH的倍数关系必须是2的n次方，如2倍、4倍、8倍，不能是3倍、6倍
6. FIFO深度通过WADDR_WIDTH来设置，所以FIFO的深度必然是2的指数，如8、16、32等
7. WADDR_WIDTH必须≥2，且RADDR_WIDTH =  WADDR_WIDTH + log2(DIN_WIDTH / DOUT_WIDTH)也必须≥2
    一种极限情况，DIN_WIDTH = 4，DOUT_WIDTH=16，WADDR_WIDTH=4，RADDR_WIDTH =5+log2(4/16)=2
8. MSB_FIFO用于设定高位/低位先进先出，它和一般讲的FIFO大端和小端模式不是一个概念
*/

`default_nettype none

module syncFIFO_diffWidth
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

  output wire [DOUT_WIDTH-1:0] dout,
  input  wire                  rd_en,
  output wire                  empty,
  output wire                  almost_empty,

  input  wire                  clk,
  input  wire                  rst
);


//++ 写与读位宽转换 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire [DIN_WIDTH-1:0] wdata;
wire wdata_rd_en;
wire wdata_empty;

wire [DOUT_WIDTH-1:0] rdata;
wire rdata_wr_en;
wire rdata_full;

generate
  //~ 如果读位宽大于写位宽，则需要组合数据，组合成一个数据就写入到读取侧FIFO中
  if (DOUT_WIDTH > DIN_WIDTH) begin
    wire wdata_almost_full;
    syncFIFO # (
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
    syncFIFO # (
      .DATA_WIDTH (DOUT_WIDTH ),
      .ADDR_WIDTH (RADDR_WIDTH),
      .RAM_STYLE  (RAM_STYLE  ),
      .FWFT_EN    (FWFT_EN    )
    ) syncFIFO_u1 (
      .din          (rdata       ),
      .wr_en        (rdata_wr_en ),
      .full         (rdata_full  ),
      .almost_full  (            ),
      .dout         (dout        ),
      .rd_en        (rd_en       ),
      .empty        (empty       ),
      .almost_empty (almost_empty),
      .clk          (clk         ),
      .rst          (rst         )
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

  //~ 如果读位宽等于写位宽，那么就是普通的同步FIFO
  else if (DOUT_WIDTH == DIN_WIDTH) begin
    syncFIFO # (
      .DATA_WIDTH (DIN_WIDTH  ),
      .ADDR_WIDTH (WADDR_WIDTH),
      .RAM_STYLE  (RAM_STYLE  ),
      .FWFT_EN    (FWFT_EN    )
    ) syncFIFO_u0 (
      .din          (din         ),
      .wr_en        (wr_en       ),
      .full         (full        ),
      .almost_full  (almost_full ),
      .dout         (dout        ),
      .rd_en        (rd_en       ),
      .empty        (empty       ),
      .almost_empty (almost_empty),
      .clk          (clk         ),
      .rst          (rst         )
    );
  end

  //~ 如果读位宽小于写位宽，则需要分解数据，写入的数据分解成几个数据写入到读取侧FIFO中
  else begin
    syncFIFO # (
      .DATA_WIDTH (DIN_WIDTH  ),
      .ADDR_WIDTH (WADDR_WIDTH),
      .RAM_STYLE  (RAM_STYLE  ),
      .FWFT_EN    (1          )
    ) syncFIFO_u0 (
      .din          (din        ),
      .wr_en        (wr_en      ),
      .full         (full       ),
      .almost_full  (almost_full),
      .dout         (wdata      ),
      .rd_en        (wdata_rd_en),
      .empty        (wdata_empty),
      .almost_empty (           ),
      .clk          (clk        ),
      .rst          (rst        )
    );


    wire rdata_almost_empty;
    syncFIFO # (
      .DATA_WIDTH (DOUT_WIDTH),
      .ADDR_WIDTH (1         ),
      .RAM_STYLE  (RAM_STYLE ),
      .FWFT_EN    (FWFT_EN   )
    ) syncFIFO_u1 (
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