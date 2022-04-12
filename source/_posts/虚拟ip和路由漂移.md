---
title: 虚拟IP和路由漂移
date: 2022-04-07 14:55:45
updated: 2022-04-07 14:55:45
tags:
    - 虚拟ip
    - 高可用
categories:
    - 网络
---

最近在研究网络相关内容，看到虚拟IP相关的内容，之前对这块有一些了解，但都是比较片面的认知，于是花了几天的时间，整理了相关的内容，本篇文章也是对自己整理内容的总结。

## 什么是虚拟ip

 按照维基百科上面的介绍，虚拟IP（Vrtual IP Address，vip）是一种不与特定计算机或者特定计算机网卡相对应的IP地址。所有发往这个IP地址的数据包最后都会经过真实的网卡到达目的主机的目的进程。主要是用来网络地址转换，网络容错和可移动性。

这种定义确实准确的定义了什么是虚拟IP，不过看完之后还是摸不着头脑。下面通过一个例子来介绍VIP。
<!-- more -->
虚拟IP比较常见的一个用例就是在系统高可用性（High Availability HA）方面的应用，通常一个系统会因为日常维护或者非计划外的情况而发生宕机，为了提高系统对外服务的高可用性，就会采用主备模式进行高可用性的配置。当提供服务的主机M宕机后，服务会切换到备用主机S继续对外提供服务。而这一切用户是感觉不到的，在这种情况下系统对客户端提供服务的IP地址就会是一个虚拟IP，当主机M宕机后，虚拟IP便会漂浮到备机上，继续提供服务。在这种情况下，虚拟IP就不是与特定计算主机或者特定某个物理网卡对应的了，而是一种虚拟或者是说逻辑的概念，它是可以自由移动自由漂浮的，这样一来既对外屏蔽了系统内部的细节，又为系统内部的可维护性和扩展性提供了方便。

## VIP漂移

在主机与主机之间通信的时候，会将IP地址翻译成MAC地址，然后主机之间通过这个mac地址相互通信，也就是ARP协议做的事情，如果不清楚什么是ARP协议，参考这篇文章[ARP，这个隐匿在计网背后的男人](https://mp.weixin.qq.com/s?__biz=MzI0ODk2NDIyMQ==&mid=2247487804&idx=1&sn=f001a24a308053b3723dfb12d36045ee&chksm=e999e42edeee6d383fbb411792e22e4028bb8c2441255786f50cf848443af7b1bd5e382078dc&scene=21#wechat_redirect)。

为了提高通信的效率，操作系统会对IP地址和MAC地址之间的映射进行缓存。但是这和VIP漂移有什么关系呢。可以试想下这种场景，当VIP在主机A上时，主机A的MAC地址为MAC_A，某主机M的arp缓存中存放着一个映射关系：VIP-a MAC_A；当主机A宕机后，VIP漂浮到了主机B，主机B的MAC地址为MAC_B，那么此时主机M想与VIP_a通信时，是做不到，因为它的arp高速缓存中的VIP映射还指向主机A的MAC地址。

说了这么多，和VIP漂移有什么关系呢，当VIP进行漂移时，其它主机记录还是之前vip绑定的MAC地址，因此需要刷新其他主机的arp缓存，才能够正确的通信。要解决这个问题，需要引入一个新的概念garp，简称无端arp或者免费arp。主要是用来当某一个主机C开机时，用来确认自己的IP地址没有被人占用而做的一个检测。广播发送这个arp，请求得到本机IP地址的MAC地址，主机C并不希望此次arp请求会有arp应答，因为应答意味着IP地址冲突了。当其他主机收到这个arp请求后，会刷新关于这个arp请求源的主机IP地址的映射。

Garp的作用主要有两个:

1. 检测IP地址是否有冲突
2. 刷新其他主机关于本次IP地址的映射关系

当VIP漂移到新的主机上时，可以通过主动触发Garp，来刷新其它机器上相关的映射。

这里解决了VIP和MAC地址的缓存问题，但是什么时机进行漂移，有谁来触发漂移还没有解决。这就会引出VRRP协议。

## VRRP

VRRP是Virtual Router Redundancy Protocol的简称，即虚拟路由冗余协议，协议的具体内容可以参考[虚拟路由冗余协议(VRRP)](https://blog.csdn.net/qq_38265137/article/details/80404440)。这个协议的主要作用通过健康检查决定VIP什么时机进行漂移以及通过ARP协议向外通告VIP对应的MAC地址发生了变化。通过它可以实现VIP的自动漂移。

这里简单介绍下VRRP完整的工作过程

1. 两台机器互相进行健康检查；
2. 主机器对外响应虚拟地址的ARP请求，通告其MAC地址；
3. 虚拟地址网络流量被机器由处理；
4. 备用机器发现主机器故障，开始响应虚拟地址的ARP请求，通告其MAC地址；
5. 虚拟地址网络流量被备用机器处理；
6. 主机器恢复，重新响应ARP请求，夺回流量；
7. 备用机器发现主机器恢复，停止响应ARP请求，释放流量处理权；

常用的HA软件[Keepalived](http://www.keepalived.org/)实现了此协议，可以实现机器的故障隔离及负载均衡器间的失败切换，提高系统的可用性。

## 实践

上面也只是简单的总结了一些内容，要想整正的理解这些，还是需要上手做一些实验。我是按照[使用Docker-compose搭建nginx-keepalived双机热备来实现nginx集群](https://zhuanlan.zhihu.com/p/133085218)这篇文章搭建了基本的实验环境，然后按照[nginx高可用方案](https://www.yuque.com/docs/share/b6db6dd9-e737-4ade-a7dd-335fc84ac458?#SGleK)这篇文章实践了主从模式，双主模式，最后一种DNS轮训还没想好怎么在本地实验。

## 参考

1. [ARP，这个隐匿在计网背后的男人](https://mp.weixin.qq.com/s?__biz=MzI0ODk2NDIyMQ==&mid=2247487804&idx=1&sn=f001a24a308053b3723dfb12d36045ee&chksm=e999e42edeee6d383fbb411792e22e4028bb8c2441255786f50cf848443af7b1bd5e382078dc&scene=21#wechat_redirect)
2. [虚拟IP与arp协议](https://blog.csdn.net/u014532901/article/details/52245138)
3. [VRRP虚IP漂移](https://network.fasionchan.com/zh_CN/latest/distributed/vrrp-vip-floating.html)
4. [HAProxy用法详解 全网最详细中文文档](http://www.ttlsa.com/linux/haproxy-study-tutorial/)
5. [Keepalived 原理介绍和配置实践](https://wsgzao.github.io/post/keepalived/)
