---
categories:
  - java
  - 基础
title: URL详解
abbrlink: 236c7534
---
# URL详解

<!-- 
    1. 简单介绍
    2. 简单使用
    3. URLConnection简单介绍与使用
    4. URLStreamHandler 简单介绍
    5. 
 -->

 平时看源码中，发现很多开源库都会使用URL这个类，因此有必要对这个类的使用以及原理做一个总结。

这里先简单介绍一个概念，URL（Uniform Resource Locator）中文名为统一资源定位符，有时也被俗称为网页地址。表示为互联网上的资源，如网页或者FTP地址。

URL可以分为如下几个部分

``` url
protocol://host:port/path?query#fragment
```
<!-- more -->
protocol(协议)可以是 HTTP、HTTPS、FTP 和 File，port 为端口号，path为文件路径及文件名。

比如最常见的HTTP协议，

```http
http://www.taobao.com/index.html?language=cn#j2se
```

URL 解析：

* 协议为(protocol)：http
* 主机为(host:port)：www.tabao.com
* 端口号为(port): 80 ，以上URL实例并未指定端口，因为 HTTP 协议默认的端口号为 80。
* 文件路径为(path)：/index.html
* 请求参数(query)：language=cn
* 定位位置(fragment)：j2se，定位到网页中 id 属性为 j2se 的 HTML 元素位置 。

## 简单使用

``` java  
public class URLDemo
{
   public static void main(String [] args)
   {
      try
      {
         URL url = new URL("http://www.taobao.com/index.html?language=cn#j2se");
         System.out.println("URL 为：" + url.toString());
         System.out.println("协议为：" + url.getProtocol());
         System.out.println("验证信息：" + url.getAuthority());
         System.out.println("文件名及请求参数：" + url.getFile());
         System.out.println("主机名：" + url.getHost());
         System.out.println("路径：" + url.getPath());
         System.out.println("端口：" + url.getPort());
         System.out.println("默认端口：" + url.getDefaultPort());
         System.out.println("请求参数：" + url.getQuery());
         System.out.println("定位位置：" + url.getRef());
      }catch(IOException e)
      {
         e.printStackTrace();
      }
   }
}
```

## URLConnection

URL#openConnection() 返回一个 java.net.URLConnection。这个类表示应用和某个URL进行连接，可以是文件、HTTP等。不同的URL协议返回的URLConnection也不相同。

例如：

* 如果你连接HTTP协议的URL, openConnection() 方法返回 HttpURLConnection 对象。

* 如果你连接的URL为一个 JAR 文件, openConnection() 方法将返回 JarURLConnection 对象。

当然还可以自定义其它协议对应的URLConnection。

比如下面创建一个HttpURLConnection

``` java
public class URLConnDemo
{
   public static void main(String [] args)
   {
      try {
         URL url = new URL("http://www.taobao.com");
         URLConnection urlConnection = url.openConnection();
         HttpURLConnection connection = null;
         if(urlConnection instanceof HttpURLConnection){
            connection = (HttpURLConnection) urlConnection;
         }
         BufferedReader in = new BufferedReader(
         new InputStreamReader(connection.getInputStream()));
         String urlString = "";
         String current;
         while((current = in.readLine()) != null)  {
            urlString += current;
         }
         System.out.println(urlString);
      }catch(IOException e) {
         e.printStackTrace();
      }
   }
}
```

这里会打印连接对应的内容，也就是www.taobao.com这个页面的内容。

这里URLConnection是如何通过URL创建出来的呢？其实是在构造URL实例的时候就创建了对应的URLStreamHandler，由它来创建对应的URLConnection。

下面我们看下URLStreamHandler的创建过程。通过分析URL的构造函数，找出URLStreamHandler是通过getURLStreamHandler方法来创建的：
这里需要简单介绍一些对象：

