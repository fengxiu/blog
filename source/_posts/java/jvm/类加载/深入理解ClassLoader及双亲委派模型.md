---
title: 深入理解类加载以及其实现ClassLoader
abbrlink: 2735b28b
categories:
  - java
  - jvm
tags:
  - 类加载
date: 2019-07-09 21:07:04
updated: 2019-07-09 21:07:04
---

应用开发完成后，会产生大量的Class文件，这些文件都是静态的，最终都需要加载到虚拟机中之后才能被运行和使用。而虚拟机如何加载这些Class文件，Class文件中的信息进入到虚拟机后会发生什么变化，这些都是本文将要了解的内容。 Java虚拟机把描述类的数据从Class文件加载到内存，并对数据进行校验、转换解析和初始化，最终形成可以被虚拟机直接使用的Java类型，这个过程被称作虚拟机的类加载机制。

具体的实现就是ClassLoader，翻译过来就是类加载器，普通的java开发者其实用到的不多，但对于某些框架开发者来说却非常常见。理解ClassLoader的加载机制，也有利于我们编写出更高效的代码。ClassLoader的具体作用就是将class文件加载到jvm虚拟机中去，程序就可以正确运行了。但是，jvm启动的时候，并不会一次性加载所有的class文件，而是根据需要去动态加载。想想也是的，一次性加载那么多jar包那么多class，那内存不崩溃。本文的目的也是学习ClassLoader这种加载机制。

因此本篇文章将会详细分析类加载整个过程，以及java代码中已存在的各种类加载器。这样我们便可以做到不仅仅在概念上，也可以能够简单的运用。
<!-- more -->

## 类加载过程

一个类型从被加载到虚拟机内存中开始，到卸载出内存为止，它的整个生命周期将会经历加载 （Loading）、验证（Verification）、准备（Preparation）、解析（Resolution）、初始化 （Initialization）、使用（Using）和卸载（Unloading）七个阶段，其中验证、准备、解析三个部分统称为连接（Linking）。这七个阶段的发生顺序如下图所示。

