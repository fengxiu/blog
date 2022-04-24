---
categories:
  - java
  - 基础
title: 如何从Jar包中加载class
abbrlink: 7e5ec6ca
date: 2020-09-13 10:09:53
---

# 如何从Jar包中加载class

<!--  
    1. 简单介绍
    2. 说明URLClassPath 和URLClassPath.Loader之间的关系
    3. 整个加载流程
    4. 函数分析
-->

之前在看java类加载机制的时候，就在想，JVM是如何在Jar包中找到某个具体的Class文件，如果是把Jar包解压到一个指定的文件中，那我还能理解，他是先解压然后在去解压后的文件中查找有没有具体的文件，但事实上，jvm在运行java程序时候，并没有将jar包解压。所以就比较好奇jvm是如何获取到具体的class文件。本篇文章主要对其进行探究。

这里就不在叙述类加载机制，直接定位到具体加载Class文件资源的函数，代码如下：
<!-- more -->
``` java
protected Class<?> findClass(final String name)
    throws ClassNotFoundException{
    final Class<?> result;
    try {
        result = AccessController.doPrivileged(
            new PrivilegedExceptionAction<Class<?>>() {
                public Class<?> run() throws ClassNotFoundException {
                    String path = name.replace('.', '/').concat(".class");
                    Resource res = ucp.getResource(path, false);
                    if (res != null) {
                        try {
                            return defineClass(name, res);
                        } catch (IOException e) {
                            throw new ClassNotFoundException(name, e);
                        }
                    } else {
                        return null;
                    }
                }
            }, acc);
    } catch (java.security.PrivilegedActionException pae) {
        throw (ClassNotFoundException) pae.getException();
    }
    if (result == null) {
        throw new ClassNotFoundException(name);
    }
    return result;
}
```

在上面代码中，主要获取的Class文件资源的代码就是下面俩句

``` java
String path = name.replace('.', '/').concat(".class");
Resource res = ucp.getResource(path, false);
```

其中ucp指的就是URLClassPath这个类，也就是说，jvm是通过这个类来定位具体的Class资源。

## 获取Class文件资源流程

下面是本文debug时创建的一个函数，用于跟踪URLClassPath是如何加载class资源文件的。

``` java
URL url = new URL("file:/Users/zhangke/code/apache-maven-3.6.3/repository/log4j/log4j/1.2.17/log4j-1.2.17.jar");
URL url2 = new URL("file:/Users/zhangke/code/apache-maven-3.6.3/repository/hessian/hessian/3.0.13/hessian-3.0.13.jar");
URLClassPath urlClassPath = new URLClassPath(new URL[]{url2,url});
Resource resource = urlClassPath.getResource("org/apache/log4j/Appender.class");
```

这里有一点需要注意的是，在定位具体的class文件中，要把类名中的点转换成"/"。

首先补充一点知识，方便后面理解，URLClassPath是通过根据文件类型创建不通的Loader来加载具体的资源。这些Loader是URLClassPath的内部类，具体继承关系如下图。

