---
categories:
  - java
  - spring
  - springboot
title: SpringBoot源码分析之spring-boot-loader可执行文件解析
abbrlink: 54f801f1
---
# SpringBoot源码分析之spring-boot-loader可执行文件解析

<!-- 
   1.  为什么会有这个
   2.  简单介绍怎么使用springboot maven plugin
   3.  格式
   4.  启动原理
 -->

spring-boot-loader模块使得springboot应用具备打包为可执行jar或war文件的能力。只需要引入Maven插件或者Gradle插件就可以自动生成。

​Java中并没有标准的方法加载嵌入式的jar文件，通常都是在一个jar文件中。这种情况下，如果你要通过命令行的形式发布一个没有打包的独立程序的话，可能会出现问题。

​为了解决这种问题，很多人员使用"shaded jars"方式，即将所有的class文件都打包在一个jar包里面，也就是通常所有的"uber jar"。这种方式下，开发人员很难去判断哪个依赖的文件库是被程序真正使用到的。更普遍的问题是，在不同的jar文件中，如果有相同名称的文件则会冲突。spring boot采用了一种不同的方式，让我们可以直接从命令行启动jar。这也就是spring-boot-loader模块提供的功能。

这里补充一点，如果你对jar文件或者Manifest不是很清楚的话，可以看这篇文章.
[java 打包技术之jar文件](/posts/2f7bd7dc/)
<!-- more -->
<!-- （这里说明一下，在传统的可执行jar文件中会有/META-INF/MANIFEST.MF文件，这里主要介绍两个属性：Main-Class和classpath，Main-Class是可执行jar的启动类，classpath则可以指定依赖的类库。） -->

## SpringBoot loader插件提供的可执行文件结构

``` java
example.jar
 |
 +-META-INF (1)
 |  +-MANIFEST.MF
 +-org (2)
 |  +-springframework
 |     +-boot
 |        +-loader
 |           +-<spring boot loader classes>
 +-BOOT-INF 
    +-classes (3)
    |  +-mycompany
    |     +-project
    |        +-YourClasses.class
    +-lib (4)
    |   +-dependency1.jar
    |   +-dependency2.jar
    |   ...........
```

1. META-INF ：Jar文件MANIFEST.MF文件存放处
2. org.springframework.boot.loader : springboot-loader启动应用class存放处
3. BOOT-INF/classes : 应用本身文件存放处
4. BOOT-INF/lib :应用需要的依赖存放处

## MANIFEST.MF 文件内容

``` java
Manifest-Version: 1.0
Spring-Boot-Classpath-Index: BOOT-INF/classpath.idx
Built-By: zhangke
Start-Class: club.fengxiu.App
Spring-Boot-Classes: BOOT-INF/classes/
Spring-Boot-Lib: BOOT-INF/lib/
Spring-Boot-Version: 2.3.0.RELEASE
Created-By: Apache Maven 3.6.3
Build-Jdk: 1.8.0_251
Main-Class: org.springframework.boot.loader.JarLauncher
```

从中可以看得到，它的Main-Class是org.springframework.boot.loader.JarLauncher，即当使用java -jar执行jar包的时候会调用JarLunch的main方法，而不是调用应用本身定义的SpringApplication注解的类。

从这里应该可以猜测出，Springboot-Loader模块打包出的jar具备可执行能力跟这个类有很大的关系。它是SpringBoot定义的一个工具类，用于执行应用定义的SpringApplication类。相当于SpringBoot Loader提供了一套标准用于执行SpringBoot打包出来的jar。

## JarLuncher的执行流程

### SpringBoot loader模块类简介

由于下面会多次涉及到一些类，

### JarLauncher#main

``` java
public static void main(String[] args) throws Exception {
   new JarLauncher().launch(args);
}
```

