---
title: java多线程系列01基本概念以及实现方式
tags:
  - 并发
categories:
  - java
  - thread
abbrlink: 51baaf1d
date: 2018-07-11 16:12:00
updated: 2018-07-11 16:12:00
---

本篇文章主要针对线程的基本概念进行介绍，然后看下java中的具体实现

要理解线程，需要先看下什么是进程，进程是对运行时程序的封装，是系统进行资源调度和分配的的基本单位，实现了操作系统的并发；

线程是进程的子任务，是CPU调度和分派的基本单位，用于保证程序的实时性，实现进程内部的并发；线程是操作系统可识别的最小执行和调度单位。每个线程都独自占用一个虚拟处理器：独自的寄存器组，指令计数器和处理器状态。每个线程完成不同的任务，但是共享同一地址空间（也就是同样的动态内存，映射文件，目标代码等等），打开的文件队列和其他内核资源。

<!-- more -->

线程的基本状态如下：
![线程状态](https://cdn.jsdelivr.net/gh/fengxiu/img/20220422114817.png)

线程共包括以下5种状态。

1. **新建状态(New)**  : 线程对象被创建后，就进入了新建状态。例如`Thread thread = new Thread()`。
2. **就绪状态(Runnable)**: 也被称为可执行状态。线程对象被创建后，其它线程调用了该对象的start()方法，从而来启动该线程。例如`thread.start()`处于就绪状态的线程，随时可能被CPU调度执行。
3. **运行状态(Running)** : 线程获取CPU权限进行执行。需要注意的是，线程只能从就绪状态进入到运行状态。
4. **阻塞状态(Blocked)**  : 阻塞状态是线程因为某种原因放弃CPU使用权，暂时停止运行。直到线程进入就绪状态，才有机会转到运行状态。阻塞的情况分三种：
   1. 等待阻塞 -- 通过调用线程的wait()方法，让线程等待某工作的完成。
   2. 同步阻塞 -- 线程在获取synchronized同步锁失败(因为锁被其它线程所占用)，它会进入同步阻塞状态。
   3. 其他阻塞 -- 通过调用线程的sleep()或join()或发出了I/O请求时，线程会进入到阻塞状态。当sleep()状态超时、join()等待线程终止或者超时、或者I/O处理完毕时，线程重新转入就绪状态。
5. **死亡状态(Dead)**: 线程执行完了或者因异常退出了run()方法，该线程结束生命周期。需要注意的是，**线程一旦进入死亡状态就不能在调用start()方法来让线程恢复运行。**

这5种状态涉及到的内容包括Object类, Thread和synchronized关键字。这些内容我们会在后面的章节中逐个进行学习。

**Object类**，定义了wait(), notify(), notifyAll()等休眠/唤醒函数。
**Thread类**，定义了一系列的线程操作函数。例如，sleep()休眠函数, interrupt()中断函数, getName()获取线程名称等。
**synchronized**，是关键字；它区分为synchronized代码块和synchronized方法。synchronized的作用是让线程获取对象的同步锁。

在后面详细介绍wait(),notify()等方法时，我们会分析为什么**wait(), notify()等方法要定义在Object类，而不是Thread类中**。

## 线程使用方式

有三种使用线程的方法:

* 实现 Runnable 接口；
* 实现 Callable 接口；
* 继承 Thread 类。

实现Runnable和Callable接口的类只能当做一个可以在线程中运行的任务，不是真正意义上的线程，因此最后还需要通过 Thread来调用。可以说任务是通过线程驱动从而执行的。

**实现Runnable接口方式**
需要实现 run() 方法。
通过Thread调用start()方法来启动线程。

```java
public class MyRunnable implements Runnable {
    public void run() {
        // ...
    }
}
```

```java
     12345public static void main(String[] args) {
    MyRunnable instance = new MyRunnable();
    Thread thread = new Thread(instance);
    thread.start();
}
```
  
**实现Callable接口接口方式**

与Runnable相比，Callable可以有返回值，返回值通过FutureTask进行封装。 

```java
public class MyCallable implements Callable<Integer> {
    public Integer call() {
        return 123;
    }
}
```

```java
public static void main(String[] args) throws ExecutionException, InterruptedException {
    MyCallable mc = new MyCallable();
    FutureTask<Integer> ft = new FutureTask<>(mc);
    Thread thread = new Thread(ft);
    thread.start();
    System.out.println(ft.get());
}
```

**继承Thread类**
同样也是需要实现run()方法，因为Thread类也实现了 Runable接口。 当调用start()方法启动一个线程时，虚拟机会将该线程放入就绪队列中等待被调度，当一个线程被调度时会执行该线程的 run() 方法。

```java
public class MyThread extends Thread {
    public void run() {
        // ...
    }
}
```
  
```java
     12345public static void main(String[] args) {
    MyThread mt = new MyThread();
    mt.start();
}
```

**实现接口VS继承Thread**：实现接口会更好一些，主要有以下俩方面考虑:

1. Java不支持多重继承，因此继承了Thread类就无法继承其它类，但是可以实现多个接口；
2. 类可能只要求可执行就行，继承整个Thread类开销过大。

**Thread中start()和run()的区别**
**start()** : 它的作用是启动一个新线程，新线程会执行相应的run()方法。start()不能被重复调用。

 **run()** : run()就和普通的成员方法一样，可以被重复调用。单独调用run()的话，会在当前线程中执行run()，而并不会启动新线程！

## 参考

1. [进程和线程的概念、区别及进程线程间通信](https://cloud.tencent.com/developer/article/1688297)