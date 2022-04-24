---
title: NIO vs BIO该如何选择
abbrlink: 8300084f
categories:
  - java
  - IO
date: 2019-07-20 16:50:39
tags:
  - IO
---
本文介绍了NIO和BIO的工作原理，并通过一组性能测试，对NIO和BIO的性能进行对比，为如何选择NIO和BIO提供理论和实践依据。
**术语介绍**

* **BIO** -- Blocking IO 即阻塞式IO。
* **NIO** -- Non-Blocking IO, 即非阻塞式IO或异步IO。
* **性能** -- 所谓的性能是指服务器响应客户端的能力，对于服务器我们通常用并发客户连接数+系统响应时间来衡量服务器性能，例如，我们说这个服务器在10000个并发下响应时间是100ms，就是高性能，而另一个服务器在10个并发下响应时间是500ms，性能一般。所以提升性能就是提升服务器的并发处理能力，和缩短系统的响应时间。
<!-- more -->
## 性能对比

用同一个Java Socket Client分别调用用BIO和NIO实现的Socket Server， 观察其建立一个Socket （TCP Connection）所需要的时间，从而计算出Server吞吐量TPS。
之所以可以用Connection建立时间来计算TPS，而不考虑业务逻辑运行时间，是因为这里的业务逻辑很简单，只是Echo回从client传过来的字符，所消耗时间可以忽略不计。

**注意：** 在现实场景中，业务逻辑会比较复杂，TPS的计算必须综合考虑IO时间+业务逻辑执行时间+多线程并行运行情况 等因素的影响。

### 测试类

发送socket请求的client

``` java
/**************************************
 *
 *      Author : zhangke
 *      Date   : 2019-07-20 16:53
 *      Desc   : 请求client
 *
 ***************************************/
public class PlainClient {

    private static int totalTime = 0;

    private static ExecutorService executorService = Executors.newCachedThreadPool();

    public static void main(String args[]) throws Exception {

        // 创建请求任务列表
        List<Callable<String>>  tasksList = new ArrayList<>();
        for (int i = 0; i < 100; i++) {
            tasksList.add(()->{
                startClient();
                return null;
            });
        }
        executorService.invokeAll(tasksList);
        System.out.println( "100个请求，平均请求时间："+ totalTime/100);

    }

    private static void startClient()
            throws  IOException {
        String host = "127.0.0.1";
        int port = 8086;

        try(// 创建socket
            Socket client = new Socket(host, port);
            // 建立连接后就可以往服务端写数据了
            Writer writer = new OutputStreamWriter(client.getOutputStream());
            // 写完以后进行读操作
            Reader reader = new InputStreamReader(client.getInputStream());
                ) {

            long beforeTime = System.nanoTime();

            writer.write("Hello Server.");
            writer.flush();

            // 用于接收数据
            char chars[] = new char[64];
            int len = reader.read(chars);
            StringBuffer sb = new StringBuffer();
            sb.append(new String(chars, 0, len));
            System.out.println("From server: " + sb.toString());
            totalTime += System.nanoTime() - beforeTime;
        }

    }
}
```

下面这个Socket Server模拟的是我们经常使用的thread-per-connection模式， Tomcat，JBoss等Web Container都是这种方式。

``` java
public class PlainEchoServer {

    private static final ExecutorService executorPool =
            Executors.newFixedThreadPool(5);


    public static void main(String[] args) throws IOException{
        PlainEchoServer server = new PlainEchoServer();
        server.serve(8086);
    }
    /**
     * 处理请求的handler
     */
    private static class Handler implements Runnable{

        // handler对应的socket
        private Socket clientSocket;

        public Handler(Socket clientSocket){
            this.clientSocket = clientSocket;
        }

        @Override
        public void run() {

            try( InputStream inputStream =  clientSocket.getInputStream();
                 OutputStream outputStream =clientSocket.getOutputStream();
            ) {

                // 读取客户端传过来的数据
                byte bytes[] = new byte[64];
                int len = inputStream.read(bytes);
                StringBuffer sb = new StringBuffer();
                sb.append(new String(bytes, 0, len));
                System.out.println("From client: " + sb);

                // 向客户端传输数据
                outputStream.write(sb.toString().getBytes());
                outputStream.flush();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    public void serve(int port) throws IOException {
        // 创建阻塞socket
        final ServerSocket socket = new ServerSocket(port);
        try {
            while (true) {
                // 阻塞等待socket请求
                final Socket clientSocket = socket.accept();
                executorPool.execute(new Handler(clientSocket));
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
```

NIO 类型的ServerSocket，这里使用一个Thread来处理所有的请求