这个方法比较简单，构造JarLuncher，然后调用launch方法，并将控制台的参数传进去。这个是默认的构造函数，因此这个类在创建的时候，同时会调用父类的构造函数，也就是ExecutableArchiveLauncher的默认构造函数，ExecutableArchiveLauncher#ExecutableArchiveLauncher()代码如下

``` java
public ExecutableArchiveLauncher() {
   try {
      this.archive = createArchive();
   }
   catch (Exception ex) {
      throw new IllegalStateException(ex);
   }
}
```

可以看出，这里会调用createArchive()方法，这个方法主要是用来创建Archive，这个类是SpringBoot-loader定义的归档文件基础抽象类。具体的实现有俩个，JarFileArchive和ExplodedArchive。JarFileArchive是用来对Jar包文件的抽象，主要用来获取Jar包中的各种文件或者信息，主要实现是通过JarFile类，其实也就是JarFile的一个装饰器。ExplodedArchive是文件目录的抽象。

JarFile：对jar包的封装，每个JarFileArchive都会对应一个JarFile。JarFile被构造的时候会解析内部结构，去获取jar包里的各个文件或文件夹，这些文件或文件夹会被封装到Entry中，也存储在JarFileArchive中。如果Entry是个jar，会解析成JarFileArchive。注意这里的JarFile是对java默认类java.util.jar.JarFile的重新定义。

有了以上知识，下面就就可以来看createArchive方法

``` java
protected final Archive createArchive() throws Exception {

   // 获取当前类所对应的绝对路径
   ProtectionDomain protectionDomain = getClass().getProtectionDomain();
   CodeSource codeSource = protectionDomain.getCodeSource();
   URI location = (codeSource != null) ? codeSource.getLocation().toURI() : null;
   String path = (location != null) ? location.getSchemeSpecificPart() : null;
   if (path == null) {
      throw new IllegalStateException("Unable to determine code source archive");
   }
   // 创建File对象
   File root = new File(path);
   if (!root.exists()) {
      throw new IllegalStateException("Unable to determine code source archive from " + root);
   }
   // 创建文件对应的Archive抽象
   return (root.isDirectory() ? new ExplodedArchive(root) : new JarFileArchive(root));
}
```

### Launcher#launch(java.lang.String[])

```java
protected void launch(String[] args) throws Exception {
   // 注册UrlProtocolHandler
   JarFile.registerUrlProtocolHandler();
   // 根据当前可执行Jar的ClassPath创建ClassLoader
   ClassLoader classLoader = createClassLoader(getClassPathArchives());
   // 启动应用
   launch(args, getMainClass(), classLoader);
}
```

这个方法主要分为三步，下面分别介绍每一步

#### JarFile.registerUrlProtocolHandler()

``` java
public static void registerUrlProtocolHandler() {
   // 注册系统指定的UrlProtocolHandler，如果没有指定使用springboot-loader默认的，
   String handlers = System.getProperty(PROTOCOL_HANDLER, "");
   System.setProperty(PROTOCOL_HANDLER,
         ("".equals(handlers) ? HANDLERS_PACKAGE : handlers + "|" + HANDLERS_PACKAGE));
   resetCachedUrlHandlers();
}


private static void resetCachedUrlHandlers() {
   try {
      URL.setURLStreamHandlerFactory(null);
   }
   catch (Error ex) {
      // Ignore
   }
}
```

查看系统是否注册了指定的URL处理器，如果没有则使用org.springframework.boot.loader.jar.Handler自定义的。这里具体的操作可以看
<!-- TODO:加一篇URL 处理 -->

#### createClassLoader(getClassPathArchives())