![雷家挨过程](https://raw.githubusercontent.com/fengxiu/img/master/20220419173111.png)

### 类加载的时机

关于在什么情况下需要开始类加载过程的第一个阶段“加载”，《Java虚拟机规范》中并没有进行强制约束，这点可以交给虚拟机的具体实现来自由把握。但是对于初始化阶段，《Java虚拟机规范》 则是严格规定了有且只有六种情况必须立即对类进行“初始化”（而加载、验证、准备自然需要在此之前开始），这里就不罗列具体的情形，可以简单的理解类使用前必须要经过加载。

### 类加载过程

加载、验证、准备、初始化和卸载这五个阶段的顺序是确定的，类型的加载过程必须按照这种顺序按部就班地开始，而解析阶段则不一定：它在某些情况下可以在初始化阶段之后再开始， 这是为了支持Java语言的运行时绑定特性（也称为动态绑定或晚期绑定）。请注意，这里笔者写的是按部就班地“开始”，而不是按部就班地“进行”或按部就班地“完成”，强调这点是因为这些阶段通常都是互相交叉地混合进行的，会在一个阶段执行的过程中调用、激活另一个阶段。

下面具体来看类加载的整个过程，也就是上面所说的连接

#### 加载

两个看起来很相似的名词。在加载阶段，Java虚拟机需要完成以下三件事情：

1. 通过一个类的全限定名来获取定义此类的二进制字节流。
2. 将这个字节流所代表的静态存储结构转化为方法区的运行时数据结构。
3. 在内存中生成一个代表这个类的java.lang.Class对象，作为方法区这个类的各种数据的访问入口。

总结起来就是需要找到对应的文件，并在内存中生成Class对象

#### 验证

验证是连接阶段的第一步，这一阶段的目的是确保Class文件的字节流中包含的信息符合《Java虚 拟机规范》的全部约束要求，保证这些信息被当作代码运行后不会危害虚拟机自身的安全。

主要验证下面四个方面

1. 文件格式验证：验证字节流是否符合Class文件格式的规范，并且能被当前版本的虚拟机处理
2. 元数据验证：对字节码描述的信息进行语义分析，以保证其描述的信息符合《Java语言规范》的要 求，
3. 字节码验证： 是整个验证过程中最复杂的一个阶段，主要目的是通过数据流分析和控制流分析，确定程序语义是合法的、符合逻辑的。
4. 符号引用验证：最后一个阶段的校验行为发生在虚拟机将符号引用转化为直接引用的时候，这个转化动作将在连接的第三阶段——解析阶段中发生。符号引用验证可以看作是对类自身以外（常量池中的各种符号引用）的各类信息进行匹配性校验，通俗来说就是，该类是否缺少或者被禁止访问它依赖的某些外部类、方法、字段等资源。

#### 准备

准备阶段是正式为类中定义的变量（即静态变量，被static修饰的变量）分配内存并设置类变量初始值的阶段，从概念上讲，这些变量所使用的内存都应当在方法区中进行分配，但必须注意到方法区 本身是一个逻辑上的区域，在JDK7及之前，HotSpot使用永久代来实现方法区时，实现是完全符合这种逻辑概念的；而在JDK8及之后，类变量则会随着Class对象一起存放在Java堆中，这时候“类变量在方法区”就完全是一种对逻辑概念的表述了。 关于准备阶段，还有两个容易产生混淆的概念笔者需要着重强调，首先是这时候进行内存分配的仅包括类变量，而不包括实例变量，实例变量将会在对象实例化时随着对象一起分配在Java堆中。其次是这里所说的初始值“通常情况”下是数据类型的零值。

#### 解析

解析阶段是Java虚拟机将常量池内的符号引用替换为直接引用的过程，

* 符号引用（Symbolic References）：符号引用以一组符号来描述所引用的目标，符号可以是任何形式的字面量，只要使用时能无歧义地定位到目标即可。符号引用与虚拟机实现的内存布局无关，引 用的目标并不一定是已经加载到虚拟机内存当中的内容。各种虚拟机实现的内存布局可以各不相同， 但是它们能接受的符号引用必须都是一致的，因为符号引用的字面量形式明确定义在《Java虚拟机规 范》的Class文件格式中。 
* 直接引用（Direct References）：直接引用是可以直接指向目标的指针、相对偏移量或者是一个能 间接定位到目标的句柄。直接引用是和虚拟机实现的内存布局直接相关的，同一个符号引用在不同虚 拟机实例上翻译出来的直接引用一般不会相同。如果有了直接引用，那引用的目标必定已经在虚拟机 的内存中存在。

#### 初始化

类的初始化阶段是类加载过程的最后一个步骤，之前介绍的几个类加载的动作里，除了在加载阶段用户应用程序可以通过自定义类加载器的方式局部参与外，其余动作都完全由Java虚拟机来主导控制。直到初始化阶段，Java虚拟机才真正开始执行类中编写的Java程序代码，将主导权移交给应用程序。进行准备阶段时，变量已经赋过一次系统要求的初始零值，而在初始化阶段，则会根据程序员通过程序编码制定的主观计划去初始化类变量和其他资源。我们也可以从另外一种更直接的形式来表达：初始化阶段就是执行类构造器`<clinit>`()方法的过程。`<clinit>`()并不是程序员在Java代码中直接编写的方法，它是Javac编译器的自动生成物，但我们非常有必要了解这个方法具体是如何产生的，以及 `<clinit>`()方法执行过程中各种可能会影响程序运行行为的细节，这部分比起其他类加载过程更贴近于 普通的程序开发人员的实际工作。

* `<clinit>`()方法是由编译器自动收集类中的所有类变量的赋值动作和静态语句块（static{}块）中的 语句合并产生的，编译器收集的顺序是由语句在源文件中出现的顺序决定的，静态语句块中只能访问 到定义在静态语句块之前的变量，定义在它之后的变量，在前面的静态语句块可以赋值，但是不能访 问，如代码清单7-5所示。
* `<clinit>`()方法与类的构造函数（即在虚拟机视角中的实例构造器<init>()方法）不同，它不需要显 式地调用父类构造器，Java虚拟机会保证在子类的`<clinit>`()方法执行前，父类的`<clinit>`()方法已经执行 完毕。因此在Java虚拟机中第一个被执行的`<clinit>`()方法的类型肯定是java.lang.Object。 
* 由于父类的`<clinit>`()方法先执行，也就意味着父类中定义的静态语句块要优先于子类的变量赋值操作。
* `<clinit>`()方法对于类或接口来说并不是必需的，如果一个类中没有静态语句块，也没有对变量的赋值操作，那么编译器可以不为这个类生成`<clinit>`()方法。
* 接口中不能使用静态语句块，但仍然有变量初始化的赋值操作，因此接口与类一样都会生成 `<clinit>`()方法。但接口与类不同的是，执行接口的`<clinit>`()方法不需要先执行父接口的`<clinit>`()方法， 因为只有当父接口中定义的变量被使用时，父接口才会被初始化。此外，接口的实现类在初始化时也 一样不会执行接口的`<clinit>`()方法。
* Java虚拟机必须保证一个类的`<clinit>`()方法在多线程环境中被正确地加锁同步，如果多个线程同 时去初始化一个类，那么只会有其中一个线程去执行这个类的`<clinit>`()方法，其他线程都需要阻塞等待，直到活动线程执行完毕`<clinit>`()方法。如果在一个类的`<clinit>`()方法中有耗时很长的操作，那就可能造成多个进程阻塞，在实际应用中这种阻塞往往是很隐蔽的。

## 类加载器简单介绍

类加载器就是对上面描述类加载整个过程的实现，首先看下类加载器的整个继承体系

![类加载器继承体系](https://raw.githubusercontent.com/fengxiu/img/master/20170211112754197.png)

从上面可以看到平常我们经常听到到的扩展类加载器，系统类加载器等等，下面会对上面的类加载器一一进行介绍。

### 启动（Bootstrap）类加载器

启动类加载器主要加载的是JVM自身需要的类，这个类加载使用C++语言实现的，是虚拟机自身的一部分，它负责将**JAVA_HOME/lib**路径下的核心类库或`-Xbootclasspath`参数指定的路径下的jar包加载到内存中，注意的一点是，由于虚拟机是按照文件名识别加载jar包的，如rt.jar，如果文件名不被虚拟机识别，即使把jar包丢到lib目录下也是没有作用的(出于安全考虑，Bootstrap启动类加载器只加载包名为java、javax、sun等开头的类)。

### 扩展（Extension）类加载器

扩展类加载器是指Sun公司(已被Oracle收购)实现`sun.misc.Launcher$ExtClassLoader`类，由Java语言实现的，是Launcher的静态内部类，它负责加载**JAVA_HOME/lib/ext**目录下或者由系统变量`-Djava.ext.dir`指定位路径中的类库，开发者可以直接使用标准扩展类加载器。

### 系统（System）类加载器

也称应用程序加载器，是指Sun公司实现的`sun.misc.Launcher$AppClassLoader`。它负责加载系统类路径`java -classpath`或`-Djava.class.path`指定路径下的类库，也就是我们经常用到的classpath路径，开发者可以直接使用系统类加载器，一般情况下该类加载是程序中默认的类加载器，通过`ClassLoader#getSystemClassLoader()`方法可以获取到该类加载器。

在Java的日常应用程序开发中，类的加载几乎是由上述3种类加载器相互配合执行的，在必要时，我们还可以自定义类加载器，需要注意的是，Java虚拟机对class文件采用的是按需加载的方式，也就是说当需要使用该类时才会将它的class文件加载到内存生成class对象，而且加载某个类的class文件时，Java虚拟机采用的是双亲委派模式即把请求交由父类处理，它一种任务委派模式，下面我们进一步了解它。

## 双亲委派模型

双亲委派模式要求除了顶层的启动类加载器外，其余的类加载器都应当有自己的父类加载器，**请注意双亲委派模式中的父子关系并非通常所说的类继承关系，而是采用组合关系来复用父类加载器的相关代码**，类加载器间的关系如下：

![](https://raw.githubusercontent.com/fengxiu/img/master/20180428160028362.png)

双亲委派模式是在Java 1.2后引入的，其工作原理的是，如果一个类加载器收到了类加载请求，它并不会自己先去加载，而是把这个请求委托给父类的加载器去执行，如果父类加载器还存在父类加载器，则进一步向上委托，依次递归，请求最终将到达顶层的启动类加载器，如果父类加载器可以完成类加载任务，就成功返回，倘若父类加载器无法完成此加载任务，子加载器才会尝试自己去加载，这就是双亲委派模式，即每个儿子都很懒，每次有活就丢给父亲去干，直到父亲说这件事我也干不了时，儿子自己想办法去完成，这不就是传说中的实力坑爹啊？那么采用这种模式有啥用呢?

### 双亲委派模式优势

采用双亲委派模式的是好处是Java类随着它的类加载器一起具备了一种带有优先级的层次关系，通过这种层级关可以避免类的重复加载，当父亲已经加载了该类时，就没有必要子ClassLoader再加载一次。其次是考虑到安全因素，java核心api中定义类型不会被随意替换，假设通过网络传递一个名为java.lang.Integer的类，通过双亲委托模式传递到启动类加载器，而启动类加载器在核心Java API发现这个名字的类，发现该类已被加载，并不会重新加载网络传递的过来的java.lang.Integer，而直接返回已加载过的Integer.class，这样便可以防止核心API库被随意篡改。可能你会想，如果我们在classpath路径下自定义一个名为java.lang.SingleInterge类(该类是胡编的)呢？该类并不存在java.lang中，经过双亲委托模式，传递到启动类加载器中，由于父类加载器路径下并没有该类，所以不会加载，将反向委托给子类加载器加载，最终会通过系统类加载器加载该类。但是这样做是不允许，因为java.lang是核心API包，需要访问权限，强制加载将会报出异常。
比如下面在java.lang包下自定义的一个类。

``` java
/**************************************
 *
 *      Author : zhangke
 *      Date   : 2019-07-11 22:27
 *      Desc   : 验证能否通过默认类加载器加载
 *              自定义的java.lang下面的类
 *
 ***************************************/
public class MyString {
    private int age = 0;

    public static void main(String[] args) {
        MyString myString = new MyString();
        System.out.println(myString.age);
    }
}
```

运行上面的代码，将会抛出异常：

``` java
Error: A JNI error has occurred, please check your installation and try again
Exception in thread "main" java.lang.SecurityException: Prohibited package name: java.lang
```

## 类加载源码分析

前面已经将类加载的基本信息进行了介绍，下面开始详细分析java中关于类加载的几个类，主要的类继承关系图如下：

![类加载类图](https://raw.githubusercontent.com/fengxiu/img/master/Xnip2019-07-11_22-42-28.jpg)
由于ClassLoader中函数众多，这里我们只关注我们比较常用的一些函数。

### ClassLoader

这个类是Java代码中实现类加载的根类，定义了类加载中需要使用的函数，下面就具体看看。

#### loadClass(String)

该方法加载指定名称（包括包名）的二进制类型，该方法在JDK1.2之后不再建议用户重写但用户可以直接调用该方法，loadClass()方法是ClassLoader类自己实现的，该方法中的逻辑就是双亲委派模式的实现，其源码如下，loadClass(String name, boolean resolve)是一个重载方法，resolve参数代表是否生成class对象的同时进行解析相关操作。

``` java

protected Class<?> loadClass(String name, boolean resolve)
      throws ClassNotFoundException
  {
      synchronized (getClassLoadingLock(name)) {
          // 先从缓存查找该class对象，找到就不用重新加载
          Class<?> c = findLoadedClass(name);
          if (c == null) {
              long t0 = System.nanoTime();
              try {
                  if (parent != null) {
                      //如果找不到，则委托给父类加载器去加载
                      c = parent.loadClass(name, false);
                  } else {
                  //如果没有父类，则委托给启动加载器去加载
                      c = findBootstrapClassOrNull(name);
                  }
              } catch (ClassNotFoundException e) {
                  // ClassNotFoundException thrown if class not found
                  // from the non-null parent class loader
              }

              if (c == null) {
                  // If still not found, then invoke findClass in order
                  // 如果都没有找到，则通过自定义实现的findClass去查找并加载
                  c = findClass(name);

                  // this is the defining class loader; record the stats
                  sun.misc.PerfCounter.getParentDelegationTime().addTime(t1 - t0);
                  sun.misc.PerfCounter.getFindClassTime().addElapsedTimeFrom(t1);
                  sun.misc.PerfCounter.getFindClasses().increment();
              }
          }
          if (resolve) {//是否需要在加载时进行解析
              resolveClass(c);
          }
          return c;
      }
  }
```

#### findClass(String)
在JDK1.2之前，在自定义类加载时，总会去继承ClassLoader类并重写loadClass方法，从而实现自定义的类加载类，但是在JDK1.2之后已不再建议用户去覆盖loadClass()方法，而是建议把自定义的类加载逻辑写在findClass()方法中，从前面的分析可知，findClass()方法是在loadClass()方法中被调用的，当loadClass()方法中父加载器加载失败后，则会调用自己的findClass()方法来完成类加载，这样就可以保证自定义的类加载器也符合双亲委托模式。需要注意的是ClassLoader类中并没有实现findClass()方法的具体代码逻辑，取而代之的是抛出ClassNotFoundException异常，同时应该知道的是findClass方法通常是和defineClass方法一起使用的(稍后会分析)，ClassLoader类中findClass()方法源码如下：

``` java
//直接抛出异常
protected Class<?> findClass(String name) throws ClassNotFoundException {
        throw new ClassNotFoundException(name);
}
```

#### defineClass(byte[] b, int off, int len)

defineClass()方法是用来将byte字节流解析成JVM能够识别的Class对象(ClassLoader中已实现该方法逻辑)，通过这个方法不仅能够通过class文件实例化class对象，也可以通过其他方式实例化class对象，如通过网络接收一个类的字节码，然后转换为byte字节流创建对应的Class对象，defineClass()方法通常与findClass()方法一起使用，一般情况下，在自定义类加载器时，会直接覆盖ClassLoader的findClass()方法并编写加载规则，取得要加载类的字节码后转换成流，然后调用defineClass()方法生成类的Class对象，简单例子如下：

``` java
protected Class<?> findClass(String name) throws ClassNotFoundException {
      // 获取类的字节数组
      byte[] classData = getClassData(name);  
      if (classData == null) {
          throw new ClassNotFoundException();
      } else {
         //使用defineClass生成class对象
          return defineClass(name, classData, 0, classData.length);
      }
  }
```

需要注意的是，如果直接调用defineClass()方法生成类的Class对象，这个类的Class对象并没有解析(也可以理解为链接阶段，毕竟解析是链接的最后一步)，其解析操作需要等待初始化阶段进行。

#### resolveClass(Class≺?≻ c)

使用该方法可以完成类的Class对象创建也同时被解析。前面我们说链接阶段主要是对字节码进行验证，为类变量分配内存并设置初始值同时将字节码文件中的符号引用转换为直接引用。


### SercureClassLoader

上述4个方法是ClassLoader类中的比较重要的方法，也是我们可能会经常用到的方法。接着下面是SercureClassLoader扩展了ClassLoader，新增了几个与使用相关的代码源(对代码源的位置及其证书的验证)和权限定义类验证(主要指对class源码的访问权限)的方法，一般我们不会直接跟这个类打交道。

### UrlClassLoader

在我们代码中，更多是URLClassLoader类关联，前面说过，ClassLoader是一个抽象类，很多方法是空的没有实现，比如findClass()、findResource()等。而URLClassLoader这个实现类为这些方法提供了具体的实现，并新增了URLClassPath类协助取得Class字节码流等功能，在编写自定义类加载器时，如果没有太过于复杂的需求，可以直接继承URLClassLoader类，这样就可以避免自己去编写findClass()方法及其获取字节码流的方式，使自定义类加载器编写更加简洁，下面是URLClassLoader的类图(利用IDEA生成的类图)

![](https://raw.githubusercontent.com/fengxiu/img/master/20170620232230987.png)

从类图结构看出URLClassLoader中存在一个URLClassPath类，通过这个类就可以找到要加载的字节码流，也就是说URLClassPath类负责找到要加载的字节码，再读取成字节流，最后通过defineClass()方法创建类的Class对象。
从URLClassLoader类的结构图可以看出其构造方法都有一个必须传递的参数URL[\]，该参数的元素是代表字节码文件的路径,换句话说在创建URLClassLoader对象时必须要指定这个类加载器的到那个目录下找class文件。同时也应该注意URL[]也是URLClassPath类的必传参数，在创建URLClassPath对象时，会根据传递过来的URL数组中的路径判断是文件还是jar包，然后根据不同的路径创建FileLoader或者JarLoader或默认Loader类去加载相应路径下的class文件，而当JVM调用findClass()方法时，就由这3个加载器中的一个将class文件的字节码流加载到内存中，最后利用字节码流创建类的class对象。**请记住，如果我们在定义类加载器时选择继承ClassLoader类而非URLClassLoader，必须手动编写findclass()方法的加载逻辑以及获取字节码流的逻辑。**

### ExtClassLoader 和 AppClassLoader

了解完URLClassLoader后接着看看剩余的两个类加载器，即拓展类加载器ExtClassLoader和系统类加载器AppClassLoader，这两个类都继承自URLClassLoader，是`sun.misc.Launcher`的静态内部类。`sun.misc.Launcher`主要被系统用于启动主应用程序，ExtClassLoader和AppClassLoader都是由sun.misc.Launcher创建的，如果想要，详细了解Launcher这个类，可以看这篇文章[main函数启动流程](/archives/ddfbbdfc.html)其类主要类结构如下：

![](https://raw.githubusercontent.com/fengxiu/img/master/20170621075845201.png)

它们间的关系正如前面所阐述的那样，同时我们发现ExtClassLoader并没有重写loadClass()方法，这足矣说明其遵循双亲委派模式，而AppClassLoader重载了loadCass()方法，但最终调用的还是父类loadClass()方法，因此依然遵守双亲委派模式，重载方法源码如下：

``` java
 /**
  * Override loadClass 方法，新增包权限检测功能
  */
public Class loadClass(String name, boolean resolve)
     throws ClassNotFoundException{

     int i = name.lastIndexOf('.');
     if (i != -1) {
         SecurityManager sm = System.getSecurityManager();
         if (sm != null) {
             sm.checkPackageAccess(name.substring(0, i));
         }
     }
     //依然调用父类的方法
     return (super.loadClass(name, resolve));
}
```

其实无论是ExtClassLoader还是AppClassLoader都继承URLClassLoader类，因此它们都遵守双亲委托模型，这点是毋庸置疑的。到此我们对ClassLoader、URLClassLoader、ExtClassLoader、AppClassLoader以及Launcher类间的关系有了比较清晰的了解，同时对一些主要的方法也有一定的认识，这里并没有对这些类的源码进行详细的分析，毕竟没有那个必要，因为我们主要弄得类与类间的关系和常用的方法同时搞清楚双亲委托模式的实现过程，为编写自定义类加载器做铺垫就足够了。前面出现了很多父类加载器的说法，但每个类加载器的父类到底是谁，一直没有阐明，下面我们就通过代码验证的方式来阐明这答案。

## 类加载器间的关系

我们进一步了解类加载器间的关系(并非指继承关系)，主要可以分为以下4点

1. 启动类加载器，由C++实现，没有父类。

2. 拓展类加载器(ExtClassLoader)，由Java语言实现，父类加载器为null

3. 系统类加载器(AppClassLoader)，由Java语言实现，父类加载器为ExtClassLoader

4. 自定义类加载器，父类加载器肯定为AppClassLoader。

下面我们通过程序来验证上述阐述的观点

``` java

//自定义ClassLoader，完整代码稍后分析
class FileClassLoader extends  ClassLoader{

    private String rootDir;

    public FileClassLoader(String rootDir) {
        this.rootDir = rootDir;
    }
    // 编写获取类的字节码并创建class对象的逻辑
    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
       //...省略逻辑代码
    }
    //编写读取字节流的方法
    private byte[] getClassData(String className) {
        // 读取类文件的字节
        //省略代码....
    }
}

public class ClassLoaderTest {

    public static void main(String[] args) throws ClassNotFoundException {

              FileClassLoader loader1 = new FileClassLoader(rootDir);
              System.out.println("自定义类加载器的父加载器: "+loader1.getParent());
              System.out.println("系统默认的AppClassLoader: "+ClassLoader.getSystemClassLoader());
              System.out.println("AppClassLoader的父类加载器: "+ClassLoader.getSystemClassLoader().getParent());
              System.out.println("ExtClassLoader的父类加载器: "+ClassLoader.getSystemClassLoader().getParent().getParent());
            /**
            输出结果:
                自定义类加载器的父加载器: sun.misc.Launcher$AppClassLoader@29453f44
                系统默认的AppClassLoader: sun.misc.Launcher$AppClassLoader@29453f44
                AppClassLoader的父类加载器: sun.misc.Launcher$ExtClassLoader@6f94fa3e
                ExtClassLoader的父类加载器: null
            */

    }
}
```

代码中，我们自定义了一个FileClassLoader，这里我们继承了ClassLoader而非URLClassLoader,因此需要自己编写findClass()方法逻辑以及加载字节码的逻辑，关于自定义类加载器我们稍后会分析，这里仅需要知道FileClassLoader是自定义加载器即可，接着在main方法中，通过ClassLoader.getSystemClassLoader()获取到系统默认类加载器，通过获取其父类加载器及其父父类加载器，同时还获取了自定义类加载器的父类加载器,最终输出结果正如我们所预料的，AppClassLoader的父类加载器为ExtClassLoader，而ExtClassLoader没有父类加载器。显然ExtClassLoader的父类为null，而AppClassLoader的父加载器为ExtClassLoader，所有自定义的类加载器其父加载器只会是AppClassLoader，注意这里所指的父类并不是Java继承关系中的那种父子关系,而是组合的关系。

## 编写自己的类加载器

**class文件的显示加载与隐式加载的概念**
所谓class文件的显示加载与隐式加载的方式是指JVM加载class文件到内存的方式，显示加载指的是在代码中通过调用ClassLoader加载class对象，如直接使用`Class.forName(name)`或`this.getClass().getClassLoader().loadClass()`加载class对象。

而隐式加载则是不直接在代码中调用ClassLoader的方法加载class对象，而是通过虚拟机自动加载到内存中，如在加载某个类的class文件时，该类的class文件中引用了另外一个类的对象，此时额外引用的类将通过JVM自动加载到内存中。在日常开发以上两种方式一般会混合使用，这里我们知道有这么回事即可。

通过前面的分析可知，实现自定义类加载器需要继承ClassLoader或者URLClassLoader，继承ClassLoader则需要自己重写findClass()方法并编写加载逻辑，继承URLClassLoader则可以省去编写findClass()方法以及class文件加载转换成字节码流的代码。那么编写自定义类加载器的意义何在呢？

1. 当class文件不在ClassPath路径下，默认系统类加载器无法找到该class文件，在这种情况下我们需要实现一个自定义的ClassLoader来加载特定路径下的class文件生成class对象。

2. 当一个class文件是通过网络传输并且可能会进行相应的加密操作时，需要先对class文件进行相应的解密后再加载到JVM内存中，这种情况下也需要编写自定义的ClassLoader并实现相应的逻辑。

3. 当需要实现热部署功能时(一个class文件通过不同的类加载器产生不同class对象从而实现热部署功能)，需要实现自定义ClassLoader的逻辑。

### 自定义File类加载器

这里我们继承URLClassLoader实现自定义的特定路径下的文件类加载器并加载编译后DemoObj.class，代码如下：

``` java

 class FileUrlClassLoader extends URLClassLoader {

    public FileUrlClassLoader(URL[] urls, ClassLoader parent) {
        super(urls, parent);
    }

    public FileUrlClassLoader(URL[] urls) {
        super(urls);
    }

    public FileUrlClassLoader(URL[] urls, ClassLoader parent, URLStreamHandlerFactory factory) {
        super(urls, parent, factory);
    }


    public static void main(String[] args) throws ClassNotFoundException, MalformedURLException {
        String rootDir="替换成自己的路径";
        //创建自定义文件类加载器
        File file = new File(rootDir);
        //File to URI
        URI uri=file.toURI();
        URL[] urls={uri.toURL()};

        FileUrlClassLoader loader = new FileUrlClassLoader(urls);

        try {
            //加载指定的class文件
            Class<?> object1=loader.loadClass("DemoObj");
            System.out.println(object1.newInstance().toString());
            //输出结果:I am DemoObj
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

非常简洁除了需要重写构造器外无需编写findClass()方法及其class文件的字节流转换逻辑。

### 热部署类加载器

所谓的热部署就是利用同一个class文件不同的类加载器在内存创建出两个不同的class对象关于这点，可以看这篇文章[类加载之SystemDictionary:系统字典](/archives/53cf9979.html)。由于JVM在加载类之前会检测请求的类是否已加载过(即在loadClass()方法中调用findLoadedClass()方法)，如果被加载过，则直接从缓存获取，不会重新加载。注意同一个类加载器的实例和同一个class文件只能被加载器一次，多次加载将报错，因此我们实现的热部署必须让同一个class文件可以根据不同的类加载器重复加载，以实现所谓的热部署。实际上前面的实现的FileUrlClassLoader已具备这个功能，但前提是直接调用findClass()方法，而不是调用loadClass()方法，因为ClassLoader中loadClass()方法体中调用findLoadedClass()方法进行了检测是否已被加载，因此我们直接调用findClass()方法就可以绕过这个问题，当然也可以重新loadClass方法，但强烈不建议这么干。利用FileClassLoader类测试代码如下：

``` java

 public static void main(String[] args) throws ClassNotFoundException {
        String rootDir="自定义文件夹";
       //创建自定义文件类加载器
        File file = new File(rootDir);
        //File to URI
        URI uri=file.toURI();
        URL[] urls={uri.toURL()};
        //创建自定义文件类加载器
        FileUrlClassLoader loader1 =  new FileUrlClassLoader(urls);
        FileUrlClassLoader loader2 =  new FileUrlClassLoader(urls);

        try {
            //加载指定的class文件,调用loadClass()
            Class<?> object1=loader.loadClass("DemoObj");
            Class<?> object2=loader2.loadClass("DemoObj");

            System.out.println("loadClass->obj1:"+object1.hashCode());
            System.out.println("loadClass->obj2:"+object2.hashCode());

            //加载指定的class文件,直接调用findClass(),绕过检测机制，创建不同class对象。
            Class<?> object3=loader.findClass("DemoObj");
            Class<?> object4=loader2.findClass("DemoObj");

            System.out.println("loadClass->obj3:"+object3.hashCode());
            System.out.println("loadClass->obj4:"+object4.hashCode());

            /**
             * 输出结果:
             *  loadClass->obj1:644117698
             *  loadClass->obj2:644117698
             *  findClass->obj3:723074861
             *  findClass->obj4:895328852
             */

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
```

## 参考

1. [深入理解Java类加载器(ClassLoader)](https://blog.csdn.net/javazejian/article/details/73413292)
2. [URLClassLoader详解](https://blog.csdn.net/how_interesting/article/details/80091472)
