---
tags:
  - http
categories:
  - 网络
  - http
title: HTTP协议简介
abbrlink: 41df0a9f
date: 2019-03-10 07:25:00
update: 2019-03-10 07:25:00
---
## HTTP协议简介

HTTP协议是Hyper Text Transfer Protocol(超文本传输协议)的缩写,用于万维网（WWW:World Wide Web ）服务器传输超文本到本地浏览器的传送协议。

在OSI七层模型中，HTTP协议位于应用层，是应用层协议。浏览器访问网页使用http协议来进行数据的传输，使用HTTP协议时，客户端首先与服务端的80（默认）端口建立一个TCP连接，然后在这个连接的基础上进行请求和应答，以及数据的交换，数据可以是HTML文件, 图片文件, 查询结果等。

HTTP是一个属于应用层的面向对象的协议，由于其简捷、快速的方式，适用于分布式超媒体信息系统。它于1990年提出，经过几年的使用与发展，得到不断地完善和扩展。HTTP有三个常用版本，分别是1.0、1.1和2。主要区别在于HTTP1.0中每次请求和应答都会使用一个新的TCP连接，而从HTTP1.1开始，运行在一个TCP连接上发送多个请求和应答。因此大幅度减少了TCP连接的建立和断开，提高了效率。HTTP2在1.1的基础上改进协议的一些特点，包括长连接、pipeline、并行连接等。

HTTP协议工作于客户端-服务端架构为上。浏览器作为HTTP客户端通过URL向HTTP服务端即WEB服务器发送所有请求。Web服务器根据接收到的请求后，向客户端发送响应信息。基本模式如下图：

![](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-205.png)

## 主要特点

1. 简单快速：客户向服务器请求服务时，只需传送请求方法和路径。请求方法常用的有GET、HEAD、POST。每种方法规定了客户与服务器联系的类型不同。由于HTTP协议简单，使得HTTP服务器的程序规模小，因而通信速度很快。

2. 灵活：HTTP允许传输任意类型的数据对象。正在传输的类型由Content-Type加以标记。

3. 无连接：无连接的含义是限制每次连接只处理一个请求。服务器处理完客户的请求，并收到客户的应答后，即断开连接。采用这种方式可以节省传输时间。

4. 无状态：HTTP协议是无状态协议。无状态是指协议对于事务处理没有记忆能力。缺少状态意味着如果后续处理需要前面的信息，则它必须重传，这样可能导致每次连接传送的数据量增大。另一方面，在服务器不需要先前信息时它的应答就较快。
5. 支持B/S及C/S模式。

## URL与URI

在介绍HTTP协议的格式之前，我们先来看看URL和URI。这俩个概念经常被弄混。

### URI-统一资源标识符

首先，什么是URI呢？URI，全称为uniform resource identifier，统一资源标识符，用来唯一的标识一个资源。

Web上可用的每种资源-HTML文档、图像、视频片段、程序等都由一个通用资源标识符（即URI）进行定位。

URI一般由三部分组成：

1. 访问资源的命名机制
2. 存放资源的主机名
3. 资源自身的名称，由路径表示

比如下面这个URI例子：
`http://www.dodomonster.com/html/html4`

这个URI定义如下：是一个通过HTTP协议访问的资源，位于www.dodomonster.com上，通过路径"/html/html4"访问。

有的URI指向一个资源的内部。这种URi以"#"结束，并跟着一个anchor标识符（称为片段标识符）。例如，下面是一个指向section_2的URI：`http://somesite.com/html/top.htm#section_2`

**绝对URi**
URI有绝对和相对之分，绝对的URI指以scheme（后面跟着冒号）开头的URi。前面提到的`http://www.cnn.com`就是绝对的URI的一个例子，其它的例子还有`mailto:jeff@javajeff.com`、`news:comp.lang.java.help`和`xyz://whatever`。你可以把绝对的URi看作是以某种方式引用某种资源，而这种方式对标识符出现的环境没有依赖。如果使用文件系统作类比，绝对的URI类似于从根目录开始的某个文件的径。

