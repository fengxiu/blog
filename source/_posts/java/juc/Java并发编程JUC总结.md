---
title: Java并发编程JUC总结
abbrlink: 59504c8e
categories:
  - java
  - juc
tags:
  - 总结
date: 2019-07-07 09:45:06
---
## 前言

学习了一段时间JUC，也就是java对并发做的一些工具类，但是虽然学习完了，但是还是觉得没有在脑子中形成一个系统，所以这里对我学习的并发包做一个整理和总结，一方面是对自己学习的总结，另一方面也是帮助自己以后能够快速的进行查阅。

## JSR 166及J.U.C

### 什么是JSR

JSR，全称 Java Specification Requests， 即Java规范提案， 主要是用于向JCP(Java Community Process)提出新增标准化技术规范的正式请求。每次JAVA版本更新都会有对应的JSR更新，比如在Java 8版本中，其新特性Lambda表达式对应的是JSR 335，新的日期和时间API对应的是JSR 310。

### 什么是JSR 166

当然，本文的关注点仅仅是JSR 166，它是一个关于Java并发编程的规范提案，在JDK中，该规范由java.util.concurrent包实现，是在JDK 5.0的时候被引入的；

另外JDK6引入Deques、Navigable collections，对应的是JSR 166x，JDK7引入fork-join框架，用于并行执行任务，对应的是JSR 166y。

### 什么是J.U.C

即java.util.concurrent的缩写，该包参考自EDU.oswego.cs.dl.util.concurrent，是JSR 166标准规范的一个实现；

### 膜拜

那么，JSR 166以及J.U.C包的作者是谁呢，没错，就是Doug Lea大神，挺牛逼的，大神级别任务，贴张照片膜拜下。
![879896-20160624160226063-830249727](/images/879896-20160624160226063-830249727.jpg)
<!-- more -->
## 什么是Executor框架

简单的说，就是一个任务的执行和调度框架，涉及的类如下图所示：
![Executor 框架](/images/pasted-345.png)
其中，最顶层是Executor接口，它的定义很简单，一个用于执行任务的execute方法，如下所示：

``` java
public interface Executor {
    void execute(Runnable command);
}
```

但是我们平常使用的最多的是ExecutorService接口，因为这个接口定义了比较全的方法，下面是ExecutorService的官方解释

``` txt
一个Executor，提供管理终止的方法和可以生成Future以跟踪一个或多个异步任务进度的方法。
可以关闭ExecutorService，这将导致它拒绝新任务。提供了两种不同的方法来关闭ExecutorService。 shutdown（）方法将允许先前提交的任务在终止之前执行，而shutdownNow（）方法则阻止等待任务启动并尝试停止当前正在执行的任务。终止时，执行程序没有正在执行的任务，没有等待执行的任务，也没有任何新任务可以提交。应关闭未使用的ExecutorService以允许回收其资源。

方法提交通过创建和返回可用于取消执行和/或等待完成的Future来扩展基本方法Executor.execute（Runnable）。方法invokeAny和invokeAll执行最常用的批量执行形式，执行一组任务，然后等待至少一个或全部完成。 （类ExecutorCompletionService可用于编写这些方法的自定义变体。）
```

具体的接口如下

``` java
public interface ExecutorService extends Executor {

    void shutdown();

    List<Runnable> shutdownNow();

    boolean isShutdown();

    boolean isTerminated();

    boolean awaitTermination(long timeout, TimeUnit unit)
        throws InterruptedException;

    <T> Future<T> submit(Callable<T> task);

    <T> Future<T> submit(Runnable task, T result);

    Future<?> submit(Runnable task);

    <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks)
        throws InterruptedException;

    <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks,
                                  long timeout, TimeUnit unit)
        throws InterruptedException;

    <T> T invokeAny(Collection<? extends Callable<T>> tasks)
        throws InterruptedException, ExecutionException;

    <T> T invokeAny(Collection<? extends Callable<T>> tasks,
                    long timeout, TimeUnit unit)
        throws InterruptedException, ExecutionException, TimeoutException;
}

```

ScheduledExecutorService可用来做定时任务，具体可以看下面的文章。
另外，我们还可以看到一个Executors类，它是一个工具类（有点类似集合框架的Collections类），用于创建ExecutorService、ScheduledExecutorService、ThreadFactory 和 Callable对象。

**优点：**
任务的提交过程与执行过程解耦，用户只需定义好任务提交，具体如何执行，什么时候执行不需要关心；

**典型步骤：**
定义好任务（如Callable对象），把它提交给ExecutorService（如线程池）去执行，得到Future对象，然后调用Future的get方法等待执行结果即可。

**什么是任务：**
实现Callable接口或Runnable接口的类，其实例就可以成为一个任务提交给ExecutorService去执行；

其中Callable任务可以返回执行结果，Runnable任务无返回结果；

**什么是线程池**
通过Executors工具类可以创建各种类型的线程池，如下为常见的四种：

* newCachedThreadPool ：大小不受限，当线程释放时，可重用该线程；
* newFixedThreadPool ：大小固定，无可用线程时，任务需等待，直到有可用线程；
* newSingleThreadExecutor ：创建一个单线程，任务会按顺序依次执行；
* newScheduledThreadPool：创建一个定长线程池，支持定时及周期性任务执行

举个例子（不完整，仅仅演示流程）：

``` txt
ExecutorService executor = Executors.newCachedThreadPool();//创建线程池
Task task = new Task(); //创建Callable任务
Future<Integer> result = executor.submit(task);//提交任务给线程池执行
result.get()；//等待执行结果; 可以传入等待时间参数，指定时间内没返回的话，直接结束
```

**补充：批量任务的执行方式**
**方式一**:首先定义任务集合，然后定义Future集合用于存放执行结果，执行任务，最后遍历Future集合获取结果；

**优点**：可以依次得到有序的结果；
**缺点**：不能及时获取已完成任务的执行结果；

**方式二**：首先定义任务集合，通过CompletionService包装ExecutorService，执行任务，然后调用其take()方法去取Future对象

**优点**：及时得到已完成任务的执行结果
**缺点**：不能依次得到结果
这里稍微解释下，在方式一中，从集合中遍历的每个Future对象并不一定处于完成状态，这时调用get()方法就会被阻塞住，所以后面的任务即使已完成也不能得到结果；而方式二中，CompletionService的实现是维护一个保存Future对象的BlockingQueue，只有当这个Future对象状态是结束的时候，才会加入到这个Queue中，所以调用take()能从阻塞队列中拿到最新的已完成任务的结果；

**具体分析文章列表：**

1. [java多线程系列-JUC线程池之 01 线程池架构](/posts/984191f2/)
2. [Java多线程系列-JUC线程池之02 ThreadPoolExecutor 执行流程分析](/posts/ca60f1d2)
3. [java多线程系列-JUC线程池之03 ThreadPoolExecutor 线程池的创建](/posts/a1d13062)
4. [java多线程系列-JUC线程池之04 Future、Callable和FutureTask分析](/posts/d4c4bc29)
5. [java多线程系列-JUC线程池之05 ScheduledThreadPoolExecutor](/posts/3f86c9f8)
6. [java多线程系列-JUC线程池之06 CompletionService](/posts/fac740ad)

## 参考

1. [JAVA并发编程J.U.C学习总结](https://www.cnblogs.com/chenpi/p/5614290.html)