* handlers  :HashTable类型，用于缓存Protocol对应的URLStreamHandler类型
* streamHandlerLock :一个简单对象，synchronize锁使用的对象
* factory ：URLStreamHandlerFactory 创建URLStreamHandler的工厂

``` java
static Hashtable<String,URLStreamHandler> handlers = new Hashtable<>();
private static Object streamHandlerLock = new Object();

// 根据protocol返回对应的URLStreamHandler
static URLStreamHandler getURLStreamHandler(String protocol) {

    // 从缓存中获取对应的Handler
    URLStreamHandler handler = handlers.get(protocol);
    // 缓存为空，创建对应的handler
    if (handler == null) {

        // 如果有factory对象，则通过工厂创建
        boolean checkedWithFactory = false;
        if (factory != null) {
            handler = factory.createURLStreamHandler(protocol);
            checkedWithFactory = true;
        }

        // 利用Handler对象创建
        if (handler == null) {
            // 查询用户是否指定了自定义的Handler package包
            String packagePrefixList = null;
            packagePrefixList
                = java.security.AccessController.doPrivileged(
                new sun.security.action.GetPropertyAction(
                    protocolPathProp,""));
            if (packagePrefixList != "") {
                packagePrefixList += "|";
            }

            // 这个是JVM自带的处理对应协议的package包对应位置
            packagePrefixList += "sun.net.www.protocol";

            StringTokenizer packagePrefixIter =
                new StringTokenizer(packagePrefixList, "|");
            //  循环创建
            while (handler == null && packagePrefixIter.hasMoreTokens()) {
                // 获取对应的包名
                String packagePrefix = packagePrefixIter.nextToken().trim();
                try {
                    // 获取packagePrefix包下面对应Protocol的handler
                    // 假设packagePrefix是sun.net.www.protocol，protocol是http
                    // 则会去加载sun.net.www.protocol.http.Handler这个类，
                    // 然后创建对应的Handler
                    String clsName = packagePrefix + "." + protocol +  ".Handler";
                    Class<?> cls = null;
                    try {
                        cls = Class.forName(clsName);
                    } catch (ClassNotFoundException e) {
                        ClassLoader cl = ClassLoader.getSystemClassLoader();
                        if (cl != null) {
                            cls = cl.loadClass(clsName);
                        }
                    }
                    if (cls != null) {
                        handler  =(URLStreamHandler)cls.newInstance();
                    }
                } catch (Exception e) {
                    // any number of exceptions can get thrown here
                }
            }
        }

        // 缓存Handler对象
        synchronized (streamHandlerLock) {
            URLStreamHandler handler2 = null;
            handler2 = handlers.get(protocol);

            if (handler2 != null) {
                return handler2;
            }
            if (!checkedWithFactory && factory != null) {
                handler2 = factory.createURLStreamHandler(protocol);
            }
            if (handler2 != null) {
                handler = handler2;
            }
            if (handler != null) {
                handlers.put(protocol, handler);
            }

        }
    }

    return handler;
}
```

创建Handler总共分为下面三步，前一步创建不成功，才会到下面一步创建：

1. 从缓存中获取protocol协议对应的Handler
2. 如果URLStreamHandlerFactory存在，则通过其进行创建，这里可以通过setURLStreamHandlerFactory方法进行设置，此属性是static
3. 通过加载"package+protocol+Handler" class的方式，然后通过Class.newInstance()方式创建。
4. 最后检测缓存中是否有此协议的Handler，如果没有则缓存。

## URLStreamHandler

 java.net.URLStreamHandler 是一个工厂类，通过 openConnection(java.net.URL) 方法来创建java.net.URLConnection 的实例。在 SUN JDK 中 sun.net.www.protocol 子包下面的多个 Handler类就是很好的例子。

如果需要自定义URLStreamHandler 对象，可以通过以下俩种方式注入到URL中：