**相对URi**
相对URI不包含任何命名规范信息，它的路径通常指同一台机器上的资源。相对URI可能含有相对路径（如，"..."表示上一层路径），还可能包含片段标识符。
为了说明相对URI，此处举一个例子,假设在一个HTML页面地址是：`http://www.dodomonster.com/support/index.htm`
里有一张图片，地址是`<img src="../icons/logo.png" alt="logo">`。此地址就是相对地址，它扩展成完全的URi就是`http://www.dodomonster.com/icons/logo.png`

与绝对的URI不同的，相对的URI不是以scheme（后面跟着冒号）开始。可以把相对的URI看作是以某种方式引用某种资源，而这种方式依赖于标识符出现的环境。如果用文件系统作类比，相对的URI类似于从当前目录开始的文件路径。

### URL-统一资源定位器

URL全程是uniform resource locator，统一资源定位器，它是一种具体的URI，即URL不仅可以用来标识一个资源，而且还指明了如何去定位这个资源。通俗地说，URL是Internet上用来描述资源的字符串，主要用在各种www客户端和服务器程序，特别是著名的Mosaic。采用URL可以用一种统一的格式来描述各种信息资源，包括文件、服务器的地址和目录等。

URL的第一个部分`http://`表示要访问的文件的类型。在网上，这几乎总是使用http（超文本传输协议，hypertext transfer protocol-用来转换网页的协议）；有时也使用ftp（文件传输协议，file transfer protocol-用来传输软件和大文件；telnet（远程登录），主要用于远程交谈以及文件调用等，意思是浏览器正在阅读本地盘外的一个文件而不是一个远程计算机。

**URL组成**

1. **Internet资源类型（schema）**：指出www客户程序用来C作的工具。如`http://`表示www服务器，`ftp://`表示ftp服务器，`gopher://`表示Gopher服务器，而`new:`表示Newgroup新闻组。必需的。

2. **服务器地址（host）**：指出www网页所在的服务器域名。必需的。

3. **端口（port）**：对某些资源的访问来说，需给出相应的服务器提供端口。可选的。

4. **路径（path）**：指明服务器上某资源的位置。与端口一样，路径并非总是需要的。可选的。

URL地址格式排列为：`schema://host:port/path`，如：`http://www.maogoo.com/bbs`
客户程序首先看到http（超文本协议），便知道处理的是HTML链接。接下来的wwww.maogoo.com是站点地址，最后是目录/bbs。

必须注意：www上的服务器都是区分大小写的，所以千万要注意正确的URL大小写表达形式。

在Java的URI中，一个URI实例可以代表绝对的，也可以是相对的，只要它符合URI的语法规则。而URL类则不仅符合语义，还包含了定位该资源的信息，因此它不能是相对的。 在Java类库中，URI类不包含任何访问资源的方法，它唯一的作用就是解析。相反的是，URL类可以打开一个到达资源的流。

## HTTP之请求与响应格式

大致的格式如下：

**请求报文包含四部分：**

- 请求行：包含请求方法、URI、HTTP版本信息
- 请求头部字段
- 空行
- 请求内容实体

**响应报文包含四部分：**

- 状态行：包含HTTP版本、状态码、状态码的原因短语
- 响应头部字段
- 空行
- 响应内容实体

### 请求消息（Request）具体例子

请求的格式如下图：

![upload successful](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-206.png)

下面以一个具体的例子来解释请求的消息格式,

```http
GET /562f25980001b1b106000338.jpg HTTP/1.1
Host    img.mukewang.com
User-Agent  Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.106 Safari/537.36
Accept  image/webp,image/*,*/*;q=0.8
Referer http://www.imooc.com/
Accept-Encoding gzip, deflate, sdch
Accept-Language zh-CN,zh;q=0.8
```

1. **请求行**:表示请求类型，请求的资源地址，以及使用的HTTP协议版本号，分别以空格隔开，以换行符表示结束。对应上面的例子可以看出，请求类型为GET,**[/562f25980001b1b106000338.jpg]**为要访问的资源，该行的最后一部分说明使用的是**HTTP1.1**版本。

2. **请求头部字段：**：用来说明服务器要使用的附加信息。每一行是一个附加信息，以换行符来区别不同的附加信息，然后每一行中通过空格来区别开key值和value。从第二行起为请求头部，从上面的例子可以得出以下的信息，
   1. **HOST**：将指出请求的目的地.
   2. **User-Agent**：服务器端和客户端脚本都能访问它,它是浏览器类型检测逻辑的重要基础.该信息由你的浏览器来定义,并且在每个请求中自动发送等等
   3. **Accept**：指出可以接受的数据类型

