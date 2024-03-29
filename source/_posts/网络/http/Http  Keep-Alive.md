---
title: HTTP Keep-Alive
tags:
  - http
categories:
  - 网络
  - http
abbrlink: 37f5aa4d
date: 2019-03-10 22:46:00
---
# HTTP Keep-Alive是什么？如何工作？

在http早期，每个http请求都要求打开一个tpc socket连接，并且使用一次之后就断开这个tcp连接。使用keep-alive可以改善这种状态，即在一次TCP连接中可以持续发送多份数据而不会断开连接。通过使用keep-alive机制，可以减少tcp连接建立次数，也意味着可以减少TIME_WAIT状态连接，以此提高性能和提高http服务器的吞吐率(更少的tcp连接意味着更少的系统内核调用,socket的accept()和close()调用)。

但是，[keep-alive](http://www.nowamagic.net/academy/tag/keep-alive)并不是免费的午餐,长时间的tcp连接容易导致系统资源无效占用。配置不当的keep-alive，有时比重复利用连接带来的损失还更大。所以，正确地设置keep-alive timeout时间非常重要。
<!-- more -->

#### keepalvie timeout

Httpd守护进程，一般都提供了keep-alive timeout时间设置参数。比如nginx的keepalive_timeout，和Apache的KeepAliveTimeout。这个keepalive_timout时间值意味着：一个http产生的tcp连接在传送完最后一个响应后，还需要hold住keepalive_timeout秒后，才开始关闭这个连接。

当httpd守护进程发送完一个响应后，理应马上主动关闭相应的tcp连接，设置 keepalive_timeout后，httpd守护进程会想说：”再等等吧，看看浏览器还有没有请求过来”，这一等，便是keepalive_timeout时间。如果守护进程在这个等待的时间里，一直没有收到浏览发过来http请求，则关闭这个http连接。

下面写一个脚本，方便测试：

```
sleep(60);	//为了便于分析测试，会根据测试进行调整
echo "www.example.com";
```

```
#tcpdump -n host 218.1.57.236 and port 80
20:36:50.792731 IP 218.1.57.236.43052 > 222.73.211.215.http: S 1520902589:1520902589(0) win 65535
20:36:50.792798 IP 222.73.211.215.http > 218.1.57.236.43052: S 290378256:290378256(0) ack 1520902590 win 5840
20:36:50.801629 IP 218.1.57.236.43052 > 222.73.211.215.http: . ack 1 win 32768

20:36:50.801838 IP 218.1.57.236.43052 > 222.73.211.215.http: P 1:797(796) ack 1 win 32768
20:36:50.801843 IP 222.73.211.215.http > 218.1.57.236.43052: . ack 797 win 59

20:37:50.803230 IP 222.73.211.215.http > 218.1.57.236.43052: P 1:287(286) ack 797 win 59
20:37:50.803289 IP 222.73.211.215.http > 218.1.57.236.43052: F 287:287(0) ack 797 win 59
20:37:50.893396 IP 218.1.57.236.43052 > 222.73.211.215.http: . ack 288 win 32625
20:37:50.894249 IP 218.1.57.236.43052 > 222.73.211.215.http: F 797:797(0) ack 288 win 32625
20:37:50.894252 IP 222.73.211.215.http > 218.1.57.236.43052: . ack 798 win 59
```

- 第1~3行建立tcp三次握手，建立连接。用时8898μs
- 第4~5行通过建立的连接发送第一个http请求，服务端确认收到请求。用时5μs
- 第5~6行，可以知道脚本执行用时60s1387μs,与php脚本相符。
- 第6、8行服务端发送http响应。发送响应用时90166μs。
- 第7行，表明由服务端守护进程主动关闭连接。结合第6、8行，说明http响应一旦发送完毕，服务端马上关闭这个tcp连接
- 第7、9、10说明tcp连接顺序关闭,用时90963μs。需要注意,这里socket资源并没有立即释放，需要等待2MSL时间（60s）后才被真正释放。

由此可见，在没有设置 keepalive_timeout 情况下，一个socket资源从建立到真正释放需要经过的时间是:建立tcp连接 + 传送http请求 + php脚本执行 + 传送http响应 + 关闭tcp连接 + 2MSL 。(注:这里的时间只能做参考，具体的时间主要由网络带宽，和响应大小而定)

2. keepalive_timeout时间大于0时，即启用Keep-Alive时，一个tcp连接的生命周期。为了便于分析，我们将keepalive_timeout设置为300s

   ```
   #tcpdump -n host 218.1.57.236 and port 80
   21:38:05.471129 IP 218.1.57.236.54049 > 222.73.211.215.http: S 1669618600:1669618600(0) win 65535
   21:38:05.471140 IP 222.73.211.215.http > 218.1.57.236.54049: S 4166993862:4166993862(0) ack 1669618601 win 5840
   21:38:05.481731 IP 218.1.57.236.54049 > 222.73.211.215.http: . ack 1 win 32768
   21:38:05.481976 IP 218.1.57.236.54049 > 222.73.211.215.http: P 1:797(796) ack 1 win 32768
   21:38:05.481985 IP 222.73.211.215.http > 218.1.57.236.54049: . ack 797 win 59
   
   21:38:07.483626 IP 222.73.211.215.http > 218.1.57.236.54049: P 1:326(325) ack 797 win 59
   21:38:07.747614 IP 218.1.57.236.54049 > 222.73.211.215.http: . ack 326 win 32605
   21:43:07.448454 IP 222.73.211.215.http > 218.1.57.236.54049: F 326:326(0) ack 797 win 59
   21:43:07.560316 IP 218.1.57.236.54049 > 222.73.211.215.http: . ack 327 win 32605
   21:43:11.759102 IP 218.1.57.236.54049 > 222.73.211.215.http: F 797:797(0) ack 327 win 32605
   21:43:11.759111 IP 222.73.211.215.http > 218.1.57.236.54049: . ack 798 win 59
   ```

- 我们先看一下，第6~8行，跟上次示例不一样的是，服务端httpd守护进程发完响应后，没有立即主动关闭tcp连接。
- 第8行，结合第6行，我们可以看到，5分钟(300s)后，服务端主动关闭这个tcp连接。这个时间，正是我们设置的keepalive_timeout的时间。
- 由此可见，设置了keepalive_timout时间情况下，一个socket建立到释放需要的时间是多了keepalive_timeout时间。

3. 当keepalive_timeout时间大于0，并且在同一个tcp连接发送多个http响应。这里为了便于分析，我们将keepalive_timeout设置为180s

   通过这个测试，我们想弄清楚,keepalive_timeout是从第一个响应结束开启计时，还是最后一个响应结束开启计时。测试结果证实是后者，这里，我们每隔120s发一次请求，通过一个tcp连接发送了3个请求。

   ```
   # tcpdump -n host 218.1.57.236 and port 80
   22:43:57.102448 IP 218.1.57.236.49955 > 222.73.211.215.http: S 4009392741:4009392741(0) win 65535
   22:43:57.102527 IP 222.73.211.215.http > 218.1.57.236.49955: S 4036426778:4036426778(0) ack 4009392742 win 5840
   22:43:57.111337 IP 218.1.57.236.49955 > 222.73.211.215.http: . ack 1 win 32768
   
   22:43:57.111522 IP 218.1.57.236.49955 > 222.73.211.215.http: P 1:797(796) ack 1 win 32768
   22:43:57.111530 IP 222.73.211.215.http > 218.1.57.236.49955: . ack 797 win 59
   22:43:59.114663 IP 222.73.211.215.http > 218.1.57.236.49955: P 1:326(325) ack 797 win 59
   22:43:59.350143 IP 218.1.57.236.49955 > 222.73.211.215.http: . ack 326 win 32605
   
   22:45:59.226102 IP 218.1.57.236.49955 > 222.73.211.215.http: P 1593:2389(796) ack 650 win 32443
   22:45:59.226109 IP 222.73.211.215.http > 218.1.57.236.49955: . ack 2389 win 83
   22:46:01.227187 IP 222.73.211.215.http > 218.1.57.236.49955: P 650:974(324) ack 2389 win 83
   22:46:01.450364 IP 218.1.57.236.49955 > 222.73.211.215.http: . ack 974 win 32281
   
   22:47:57.377707 IP 218.1.57.236.49955 > 222.73.211.215.http: P 3185:3981(796) ack 1298 win 32119
   22:47:57.377714 IP 222.73.211.215.http > 218.1.57.236.49955: . ack 3981 win 108
   22:47:59.379496 IP 222.73.211.215.http > 218.1.57.236.49955: P 1298:1622(324) ack 3981 win 108
   22:47:59.628964 IP 218.1.57.236.49955 > 222.73.211.215.http: . ack 1622 win 32768
   
   22:50:59.358537 IP 222.73.211.215.http > 218.1.57.236.49955: F 1622:1622(0) ack 3981 win 108
   22:50:59.367911 IP 218.1.57.236.49955 > 222.73.211.215.http: . ack 1623 win 32768
   22:50:59.686527 IP 218.1.57.236.49955 > 222.73.211.215.http: F 3981:3981(0) ack 1623 win 32768
   22:50:59.686531 IP 222.73.211.215.http > 218.1.57.236.49955: . ack 3982 win 108
   ```

- 第一组，三个ip包表示tcp三次握手建立连接，由浏览器建立。
- 第二组，发送第一次http请求并且得到响应，服务端守护进程输出响应之后，并没马上主动关闭tcp连接。而是启动keepalive_timout计时。
- 第三组，2分钟后，发送第二次http请求并且得到响应，同样服务端守护进程也没有马上主动关闭tcp连接，重新启动keepalive_timout计时。
- 第四组，又2分钟后，发送了第三次http请求并且得到响应。服务器守护进程依然没有主动关地闭tcp连接（距第一次http响应有4分钟了,大于keepalive_timeout值），而是重新启动了keepalive_timout计时。
- 第五组，跟最后一个响应keepalive_timeout(180s)内，守护进程再没有收到请求。计时结束，服务端守护进程主动关闭连接。4次挥手后，服务端进入TIME_WAIT状态。

这说明，当设定了keepalive_timeout，一个socket由建立到释放，需要时间是：tcp建立 + (最后一个响应时间 – 第一个请求时间) + tcp关闭 + 2MSL。红色加粗表示每一次请求发送时间、每一次请求脚本执行时间、每一次响应发送时间，还有两两请求相隔时间。进一步测试，正在关闭或者TIME_WAIT状态的tcp连接，不能传输http请求和响应。即，当一个连接结束keepalive_timeout计时，服务端守护进程发送第一个FIN标志ip包后，该连接不能再使用了。

#### http keep-alive与tcp keep-alive

http keep-alive与tcp keep-alive，不是同一回事，意图不一样。http keep-alive是为了让tcp活得更久一点，以便在同一个连接上传送多个http，提高socket的效率。而tcp keep-alive是TCP的一种检测TCP[连接](http://www.nowamagic.net/academy/tag/%E8%BF%9E%E6%8E%A5)状况的保鲜机制。tcp keep-alive保鲜定时器，支持三个系统内核配置参数：

```
echo 1800 > /proc/sys/net/ipv4/tcp_keepalive_time
echo 15 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes
```

keepalive是TCP保鲜定时器，当网络两端建立了TCP连接之后，闲置idle（双方没有任何数据流发送往来）了tcp_keepalive_time后，服务器内核就会尝试向客户端发送侦测包，来判断TCP连接状况(有可能客户端崩溃、强制关闭了应用、主机不可达等等)。如果没有收到对方的回答(ack包)，则会在 tcp_keepalive_intvl后再次尝试发送侦测包，直到收到对对方的ack,如果一直没有收到对方的ack,一共会尝试 tcp_keepalive_probes次，每次的间隔时间在这里分别是15s, 30s, 45s, 60s, 75s。如果尝试tcp_keepalive_probes,依然没有收到对方的ack包，则会丢弃该TCP连接。TCP连接默认闲置时间是2小时，一般设置为30分钟足够了。

也就是说，仅当nginx的keepalive_timeout值设置高于tcp_keepalive_time，并且距此tcp连接传输的最后一个http响应，经过了tcp_keepalive_time时间之后，操作系统才会发送侦测包来决定是否要丢弃这个TCP连接。一般不会出现这种情况，除非你需要这样做。

#### keep-alive与TIME_WAIT

使用http keep-alvie，可以减少服务端TIME_WAIT数量(因为由服务端httpd守护进程主动关闭连接)。道理很简单，相较而言，启用keep-alive，建立的tcp连接更少了，自然要被关闭的tcp连接也相应更少了。

#### 最后

我想用一张示意图片来说明使用启用keepalive的不同。另外，http keepalive是客户端浏览器与服务端httpd守护进程协作的结果，所以，我们另外安排篇幅介绍不同浏览器的各种情况对keepalive的利用。

![img](http://www.nowamagic.net/libraryshttps://cdn.jsdelivr.net/gh/fengxiu/img/201312/2013_12_20_02.png)

### 参考

[HTTP Keep-Alive是什么？如何工作？](http://www.nowamagic.net/academy/detail/23350305)