``` java
/**************************************
 *
 *      Author : zhangke
 *      Date   : 2019-07-20 17:11
 *      Desc   :  非阻塞Socket
 *
 ***************************************/
public class PlainNioEchoServer {

    public void serve(int port) throws IOException {
        // 创建ServerSocket，并设置非阻塞
        ServerSocketChannel serverChannel = ServerSocketChannel.open();
        ServerSocket ss = serverChannel.socket();
        ss.bind(new InetSocketAddress(port));
        serverChannel.configureBlocking(false);

        // 注册当前socket中的事件绑定类
        Selector selector = Selector.open();
        // 当前socket处于accept状态
        serverChannel.register(selector, SelectionKey.OP_ACCEPT);
        while (true) {

                // 这里如果没有可以执行的key，进行阻塞，防止空转
                selector.select();

                // 获取当前服务端socket中的事件列表，并循环处理
                Set readyKeys = selector.selectedKeys();
                Iterator iterator = readyKeys.iterator();
                while (iterator.hasNext()) {
                    SelectionKey key = (SelectionKey) iterator.next();
                    try {

                        // 处理accept事件
                        if (key.isAcceptable()) {
                            ServerSocketChannel server =
                                    (ServerSocketChannel) key.channel();
                            SocketChannel client = server.accept();
                            // 检查client是否为空，可能还没有准备好socket
                            if (client == null) {
                                continue;
                            }
                            client.configureBlocking(false);
                            client.register(selector,
                                    SelectionKey.OP_WRITE | SelectionKey.OP_READ,
                                    ByteBuffer.allocate(100));
                        }

                        // 处理可读事件
                        if (key.isReadable()) {
                            SocketChannel client = (SocketChannel) key.channel();
                            ByteBuffer output = (ByteBuffer) key.attachment();
                            client.read(output);
                        }
                        // 处理可写事件
                        if (key.isWritable()) {
                            SocketChannel client = (SocketChannel) key.channel();
                            ByteBuffer output = (ByteBuffer) key.attachment();
                            output.flip();
                            client.write(output);
                            output.compact();
                        }

                    } catch (IOException ex) {
                        key.cancel();
                        try {
                            key.channel().close();
                        } catch (IOException cex) {
                        }
                    }
                    iterator.remove(); // #5
                }
        }
    }

    public static void main(String[] args) throws IOException{
        PlainNioEchoServer server = new PlainNioEchoServer();
        server.serve(8086);
    }
}
```

测试结果

``` java
// BIO
100个请求，平均请求时间：1980054
// NIO
100个请求，平均请求时间：384870
```

如果希望得到比较准确的结果，最好还是先预热下服务端的代码。从测试结果可以看出，NIO的接受请求的速率大概是BIO的6倍，而且这里NIO还只是使用了单线程，如果是多线程可能性能还会更好。

## NIO还是BIO

在探讨在什么场景下使用BIO，什么场景下使用NIO之前，让我们先看一下在两种不同IO模型下，实现的服务器有什么不同。

### **BIO Server**

通常采用的是request-per-thread模式，用一个Acceptor线程负责接收TCP连接请求，并建立链路（这是一个典型的网络IO，是非常耗时的操作），然后将请求dispatch给负责业务逻辑处理的线程池，业务逻辑线程从inputStream中读取数据，进行业务处理，最后将处理结果写入outputStream，自此，一个Transaction完成。
Acceptor线程是服务的入口，任何发生在其上面的堵塞操作，都将严重影响Server性能，假设建立一个TCP连接需要4ms，无论你后面的业务处理有多快，因为Acceptor的堵塞，这个Server最多每秒钟只能接受250个请求。而NIO则是另外一番风景，因为所有的IO操作都是非堵塞的，毫无疑问，Acceptor可以接受更大的并发量，并能最大限度的利用CPU和硬件资源处理这些请求。

BIO通信模型图
![8de4fec77b5e66a0f30380dd6f34d306ee051742](https://cdn.jsdelivr.net/gh/fengxiu/img/8de4fec77b5e66a0f30380dd6f34d306ee051742.jpeg)
BIO序列图
![ce5eb30ec17b6ea31a914e02a8eac224270ee89f](https://cdn.jsdelivr.net/gh/fengxiu/img/ce5eb30ec17b6ea31a914e02a8eac224270ee89f.jpeg)

### NIO Server

如下图所示，在NIO Server中，所有的IO操作都是异步非堵塞的，Acceptor的工作变的非常轻量，即将IO操作分派给IO线程池，在收到IO操作完成的消息通知时，指派业务逻辑线程池去完成业务逻辑处理，因为所有的耗时工作都是异步的，使得Acceptor可以以非常快的速度接收请求，10W每秒是完全有可能的。

10W/S可能是没有考虑业务处理时间，考虑到业务时间，现实场景中，普通服务器可能很难做到10W TPS，为什么这么说呢？试想下，假设一个业务处理需要500ms，而业务线程池中只有50个线程，假设其它耗时忽略不计，50个线程满负载运行，在50个并发下，大家都很happy，所有的Client都能在500ms后获得响应. 在100个并发下，因为只有50个线程，当50个请求被处理时，另50个请求只能处在等待状态直到有可用线程为止。也就是说，理想情况下50个请求会在500ms返回，另50个可能会在1000ms返回。以此类推，若是10000个并发，最慢的50个请求需要100S才能返回。

以上做法是为线程池预设50个线程，这是相对保守的一种做法，其好处是不管有多少个并发请求，系统只有这么多资源（50个线程）提供服务，是一种时间换空间的做法，也许有的客户会等很长时间，甚至超时，但是服务器的运行是平稳的。 还有一种比较激进的线程池模型是类似Netty里推荐的弹性线程池，就是没有给线程池制定一个线程上线，而是根据需要，弹性的增减线程数量，这种做法的好处是，并发量加大时，系统会创建更多的线程以缩短响应时间，缺点是到达一个极限时，系统可能会因为资源耗尽（CPU 100%或者Out of Memory)而down机。

所以可以这样说，NIO极大的提升了服务器接受并发请求的能力，而服务器性能还是要取决于业务处理时间和业务线程池模型。

NIO序列图
![612710e524d3e5a94e8c9c8325d222ab73e90485](https://cdn.jsdelivr.net/gh/fengxiu/img/612710e524d3e5a94e8c9c8325d222ab73e90485.jpeg)

## 如何选择

**什么时候使用BIO？**

* 低负载、低并发的应用程序可以选择同步阻塞BIO以降低编程复杂度。
* 业务逻辑耗时过长，使得NIO节省的时间显得微不足道。
  
**什么时候使用NIO？**

* 对于高负载、高并发的网络应用，需要使用NIO的非阻塞模式进行开发。
* 业务逻辑简单，处理时间短，例如网络聊天室，网络游戏等