3. **空行：**：请求头部后面的空行是必须的，即使第四部分的请求数据为空，也必须有空行。代表头部的结束。

4. **请求内容：**：可以添加任意的内容。

**POST请求例子，使用Charles抓取的request：**

```http
POST / HTTP1.1
Host:www.wrox.com
User-Agent:Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 2.0.50727; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022)
Content-Type:application/x-www-form-urlencoded
Content-Length:40
Connection: Keep-Alive

name=Professional%20Ajax&publisher=Wiley
```

第一部分：请求行，第一行明了是post请求，以及http1.1版本。
第二部分：请求头部，第二行至第六行。
第三部分：空行，第七行的空行。
第四部分：请求数据，第八行。

### 响应消息（Response）例子

一般情况下，服务器接收并处理客户端发过来的请求后会返回一个HTTP的响应消息。

一个简单的响应的例子：

```http
HTTP/1.1 200 OK
Date: Fri, 22 May 2009 06:07:21 GMT
Content-Type: text/html; charset=UTF-8

<html>
      <head></head>
      <body>
            <!--body goes here-->
      </body>
</html>
```

1. **状态行**:由HTTP协议版本号，状态码，状态消息 三部分组成，主要用来表示响应消息的状态。上面的例子第一行为状态行，（HTTP/1.1）表明HTTP版本为1.1版本，状态码为200，状态消息为（ok）

2. **消息报头**：表示表示响应的一些信息，比如编码，时间等等。要使用的一些附加信息，和前面的请求数据一样，使用换行符来区别不同的附加信息，然后每一行通过空格来区分开key值和value。上面例子的第二行和第三行为消息报
   1. **Date**:生成响应的日期和时间；
   2. **Content-Type**:指定了MIME类型的HTML(text/html),编码类型是UTF-8

3. **空行**：消息报头后面的空行是必须的，用于区别开响应的头部信息和数据部分信息

4. **响应正文**： 服务器返回给客户端的文本信息。上面的例子返回的是html文本。

## HTTP请求方法

根据HTTP标准，HTTP请求可以使用多种请求方法。
 HTTP1.0定义了三种请求方法： GET, POST 和 HEAD方法。
 HTTP1.1新增了五种请求方法：OPTIONS, PUT, DELETE, TRACE 和 CONNECT 方法。

* GET     请求指定的页面信息，并返回实体主体。
* HEAD  类似于get请求，只不过返回的响应中没有具体的内容，用于获取报头
* POST     向指定资源提交数据进行处理请求（例如提交表单或者上传文件）。数据被包含在请求体中。POST请求可能会导致新的资源的建立和/或已有资源的修改。
* PUT  从客户端向服务器传送的数据取代指定的文档的内容。
* DELETE   请求服务器删除指定的页面。
* CONNECT  HTTP/1.1协议中预留给能够将连接改为管道方式的代理服务器。
* OPTIONS  允许客户端查看服务器的性能。
* TRACE    回显服务器收到的请求，主要用于测试或诊断。

这里简答介绍GET和POST方法的区别

### GET和POST请求的区别

首先通过一个具体的请求来先了解他们的区别，然后在进行总结
**GET请求**

```http
GET /books/?sex=man&name=Professional HTTP/1.1
Host: www.wrox.com
User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.6)
Gecko/20050225 Firefox/1.0.1
Connection: Keep-Alive
```

注意最后一行是空行
**POST请求**

```http
POST / HTTP/1.1
Host: www.wrox.com
User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.6)
Gecko/20050225 Firefox/1.0.1
Content-Type: application/x-www-form-urlencoded
Content-Length: 40
Connection: Keep-Alive

name=Professional%20Ajax&publisher=Wiley
```

**GET和POST的区别**

