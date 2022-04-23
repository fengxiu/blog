---
title: Synchronize实现原理
tags:
  - 并发
  - lock 
categories:
  - java
  - lock
abbrlink: aae77c7e
date: 2019-02-28 17:55:00
updated: 2019-02-28 17:55:00
---

Synchronized是Java中解决并发问题的一种最常用的方法，也是使用相对容易的一种方法。本文主要介绍其实现原理，如果对使用不太清楚的，可以参考[java多线程系列02sychronized关键字](/archives/aa8f827d.html)。

<!-- more -->

## 锁实现原理

首先从一段代码开始讲起


```java
package com.paddx.test.concurrent;

public class SynchronizedDemo {
    public void method() {
        synchronized (this) {
            System.out.println("Method 1 start");
        }
    }
}
```

反编译结果：

![upload successful](/images/pasted-152.png)

主要关注的是monitorenter和monitorexit这两条指令的作用，我们直接参考JVM规范中描述：

**monitorenter**

```text

Each object is associated with a monitor. A monitor is locked if and only if it has an owner. The thread that executes monitorenter attempts to gain ownership of the monitor associated with objectref, as follows:
• If the entry count of the monitor associated with objectref is zero, the thread enters the monitor and sets its entry count to one. The thread is then the owner of the monitor.
• If the thread already owns the monitor associated with objectref, it reenters the monitor, incrementing its entry count.
• If another thread already owns the monitor associated with objectref, the thread blocks until the monitor's entry count is zero, then tries again to gain ownership.

```

这段话的大概意思为：

每个对象有一个监视器锁（monitor）。当monitor被占用时就会处于锁定状态，线程执行monitorenter指令时尝试获取monitor的所有权，过程如下：

1. 如果monitor的进入数为0，则该线程进入monitor，然后将进入数设置为1，该线程即为monitor的所有者。
2. 如果线程已经占有该monitor，只是重新进入，则进入monitor的进入数加1.
3. 如果其他线程已经占用了monitor，则该线程进入阻塞状态，直到monitor的进入数为0，再重新尝试获取monitor的所有权。

**monitorexit**

```
The thread that executes monitorexit must be the owner of the monitor associated with the instance referenced by objectref.
The thread decrements the entry count of the monitor associated with objectref. If as a result the value of the entry count is zero, the thread exits the monitor and is no longer its owner. Other threads that are blocking to enter the monitor are allowed to attempt to do so.
```

这段话的大概意思为：

1. 执行monitorexit的线程必须是objectref所对应的monitor的所有者。
2. 指令执行时，monitor的进入数减1，如果减1后进入数为0，那线程退出monitor，不再是这个monitor的所有者。其他被这个monitor阻塞的线程可以尝试去获取这个monitor的所有权。 


通过这两段描述，我们应该能很清楚的看出Synchronized的实现原理，Synchronized的语义底层是通过一个monitor对象来完成，wait/notify等方法也依赖于monitor对象，这就是为什么只有在同步的块或者方法中才能调用wait/notify等方法，否则会抛出java.lang.IllegalMonitorStateException的异常的原因。


另外底层是通过互斥锁来实现的，因此在获取锁的时候会是程序从用户态陷入内核态。


我们再来看一下同步方法的反编译结果，源代码：

```java
package com.paddx.test.concurrent;
 
 public class SynchronizedMethod {
     public synchronized void method() {
         System.out.println("Hello World!");
     }
 }
```

反编译结果：

![upload successful](/images/pasted-153.png)

从反编译的结果来看，方法的同步并没有通过指令monitorenter和monitorexit来完成（理论上其实也可以通过这两条指令来实现），不过相对于普通方法，其常量池中多了ACC_SYNCHRONIZED标示符。JVM就是根据该标示符来实现方法的同步的：当方法调用时，调用指令将会检查方法的 ACC_SYNCHRONIZED 访问标志是否被设置，如果设置了，执行线程将先获取monitor，获取成功之后才能执行方法体，方法执行完后再释放monitor。在方法执行期间，其他任何线程都无法再获得同一个monitor对象。 其实本质上没有区别，只是方法的同步是一种隐式的方式来实现，无需通过字节码来完成。


## monitor介绍

在Java虚拟机（HotSpot）中，monitor是由ObjectMonitor实现的，其主要数据结构如下（位于HotSpot虚拟机源码ObjectMonitor.hpp文件，C++实现的）

```c++
ObjectMonitor() {
    _header       = NULL;
    _count        = 0; //记录个数
    _waiters      = 0,
    _recursions   = 0;
    _object       = NULL;
    _owner        = NULL;
    _WaitSet      = NULL; //处于wait状态的线程，会被加入到_WaitSet
    _WaitSetLock  = 0 ;
    _Responsible  = NULL ;
    _succ         = NULL ;
    _cxq          = NULL ;
    FreeNext      = NULL ;
    _EntryList    = NULL ; //处于等待锁block状态的线程，会被加入到该列表
    _SpinFreq     = 0 ;
    _SpinClock    = 0 ;
    OwnerIsThread = 0 ;
  }
```

ObjectMonitor中有两个队列，_WaitSet和_EntryList，用来保存ObjectWaiter对象列表(每个等待锁的线程都会被封装成ObjectWaiter对象)，_owner指向持有ObjectMonitor对象的线程，当多个线程同时访问一段同步代码时，首先会进入_EntryList集合，当线程获取到对象的monitor后进入_Owner 区域并把monitor中的owner变量设置为当前线程同时monitor中的计数器count加1，若线程调用wait()方法，将释放当前持有的monitor，owner变量恢复为null，count自减1，同时该线程进入 WaitSet集合中等待被唤醒,如果调用notify或notifyAll将会把_WaitSet移动到_EntryList里，之后参与竞争获取锁。若当前线程执行完毕也将释放monitor(锁)并复位变量的值，以便其他线程进入获取monitor(锁)。如下图所示:
![monitor](https://raw.githubusercontent.com/fengxiu/img/master/20220423121701.png)

## 总结

Synchronized是Java并发编程中最常用的用于保证线程安全的方式，通过monitor来实现，锁的获取和释放主要有以下过程

1. 查看monitor对象已被获取，如果已被获取，则判断是否被当前线程获取，是则进入并将将持有的数量加1；如果没有则值获取对象，并将持有数量加1；有则进入队列进行等待
2. 将持有数量减1，如果等于0则释放锁，唤醒等待队列上的线程；大于1则不释放锁。

Synchronized不是公平锁，可以试想这样一个情形，假设一个锁刚释放，现在恰好有一个线程来获取锁，检测到锁的owner为空，则其可以直接获取。而释放锁的线程虽然唤醒等待队列上的线程，但是其也要执行整个所得获取过程，这时检测ower不为空，则其只能继续等待。导致先来的线程没有获取到，后来的却获取到对应的锁。从而引发不公平

## 参考

1.[干货 | 深入分析Object.wait/notify实现机制](https://cloud.tencent.com/developer/article/1063043)