``` java

// 判断当前文件是否是spring-boot-loader打包的标准文件，
// 主要检测依据有俩条，如果是文件夹，文件路径BOOT-INF/classes/
// 如果是文件，则要以BOOT-INF/lib/开头
protected boolean isNestedArchive(Archive.Entry entry) {
   if (entry.isDirectory()) {
      return entry.getName().equals(BOOT_INF_CLASSES);
   }
   return entry.getName().startsWith(BOOT_INF_LIB);
}
// 这个方法主要用来处理获取Class path，需要满足上面定义的isNestedArchive
protected List<Archive> getClassPathArchives() throws Exception {
   List<Archive> archives = 
      new ArrayList<>(this.archive.getNestedArchives(this::isNestedArchive));
   postProcessClassPathArchives(archives);
   return archives;
}

// 根据Archive的路径创建对应的ClassLoader
protected ClassLoader createClassLoader(List<Archive> archives) throws Exception {
   List<URL> urls = new ArrayList<>(archives.size());
   for (Archive archive : archives) {
      urls.add(archive.getUrl());
   }
   return createClassLoader(urls.toArray(new URL[0]));
}
// 根据指定的路径创建ClassLoader
protected ClassLoader createClassLoader(URL[] urls) throws Exception {
   return new LaunchedURLClassLoader(urls, getClass().getClassLoader());
}
```

#### Launcher#launch(args, getMainClass(), classLoader)

这一步主要是获取MainClass，然后启动应用

JarArchive的getMainClass方法，主要是通过MANIFEST.MF文件获取对应Start-Class对应的值
``` java
@Override
protected String getMainClass() throws Exception {
   Manifest manifest = this.archive.getManifest();
   String mainClass = null;
   if (manifest != null) {
      mainClass = manifest.getMainAttributes().getValue("Start-Class");
   }
   if (mainClass == null) {
      throw new IllegalStateException("No 'Start-Class' manifest entry specified in " + this);
   }
   return mainClass;
}
```

```java
protected void launch(String[] args, String mainClass, ClassLoader classLoader) throws Exception {
   // 设置当前线程的ClassLoader
   Thread.currentThread().setContextClassLoader(classLoader);
   // 创建MainMethodRunner并调用main方法启动应用
   createMainMethodRunner(mainClass, args, classLoader).run();
}
protected MainMethodRunner createMainMethodRunner(String mainClass, String[] args, ClassLoader classLoader) {
   return new MainMethodRunner(mainClass, args);
}
```

MainMethodRunner的run方法

``` java
public void run() throws Exception {
   // 加载start-class对应的类，即SpringbootApplication注解的类，应用启动类
   Class<?> mainClass = Thread.currentThread().getContextClassLoader().loadClass(this.mainClassName);
   // 获取main方法
   Method mainMethod = mainClass.getDeclaredMethod("main", String[].class);
   // 使用反射调用此类，
   mainMethod.invoke(null, new Object[] { this.args });
}
```

到这一步，真正执行的应用对应的类。

## LaunchedURLClassLoader

这个是在Springboot-loader中使用的ClassLoader，这个类重写了LoadClass这个方法，

``` java
protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
   Handler.setUseFastConnectionExceptions(true);
   try {
      try {
         definePackageIfNecessary(name);
      }
      catch (IllegalArgumentException ex) {
         // Tolerate race condition due to being parallel capable
         if (getPackage(name) == null) {
            // This should never happen as the IllegalArgumentException indicates
            // that the package has already been defined and, therefore,
            // getPackage(name) should not return null.
            throw new AssertionError("Package " + name + " has already been defined but it could not be found");
         }
      }
      // 调用父类加载class
      return super.loadClass(name, resolve);
   }
   finally {
      Handler.setUseFastConnectionExceptions(false);
   }
}
```

从上面可以看出，LaunchedURLClassLoader加载class，用的是UrlClassLoader中的loadClass，但是这里的definePackageIfNecessary目前我还没有搞懂。

## 总结

Spring-boot Laoder定义了一套可执行Jar的标准规则，然后使用JarLunch或者WarLunch来启动，这俩个是最常用的，流程基本上类似。Jar包的URL路径使用自定义的规则并且这个规则需要使用org.springframework.boot.loader.jar.Handler处理器处理。
