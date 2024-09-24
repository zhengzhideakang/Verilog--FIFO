/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2024-09-14 11:40:11
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-23 11:10:10
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: myFIFO实例化参考
*/


//++ 实例化FIFO模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
myFIFO #(
  .IS_ASYNC    (0), // 1表示异步FIFO, 0(默认)表示同步FIFO
  .DIN_WIDTH   (8), // 输入数据位宽, 可取1, 2, 3, ... , 默认为8
  .DOUT_WIDTH  (8), // 输出数据位宽, 可取1, 2, 3, ... , 默认为8
  .WADDR_WIDTH (4), // 写入地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
  .RAM_STYLE   ("distributed"), // RAM类型, 可选"block", "distributed"(默认)
  .FWFT_EN     (1), // 首字直通特性使能, 默认为1, 表示使能首字直通
  .MSB_FIFO    (1) // 1(默认)表示高位先进先出,同Vivado FIFO一致; 0表示低位先进先出
) myFIFO_u0 (
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
  .rd_rst       (rd_rst)
);
//-- 实例化FIFO模块 ------------------------------------------------------------