![loader](https://cdn.jsdelivr.net/gh/fengxiu/img/loader.jpg) 

### URLClassPath#getResource

``` java
   public Resource getResource(String var1, boolean var2) {
        if (DEBUG) {
            System.err.println("URLClassPath.getResource(\"" + var1 + "\")");
        }

        // 从缓存中查找对应的Loader
        int[] var4 = this.getLookupCache(var1);

        // 循环从Loader中找出var1对应的资源文件
        URLClassPath.Loader var3;
        for(int var5 = 0; (var3 = this.getNextLoader(var4, var5)) != null; ++var5) {
            Resource var6 = var3.getResource(var1, var2);
            if (var6 != null) {
                return var6;
            }
        }

        return null;
    }
```

这个方法，主要的作用就是循环所有的Loader，查找是否有对应的资源文件

### URLClassPath#getNextLoader

``` java
    private synchronized URLClassPath.Loader getNextLoader(int[] var1, int var2) {
        if (this.closed) {
            return null;
        } else if (var1 != null) {  // 缓存的Loader数组长度大于var2索引，直接返回Loader
            if (var2 < var1.length) {
                URLClassPath.Loader var3 = (URLClassPath.Loader)this.loaders.get(var1[var2]);
                if (DEBUG_LOOKUP_CACHE) {
                    System.out.println("HASCACHE: Loading from : " + var1[var2] + " = " + var3.getBaseURL());
                }

                return var3;
            } else {
                return null;
            }
        } else {
            // Loader数组不存在，则进行创建
            return this.getLoader(var2);
        }
    }
```

首先需要注意的是，这个方法是线程安全的。方法主要有俩个作用

1. 如果文件对应的Loader已经创建，则返回缓存的Loader
2. 如果没有缓存，进行创建，即this.getLoader(var2)这句

### URLClassPath#getLoader(int var1)

下面先补充函数中用到的属性

``` java
// 存储创建的Loader
ArrayList<URLClassPath.Loader> loaders;

// 存储所有的Loader，其中key就是资源包路径名
HashMap<String, URLClassPath.Loader> lmap;

// 所有的资源
Stack<URL> urls;
```

``` java
private synchronized URLClassPath.Loader getLoader(int var1) {
        if (this.closed) {
            return null;
        } else {
            // 循环创建所有的loader
            while(this.loaders.size() < var1 + 1) {
                // 获取资源
                URL var2;
                synchronized(this.urls) {
                    if (this.urls.empty()) {
                        return null;
                    }

                    var2 = (URL)this.urls.pop();
                }
                // 处理路径
                String var3 = URLUtil.urlNoFragString(var2);
                // 判断是否存在对应路径的Loader
                if (!this.lmap.containsKey(var3)) {
                    URLClassPath.Loader var4;
                    // 创建URL对应的Loader
                    try {
                        var4 = this.getLoader(var2);
                        // 这里用于获取Jar包中class索引，加速查找Class
                        URL[] var5 = var4.getClassPath();
                        if (var5 != null) {
                            this.push(var5);
                        }
                    } catch (IOException var6) {
                        continue;
                    } catch (SecurityException var7) {
                        if (DEBUG) {
                            System.err.println("Failed to access " + var2 + ", " + var7);
                        }
                        continue;
                    }
                    // 缓存
                    this.validateLookupCache(this.loaders.size(), var3);
                    this.loaders.add(var4);
                    this.lmap.put(var3, var4);
                }
            }

            if (DEBUG_LOOKUP_CACHE) {
                System.out.println("NOCACHE: Loading from : " + var1);
            }
            // 获取索引对应的ClassLoader
            return (URLClassPath.Loader)this.loaders.get(var1);
        }
    }
```

上面函数主要处理流程：

1. 如果传入的索引小于等于loaders缓存的长度，则直接返回对应索引的Loader，否则进入第二步
2. 从urls栈中取出栈顶URL并创建对应的Loader，并对Loader进行缓存

### URLClassPath#getLoader(URL var1)

``` java
private URLClassPath.Loader getLoader(final URL var1) throws IOException {
    try {
        return (URLClassPath.Loader)AccessController.doPrivileged(new PrivilegedExceptionAction<URLClassPath.Loader>() {
            public URLClassPath.Loader run() throws IOException {
                // 后去文件名
                String var1x = var1.getFile();
                // 如果是文件夹或者文件对应的Loader
                if (var1x != null && var1x.endsWith("/")) {
                    return (URLClassPath.Loader)("file".equals(var1.getProtocol()) ? new URLClassPath.FileLoader(var1) : new URLClassPath.Loader(var1));
                } else {
                    // 创建JarLoader
                    return new URLClassPath.JarLoader(var1, URLClassPath.this.jarHandler, URLClassPath.this.lmap, URLClassPath.this.acc);
                }
            }
        }, this.acc);
    } catch (PrivilegedActionException var3) {
        throw (IOException)var3.getException();
    }
}
```

这里主要根据文件类型创建Loader。到此为止，已经将怎样创建并获取Loader流程讲完。下面介绍如何通过Loader获取具体的Resource

### URLClassPath.JarLoader#getResource(String, boolean)

```java
Resource getResource(String var1, boolean var2) {
    // 如果jar存在index，并且不包含此类，返回false
    if (this.metaIndex != null && !this.metaIndex.mayContain(var1)) {
        return null;
    } else {
        try {
            this.ensureOpen();
        } catch (IOException var5) {
            throw new InternalError(var5);
        }

        // 由于此文件是Jar类型，所有直接通过JarFIle类查找是否有次class
        // 没有直接返回
        JarEntry var3 = this.jar.getJarEntry(var1);
        if (var3 != null) {
            return this.checkResource(var1, var2, var3);
        } else if (this.index == null) {
            return null;
        } else {
            HashSet var4 = new HashSet();
            return this.getResource(var1, var2, var4);
        }
    }
}
```

上面最后一步的this.getResource(var1, var2, var4);我是真的看的头疼，不过具体的逻辑上面已经展示出来，哪位大神已经理解的话，可以把自己的理解放在回复里。
URLClassPath.FileLoader#getResource和URLClassPath.Loader#getResource大体上与此相似。