---
title: Http的演进之路之六
tags:
  - http
categories:
  - 网络
  - http
abbrlink: cd15eee9
date: 2019-03-10 12:23:00
---
# Http的演进之路之六

## 声明，此系列文章转载自[lonnieZ http的演进之路](https://www.zhihu.com/people/lonniez/activities)

## **Http/2**

鉴于SPDY的成功，HTTP/2的开发计划也呼之欲出并且众望所归的采用了SPDY作为整个方案的蓝图进行开发。由[IETF](http://link.zhihu.com/?target=https%3A//www.ietf.org/)推动，Google等公司重点参与并于2015年3月公布了[草案](http://link.zhihu.com/?target=http%3A//http2.github.io/http2-spec/)。其最终RFC可以参考[这里](http://link.zhihu.com/?target=https%3A//tools.ietf.org/html/rfc7540)。

![upload successful](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-266.png)
<!-- more -->

## 与SPDY的差异

虽然HTTP/2大体上沿用了SPDY的设计理念。但仍然有部分差异，这主要集中体现在以下几点：

- HTTP/2可以在TCP之上直接使用，不像SPDY那样必须在TLS层之上
- 更加完善的协议商讨和确认流程
- 新的头部压缩算法[HPACK](http://link.zhihu.com/?target=https%3A//http2.github.io/http2-spec/compression.html)
- 添加了控制帧的种类，对帧的格式考虑更加细致
- 更加完善的Server Push流程

**不一样的层次结构**

![upload successful](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-267.png)

对于SPDY而言，在使用SPDY协议之前可以通过NPN（Next Protocol Negotiation）进行协议沟通来协商使用的具体协议（HTTP/1.X或SPDY），一旦决定使用SPDY则必须建立在TLS之上。

对于HTTP/2而言则没有这个限制，在使用HTTP/2之前也需要通过ALPN（Application Layer Protocol Negotiation)协商具体协议（HTTP/1.X或HTTP/2），当决定使用HTTP/2时可以建立在TLS之上，也可以直接建立在TCP之上。

**ALPN协商**

在HTTP/2中使用ALPN（Application Layer Protocol Negotiation）替代了SPDY中的NPN（Next Protocol Negotiation）来协商使用的具体协议。ALPN与NPN都是TLS扩展协议，他们发生在ClientHello和ServerHello阶段。他们用来client端与server端协商使用的协议，由于并不是所有server端或client端都支持SPDY或HTTP/2，因此在正式启用相关协议之前，客户端与服务端要进行协商。以下是ALPN的一个具体示例，首先看到的是ClientHello中向server端问询可以使用的协议：

![upload successful](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-268.png)

从图中我们可以看到，Client端向Server端问询了HTTP/2和HTTP/1.1可以使用哪个协议。下面是server端通过ServerHello来答复client端：

![upload successful](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-269.png)

从Server端的答复来看可以使用HTTP/2来进行通信。而下图是另一个server的答复，这个server目前只能支持HTTP/1.1：

![upload successful](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-270.png)

**HPACK压缩(见**[Http演进之路之六](https://zhuanlan.zhihu.com/p/51241802)**)**

**帧格式**

在HTTP/2中把帧分为数据帧与控制帧：

![img](https://pic4.zhimg.com/80/v2-a3e43a05198c4a0c4bcd9d17e36b5357_hd.jpg)

**SETTINGS帧**

```text
+-----------------------------------------------+
|                Length (24)                    |
+---------------+---------------+---------------+
|     0x4 (8)   | Flags (8) |
+-+-------------+---------------+-------------------------------+
|R|                Stream Identifier/0x0 (32)                   |
+=+=============================+===============================+
|       Identifier (16)         |
+-------------------------------+-------------------------------+
|                        Value (32)                             |
+---------------------------------------------------------------+
```

当连接建立成功后发送的第一个帧，用来传递配置参数。在连接周期内的任意时刻、任意一方都可以发送SETTINGS帧来调节相关参数。由于SETTINGS帧是针对整个连接的，而不是只对某一个单独的stream，因此其内部的Stream ID值为0。通过下面的抓包可以看到在该SETTINGS帧中会携带Header Table Size、Initial Window Size、Max Frame Size等参数。

![img](https://pic2.zhimg.com/80/v2-5bcd2ac6e14fa09d9fd0df8deda187a1_hd.jpg)

**PING帧**

```text
+-----------------------------------------------+
|                0x8 (24)                       |
+---------------+---------------+---------------+
|  0x6 (8)      | Flag (8) |
+-+-------------+---------------+-------------------------------+
|R|                          0x0 (32)                           |
+=+=============================================================+
|                        Opaque Data (64)                       |
+---------------------------------------------------------------+
```

用来进行心跳监测或计算两端直接的RTT。其中的Flag如果为0表示该帧为一个PING操作，接收方必须答复一个Flag为1的PONG帧。

![img](https://pic1.zhimg.com/80/v2-eaf91fee6df6956c66beec3ea2986690_hd.jpg)

**GOAWAY帧**

```text
+-+-------------------------------------------------------------+
|R|                  Last-Stream-ID (31)                        |
+-+-------------------------------------------------------------+
|                      Error Code (32)                          |
+---------------------------------------------------------------+
|                  Additional Debug Data (*)                    |
+---------------------------------------------------------------+
```

该帧用于触发连接的关闭流程，或者将严重的错误通知给对端。它允许端点停止接受新流同时继续完成之前建立的流的处理过程。

![img](https://pic2.zhimg.com/80/v2-6e26def694e4a85160a74b83452df571_hd.jpg)

**WINDOW_UPDATE帧**

```text
+-----------------------------------------------+
|                0x4 (24)                       |
+---------------+---------------+---------------+
|   0x8 (8)     |    0x0 (8)    |
+-+-------------+---------------+-------------------------------+
|R|                Stream Identifier (31)                       |
+=+=============================================================+
|R|              Window Size Increment (31)                     |
+-+-------------------------------------------------------------+
```

WINDOW_UPDATE帧用来实现流量控制，发送方发送WINDOW_UPDATE帧来告诉接收方自己此时可以发送的最大字节数以及接收者可以接收到的最大字节数。流量控制可以应用到单个流也可以应用到整个连接承载的所有流（此时流ID为0）。此外，发送者不能发送一个大于接收者已持有（接收端已经拥有一个流控值）可用空间大小的WINDOW_UPDATE帧且该帧仅会影响DATA帧。下图为一个对整个连接的流控消息：

![img](https://pic3.zhimg.com/80/v2-17c9db94825f9a3de2792046824ce5c6_hd.jpg)

下面是针对某个stream上的流控消息：

![img](https://pic1.zhimg.com/80/v2-6080c0f94db99d7e48bdbaddeb824810_hd.jpg)

**PRIORITY帧**

```text
+-----------------------------------------------+
|                   0x5 (24)                    |
+---------------+---------------+---------------+
|   0x2 (8)     |    0x0 (8)    |
+-+-------------+---------------+-------------------------------+
|R|                  Stream Identifier (31)                     |
+=+=============================================================+
|E|                  Stream Dependency (31)                     |
+-+-------------+-----------------------------------------------+
| Weight (8)    |
+---------------+
```

明确了发送者建议的流的优先级。该帧可以在任意流状态下发送，包括空闲状态和关闭状态。其中Weight（权重）为8bit的整数，用来标识流的优先级权重，范围是1-256之间；Dependency表示是否依赖于其他流（父亲流）。此外，优先级也可以通过HEADER帧进行传递。

![img](https://pic4.zhimg.com/80/v2-20c55ad291159b02248cbb13f6089b0b_hd.jpg)

**RST_STREAM帧**

```text
+-----------------------------------------------+
|                0x4 (24)                       |
+---------------+---------------+---------------+
|  0x3  (8)     |  0x0 (8)      |
+-+-------------+---------------+-------------------------------+
|R|                Stream Identifier (31)                       |
+=+=============================================================+
|                        Error Code (32)                        |
+---------------------------------------------------------------+
```

Reset帧，用来在发生错误的时候关闭流。在流上收到该帧后，除了PRIORITY帧，接收方不能再发送额外的帧，而发送方必须做好接收和处理该流上额外的帧，这些帧可能是对端在收到RST_STREAM之前发送出来的。此外，RST_STREAM帧必须与某一个流关联。

![img](https://pic4.zhimg.com/80/v2-936599d9b4fecfa9f92e37af1bc282cf_hd.jpg)

**HEADER帧**

```text
+-----------------------------------------------+
|                Length (24)                    |
+---------------+---------------+---------------+
|     0x1 (8)   | Flags (8) |
+-+-------------+---------------+-------------------------------+
|R|                Stream Identifier/0x0 (32)                   |
+=+=============================+===============================+
|Pad Length? (8)|
+-+-------------+-----------------------------------------------+
|E|                 Stream Dependency? (31)                     |
+-+-------------+-----------------------------------------------+
|  Weight? (8)  |
+-+-------------+-----------------------------------------------+
|                   Header Block Fragment (*)                 ...
+---------------------------------------------------------------+
|                           Padding (*)                       ...
+---------------------------------------------------------------+
```

HEADER帧用来打开一个流以及传递Headers信息。其中Pad Length（填充长度）表示填充字节（Padding）的长度。该字段为可选，只有设置了PADDED标记位时才有效。E占用1个bit，表示依赖流是否为排他的，只有设置了PRIORITY标志位时才有效。Stream Dependency为依赖流，即“父亲流”，仍然为设置了PRIORITY标志位时才有效。Weight为权重，为设置了PRIORITY标志位时才有效。Header Block Fragment包含了头域信息。

![img](https://pic3.zhimg.com/80/v2-32924f6be2803d81ade9e9ad270443b2_hd.jpg)

从这个HEADER中可以看出其Flag为0x24，即"End Headers"和“Priority”为True，由于“Priority”为True，因此后面的E、Stream Dependency、Weight都是有效的。由于“End Headers”为True，表明请求头/响应头信息传递结束，如果没有设置“End Headers”则后面必须跟一个CONTINUATION帧继续传递剩余的信息。当“End Stream”为True的时候，表明该HEADER帧为当前流上的最后一个数据。

![img](https://pic4.zhimg.com/80/v2-563ec3ce6cf1dd77d3101b581a30b977_hd.jpg)

从这个HEADER信息可以看出，当Flag里面没有设置PRIORITY的时候，则E、Stream Dependency、Priority都是无效的。

**DATA帧**

```text
+-----------------------------------------------+
|                Length (24)                    |
+---------------+---------------+---------------+
| 0x0 (8)       | Flag (8) |
+-+-------------+---------------+-------------------------------+
|R|                Stream Identifier (31)                       |
+=+=============+===============================================+
|Pad Length (8)|
+---------------+-----------------------------------------------+
|                            Data (*)                         ...
+---------------------------------------------------------------+
|                          Padding (*)                       ...
+---------------------------------------------------------------+
```

DATA帧用来传递与具体流相关联的任意的、可变长度的字节序列。DATA帧必须与一个具体的流相关联，即其Stream Identifier不能为0，此外，只有当流处于“打开”或“半关闭”状态时，才能发送DATA帧。

![img](https://pic4.zhimg.com/80/v2-2093379066c325f5406fe9599f270cff_hd.jpg)

上图是流45上的两个DATA帧，当“End Stream”为true时表示该帧是当前流上最后一个帧，从而导致流进入“半关闭”或“关闭”状态。当“Padded”为true时表示该帧中包含“Pad Length”和Padding

**完善的Server Push机制**
有些人对“Server Push”机制存在一定的误解，认为这种技术可以让服务端主动向浏览器“推送消息”，甚至将其与WebSocket进行对比。实际上“Server Push”机制只是省去了浏览器发送请求的过程。从上面在SPDY章节中介绍“Server Push”机制中就可以看出，只有当服务端认为某些资源存在一定的关联性，即用户申请了资源A，势必会继续申请资源B、资源C、资源D...的时候，服务端才会主动推送这些资源，以此来达到节省浏览器发送request请求的过程。
**PUSH_PROMISE帧**
当服务端想使用Server Push推送资源的时候，会先向客户端发送PUSH_PROMISE帧。

```text
+---------------+
|Pad Length? (8)|
+-+-------------+-----------------------------------------------+
|R|                  Promised Stream ID (31)                    |
+-+-----------------------------+-------------------------------+
|                   Header Block Fragment (*)                 ...
+---------------------------------------------------------------+
|                           Padding (*)                       ...
+---------------------------------------------------------------+
```

其中Promised Stream ID标识了它所关联的流，它的值不能为0.
为了进一步演示HTTP\2的PUSH功能，我们在本地搭建了一个ngnix的server使其具有push的功能。搭建的方法可以参考[这里](http://link.zhihu.com/?target=http%3A//www.ruanyifeng.com/blog/2018/03/http2_server_push.html)。可以看到，当我们把其中的png和css资源设置为push后，在通过chrome访问时，他们的状态会置为push状态。

![img](https://pic2.zhimg.com/80/v2-d99fe507f66cddaac493e29c94ef2db1_hd.jpg)

## 性能对比

为了验证HTTP/2的性能，我在本地使用Nginx（版本1.15.2）搭建了一个服务器，该服务器上的index页面分别包含了10个、30个、50个、100个ico图片，令server端分别工作在http、http2、http2-push模式并通过chrome浏览器对其进行访问。

下图是http访问100个ico图片的结果。从图中我们可以看到，浏览器与服务器之间建立了多条连接（确切的说是6条连接，上文有相关说明），我们还可以看出“灰色”部分（Stalled）占的时间比重较大，这部分代表等待发起请求的时间，由于http每个request是顺序进行请求，因此在同一个连接上我们可以看出请求等待时间显“瀑布状”，而实际每个资源的下载时间（“蓝色”部分）则占比很小，可以理解为：当发出了request，下载数据的速度很快。

![img](https://pic2.zhimg.com/80/v2-bb96eabbe962872b9d1123cedafdaaad_hd.jpg)

下图是http2访问100个ico图片的访问结果。从图中可以看出对于同一个域名，只有一条连接，所有资源的申请都是通过这一条连接完成的。此外，从时间上看“灰色”的占比很小，“绿色”（发出request后等待response的时间）和“蓝色”的占比则很大，这与之前http的情况截然相反。这是因为在http2中，所有请求被“打散”到不同的帧中进行申请的，因此等待request发送的时间（灰色部分）比较短。但所有请求和响应都“挤在”了一条“车道”上，因此等待response（绿色部分）以及下载最终资源（蓝色部分）的时间则比较长。

![img](https://pic3.zhimg.com/80/v2-cdfc92910411ea01c9bd4e49aae17e76_hd.jpg)

下图是http2-push访问100个ico图片的结果。从图中可以看出，它与http2的现象很类似，不同之处在于有些资源是主动push的，这在一定程度上减少了客户端发送请求的次数，缩短了访问资源的时间。

![img](https://pic2.zhimg.com/80/v2-081dcd0af24d09fdf4ff8c00223bd821_hd.jpg)

下面的数据是使用http、http2、http2-push分别访问10个、30个、50个、100个ico资源的时间。从图中可以看出：普通http的访问速度比http2和http2-push要快，http2-push开启后要比http2快一点。因此，对于域名比较单一的网站，http2的效果不一定好于http，即多个连接的效果要好于单个连接的情况。添加主动push功能比没有开启的效果要好一些。因此，我们在选用http2的时候也要与我们的实际业务场景相结合。

![img](https://pic3.zhimg.com/80/v2-3222a99b5a0846cde9e0369607798ece_hd.jpg)