1. 设置自定义的URLStreamHandler类名为Handler，然后在程序启动的时候加上-Djava.protocol.handler.pkgs="Handler所在包名"参数，这个就会通过上面创建Handler的第三步来创建自定义的Handler。
2. 自定义java.net.URLStreamHandlerFactory ，然后通过URL#setURLStreamHandlerFactory设置，则创建Handler时就可以通过创建Handler的第二步来创建自定义的URLStreamHandler。

java.net.URLStreamHandlerFactory ，顾名思义，它是URLStreamHandler的工厂，即抽类工厂接口。通过调用 createURLStreamHandler(String protocol) 来创建 java.net.URLStreamHandler 对象。因此，建议java.net.URLStreamHandlerFactory 实现类应该采用 one protocol one hander 的模式， SUN JDK 也采用该模式。

![URL](https://raw.githubusercontent.com/fengxiu/img/master/URL.png)

### URLStreamHandlerFactory 方式

图 1 所示， URL 包含了名为 factory 的 URLStreamHandlerFactory 类对象和 handler 的 URLStreamHandler的实例对象。对于 URL 而言， handler 对象是必须的，因为前面说到实际处理 openConnection() 方法是 handler对象，而 factory 并不是必须的。接下来，来分析这两个对象是如何和 URL 交互的。

在 URL 的构造方法中，暂时不用关心协议字符串等参数，更多的关注于 URL context 和 URLStreamHandler参数。 URL 实例能够依赖于 URL context ，当 URLStreamHandler 参数为空的情况下，当前 URL 实例将会采用URL context 的 URLStreamHandler 成员对象。当 Context 和 URLStreamHandler 参数都为空的时。 URL 会调用getURLStreamHandler （ String) 方法，从而根据协议 (protocol) 获得协议 URLStreamHandler 对象。

在 URL 底层实现中，最初会初始化一个 protocol 和 hander 键值关系的 Map 映射。如果找到已有的映射关系，立即返回 URLStreamHandler 对象（第一次是取不到 URLStreamHandler 对象的）。

如果找不到的话，并且 URL 类中的类成员 URLStreamHandlerFactory 实例不为空的情况下，这个实例通过URL#setURLStreamHandlerFactory 方法来注册。 getURLStreamHandler 方法会调用这个类成员的createURLStreamHandler(String) 方法来创建 URLStreamHandler 实例。

``` java
URL.setURLStreamHandlerFactory(new MyURLStreamHandlerFactory());

class MyURLStreamHandlerFactory implements URLStreamHandlerFactory{  
        @Override  
        public URLStreamHandler createURLStreamHandler(String protocol) {  
            return null;  
        }
}
```

### 实现类包路径定义

通过 JVM 启动参数 -D java.protocol.handler.pkgs 来设置 URLStreamHandler 实现类的包路径，例如 -Djava.protocol.handler.pkgs=com.acme.protocol ， 代表处理实现类皆在这个包下。如果需要多个包的话，那么使用“ |” 分割。比如 -D java.protocol.handler.pkgs=com.acme.protocol|com.acme.protocol2 。 SUN 的 JDK内部实现类均是在 sun.net.www.protocol. 包下，不必设置。 路径下的协议实现类，采用先定义先选择的原则 。

#### 实现类的命名模式

 类的命名模式为 [package_path].[protocol].Handler ，比如默认实现"sun.net.www.protocol.[protocol].Handler", 比如 HTTP 协议的对应的处理类名为:sun.net. www.protocol.http.Handler 。同样，自定义实现的处理类，例如，JDNI 协议实现类命名 com.acme.protocol.jndi.Handler 。

#### 实现类必须有默认构造器

因为在创建URLStreamHandler对象时，URL类是通过Class.newInstance()方式创建。
Java 1.5 开始支持网络代理的操作，因此 URLStreamHandler 实现类尽量覆盖 openConnection(URL) 和openConnection(URL,Proxy) 两个方法。

## 参考

1. [Java URL协议扩展实现](https://blog.csdn.net/moakun/article/details/80716788)