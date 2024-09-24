# Verilog---FIFO

Gitee与Github同步：

[Verilog功能模块--FIFO: 包含同步FIFO，异步FIFO，不同位宽转换 (gitee.com)](https://gitee.com/xuxiaokang/verilog-function-module---fifo)

[zhengzhideakang/Verilog--FIFO: 包含同步FIFO，异步FIFO，不同位宽转换 (github.com)](https://github.com/zhengzhideakang/Verilog--FIFO)

## 简介

### FIFO的功能

FIFO在FPGA中应用很多，它主要有以下功能：

1. 数据缓存，很多时候数据发送速度和数据接收速度并不实时匹配，而在其中插入一个FIFO，来临时存储数据，就能平衡发送和接收速度
2. 组合与分解数据，FIFO的写入数据位宽和读出数据位宽可以不一致，例如可以16bit写入，8bit读出或者反过来，这就为组合与分解数据提供了方便
3. 跨时钟域传输数据，这是异步FIFO才有的功能，异步FIFO的读写时钟可以完全独立，所以可以借助异步FIFO来实现跨时钟域传输数据
4. 标准化接口，因为FIFO的写入与读出接口的控制时序非常简单，所以在模块需要外部数据时可以定义一个FIFO接口，这样数据接口的时序就不言自明了

本模块包含同步FIFO，异步FIFO，不同位宽转换。

### 为什么需要自编FIFO

我很喜欢在自编模块中使用FIFO接口，这样在使用此模块时就不必担心数据输入的时序问题，直接从FIFO中读数据即可。但这也带来了一些问题，如：

1. 实例化模块时还需要额外实例化FIFO IP核，总是不那么方便，降低了自编模块的通用性，这是最大的问题
2. 通常我只是需要FIFO这种接口，对于存储深度基本没要求，16的深度已经足够，但一些国产FPGA开发软件中的FIFO IP核最小深度就是512，这无疑造成了存储空间的浪费
3. 我总是使用FWFT类型的FIFO，所以在实例化FIFO IP核时还必须选择FWFT类型，这容易出错，也造成了自编模块使用的不方便；而且一些国产开发软件还不提供FWFT类型的FIFO，这使得还得额外加一个标准FIFO转FWFT FIFO的模块，这就更不方便了

综上，我觉得有必要使用纯Verilog来实现FWFT FIFO，这样就不需要额外的FIFO IP核了，模块通用性大大提升。

### FIFO总结

之前的几篇关于FIFO的文章已经实现了同步FIFO，异步FIFO，位宽不同的同步FIFO，位宽不同的异步FIFO，但使用时还要区分不同的文件，不甚便利。

这里重新编写了一个myFIFO.v文件，将所有这些FIFO都整合进来，通过Parameter参数进行选择调用，最终效果就是你总是只需要调用这一个文件即可。

## 模块框图

<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/myFIFO.svg" alt="myFIFO" />

## 更多参考

[Verilog功能模块——FIFO（总结） – 徐晓康的博客 (myhardware.top)](https://www.myhardware.top/verilog功能模块-fifo（总结）/)