1. GET提交的数据会放在URL之后，以?分割URL和传输数据，参数之间以&相连，如EditPosts.aspx?name=test1&id=123456.  POST方法是把提交的数据放在HTTP包的Body中.
2. GET提交的数据大小有限制（因为浏览器对URL的长度有限制），而POST方法提交的数据没有限制.
3. GET方式需要使用Request.QueryString来取得变量的值，而POST方式通过Request.Form来获取变量的值。
4. GET方式提交数据，会带来安全问题，比如一个登录页面，通过GET方式提交数据时，用户名和密码将出现在URL上，如果页面可以被缓存或者其他人可以访问这台机器，就可以从历史记录获得该用户的账号和密码.

此外Http协议定义了很多与服务器交互的方法，最基本的有4种，分别是GET,POST,PUT,DELETE. 一个URL地址用于描述一个网络上的资源，而HTTP中的GET, POST, PUT, DELETE就对应着对这个资源的查，改，增，删4个操作。 我们最常见的就是GET和POST了。GET一般用于获取/查询资源信息，而POST一般用于更新资源信息。其中这一块还有一个幂等性的概念，这个会单独写一篇文章来解释。

## HTTP状态码

当浏览者访问一个网页时，浏览者的浏览器会向网页所在服务器发出请求。当浏览器接收并显示网页前，此网页所在的服务器会返回一个包含HTTP状态码的信息头（server header）用以响应浏览器的请求。

HTTP状态码的英文为HTTP Status Code。

下面是常见的HTTP状态码：

- 200 - 请求成功
- 301 - 资源（网页等）被永久转移到其它URL
- 404 - 请求的资源（网页等）不存在
- 500 - 内部服务器错误

## HTTP状态码分类

HTTP状态码由三个十进制数字组成，第一个十进制数字定义了状态码的类型，后两个数字没有分类的作用。HTTP状态码共分为5种类型：

| 分类 | 分类描述                                       |
| ---- | ---------------------------------------------- |
| 1**  | 信息，服务器收到请求，需要请求者继续执行操作   |
| 2**  | 成功，操作被成功接收并处理                     |
| 3**  | 重定向，需要进一步的操作以完成请求             |
| 4**  | 客户端错误，请求包含语法错误或无法完成请求     |
| 5**  | 服务器错误，服务器在处理请求的过程中发生了错误 |

HTTP状态码列表:

| 状态码 | 状态码英文名称                  |                                                                                    中文描述                                                                                     |
| ------ | ------------------------------- | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| 100    | Continue                        |                                                  继续。[客户端](http://www.dreamdu.com/webbuild/client_vs_server/)应继续其请求                                                  |
| 101    | Switching Protocols             |                                      切换协议。服务器根据客户端的请求切换协议。<br />只能切换到更高级的协议，例如，切换到HTTP的新版本协议                                       |
|        |                                 |                                                                                                                                                                                 |
| 200    | OK                              |                                                                         请求成功。一般用于GET与POST请求                                                                         |
| 201    | Created                         |                                                                        已创建。成功请求并创建了新的资源                                                                         |
| 202    | Accepted                        |                                                                       已接受。已经接受请求，但未处理完成                                                                        |
| 203    | Non-Authoritative Information   |                                                   非授权信息。请求成功。但返回的meta信息不在原始的服务器，<br />而是一个副本                                                    |
| 204    | No Content                      |                                         无内容。服务器成功处理，但未返回内容。<br />在未更新网页的情况下，可确保浏览器继续显示当前文档                                          |
| 205    | Reset Content                   |                                 重置内容。服务器处理成功，<br />用户终端（例如：浏览器）应重置文档视图。<br />可通过此返回码清除浏览器的表单域                                  |
| 206    | Partial Content                 |                                                                      部分内容。服务器成功处理了部分GET请求                                                                      |
|        |                                 |                                                                                                                                                                                 |
| 300    | Multiple Choices                |                               多种选择。请求的资源可包括多个位置，<br />相应可返回一个资源特征与地址的列表<br />用于用户终端（例如：浏览器）选择                                |
| 301    | Moved Permanently               |                   永久移动。请求的资源已被永久的移动到新URI，<br />返回信息会包括新的URI，<br />浏览器会自动定向到新URI。今后任何新的请求都应使用新的URI代替                    |
| 302    | Found                           |                                                 临时移动。与301类似。但资源只是临时被移动。<br /><br />客户端应继续使用原有URI                                                  |
| 303    | See Other                       |                                                                 查看其它地址。与301类似。使用GET和POST请求查看                                                                  |
| 304    | Not Modified                    |  未修改。所请求的资源未修改，服务器返回此状态码时，<br />不会返回任何资源。客户端通常会缓存访问过的资源，<br />通过提供一个头信息指出客户端希望只返回在指定日期之后修改的资源   |
| 305    | Use Proxy                       |                                                                     使用代理。所请求的资源必须通过代理访问                                                                      |
| 306    | Unused                          |                                                                             已经被废弃的HTTP状态码                                                                              |
| 307    | Temporary Redirect              |                                                                    临时重定向。与302类似。使用GET请求重定向                                                                     |
|        |                                 |                                                                                                                                                                                 |
| 400    | Bad Request                     |                                                                      客户端请求的语法错误，服务器无法理解                                                                       |
| 401    | Unauthorized                    |                                                                             请求要求用户的身份认证                                                                              |
| 402    | Payment Required                |                                                                                 保留，将来使用                                                                                  |
| 403    | Forbidden                       |                                                                 服务器理解请求客户端的请求，但是拒绝执行此请求                                                                  |
| 404    | Not Found                       |                                  服务器无法根据客户端的请求找到资源（网页）。通过此代码，网站设计人员可设置"您所请求的资源无法找到"的个性页面                                   |
| 405    | Method Not Allowed              |                                                                            客户端请求中的方法被禁止                                                                             |
| 406    | Not Acceptable                  |                                                                   服务器无法根据客户端请求的内容特性完成请求                                                                    |
| 407    | Proxy Authentication Required   |                                                         请求要求代理的身份认证，与401类似，但请求者应当使用代理进行授权                                                         |
| 408    | Request Time-out                |                                                                    服务器等待客户端发送的请求时间过长，超时                                                                     |
| 409    | Conflict                        |                                                      服务器完成客户端的PUT请求是可能返回此代码，服务器处理请求时发生了冲突                                                      |
| 410    | Gone                            |                  客户端请求的资源已经不存在。410不同于404，<br />如果资源以前有现在被永久删除了可使用410代码，<br />网站设计人员可通过301代码指定资源的新位置                   |
| 411    | Length Required                 |                                                             服务器无法处理客户端发送的不带Content-Length的请求信息                                                              |
| 412    | Precondition Failed             |                                                                          客户端请求信息的先决条件错误                                                                           |
| 413    | Request Entity Too Large        | 由于请求的实体过大，服务器无法处理，<br />因此拒绝请求。为防止客户端的连续请求，<br />服务器可能会关闭连接。如果只是服务器暂时无法处理，<br />则会包含一个Retry-After的响应信息 |
| 414    | Request-URI Too Large           |                                                                 请求的URI过长（URI通常为网址），服务器无法处理                                                                  |
| 415    | Unsupported Media Type          |                                                                        服务器无法处理请求附带的媒体格式                                                                         |
| 416    | Requested range not satisfiable |                                                                              客户端请求的范围无效                                                                               |
| 417    | Expectation Failed              |                                                                        服务器无法满足Expect的请求头信息                                                                         |
|        |                                 |                                                                                                                                                                                 |
| 500    | Internal Server Error           |                                                                          服务器内部错误，无法完成请求                                                                           |
| 501    | Not Implemented                 |                                                                      服务器不支持请求的功能，无法完成请求                                                                       |
| 502    | Bad Gateway                     |                                              作为网关或者代理工作的服务器尝试执行请求时，<br />从远程服务器接收到了一个无效的响应                                               |
| 503    | Service Unavailable             |                                    由于超载或系统维护，服务器暂时的无法处理客户端的请求。<br />延时的长度可包含在服务器的Retry-After头信息中                                    |
| 504    | Gateway Time-out                |                                                               充当网关或代理的服务器，未及时从远端服务器获取请求                                                                |
| 505    | HTTP Version not supported      |                                                                 服务器不支持请求的HTTP协议的版本，无法完成处理                                                                  |

## 参考

1. [关于HTTP协议，一篇就够了](https://www.jianshu.com/p/80e25cb1d81a)
2. [详解URL的组成](https://blog.csdn.net/ergouge/article/details/8185219)
3. [URI、URL和URN的区别](https://segmentfault.com/a/1190000006081973)