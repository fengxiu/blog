---
title: java多线程系列-JUC线程池之03ThreadPoolExecutor线程池的创建
tags:
  - JUC
  - 线程池
categories:
  - java
  - juc
  - Executors
abbrlink: a1d13062
date: 2018-07-24 13:58:00
---

1. 线程池的创建
2. ThreadFactory：线程创建工厂
3. RejectedExecutionHandler：任务拒绝策略

## 线程池官方文档

下面是对线程池注释的一些翻译以及自己的理解，首先为什么使用线程池，线程池能够对线程进行统一分配，调优和监控，有以下有点

1. 降低资源消耗(线程无限制地创建，然后使用完毕后销毁)
2. 提高响应速度(无须创建线程)
3. 提高线程的可管理性

通过以下措施可以优化和配置线程池

### corePoolSize和maximumPoolSize

线程池可以根据corePoolSize和maximumPoolSize来自动调整线程池线程的数量

1. 当线程池小于corePoolSize时，会一直创建线程来执行提交的任务，即使其它线程是空闲状态
2. 如果线程数量大于corePoolSize小于maximumPoolSize，只会在队列已满的情况下创建线程。

默认情况下，corePoolSize和maximumPoolSize是也一样的，也就是会创建一个固定大小的线程数量的线程池，如果maximumPoolSize的大小是无限的，则在队列已满的情况下，会一直创建新线程。

### 提前初始化线程

默认情况下，核心线程只会在任务到达时才会创建，这个可以调用prestartCoreThread和prestartAllCoreThreads来提前初始化核心线程，或者使用一个非空的队列来初始化

### 创建新线程

线程的创建调用ThreadFactory来进行创建，如果没有指定，则会调用Executors#defaultThreadFactory来进行创建，创建出来的线程在相同的ThreadGroup，NORM_PRIORITY，以及非daemon状态。同时也可以自定义一个新的ThreadFactory，来改变这些值。同时应该保证创建出来的线程是可运行的，如果不可运行会导致线程池的服务能力下降。

### 存活时间

线程池的线程如果超过了corePoolSize设置的大小，并且有一些线程是空闲的，则可以通过设置keepAliveTime，来回收这些空闲线程，从而降低资源的消耗。默认情况下，keepAliveTime只会用来回来超过核心线程数量的线程，但是也可以通过allowCoreThreadTimeOut方法，来回收核心线程。

### 队列

BlockingQueue可以用来传递和保存提交的任务，队列与线程池的交互是通过队列的长度来决定的，主要有以下情况

1. 如果线程池中的线程数量小于corePoolSize，则会一直创建线程
2. 如果大于corePoolSize，则会先将任务放进队列中
3. 如果任务不能入队，则会创建一个新的线程执行任务，如果超过了maximumPoolSize，则会执行对应的拒绝策略。


入队对应着若干个策略

1. 直接传递（Direct handoffs）：使用一个类似SynchronousQueue的队列，不会存储任务，而是直接将任务交给线程执行。前提是maximumPoolSizes无限大，不会导致线程创建失败从而执行拒绝策略
2. 无界队列（Unbounded queues）：使用一个类似LinkedBlockingQueue的队列，所有的任务首先会被入队，这个比较适合后台任务，不需要获取结果的情形
3. 有界队列(Bounded queues)：使用类似ArrayBlockingQueue的队列，可以阻止资源的消耗，当任务超过队列的长度，以及线程超过maximumPoolSizes的长度，将会直接决绝任务。

### 拒绝策略

下面会介绍，就不在具体说明


### 钩子方法

线程池提供了一些默认的方法，可以用于任务执行前或者执行后进行处理

* beforeExecute：任务执行前调用的方法
* afterExecute：任务执行后调用的方法


<!-- more -->

##  线程池的创建

ThreadPoolExecutor提供了四个创建线程池的构造函数，源码如下

```java
ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue)

ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, RejectedExecutionHandler handler)

ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, ThreadFactory threadFactory)

ThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, ThreadFactory threadFactory, RejectedExecutionHandler handler)
```
<!-- more -->
虽然其提供了四个构造函数，但是前三个都是在调用最后一个来创建。下面来解释一下上面每个参数的意思

1. corePoolSize:核心线程池的大小
2. maximumPoolSize: 线程池中最大线程池的次数、
3. keepAliveTime :线程最大空闲的时间
4. TimeUnit：用于指定前面keepAliveTime代表的时间单位
5. workQueue：指定存放任务的队列
6. threadFactory：创建线程的工厂，如果不指定的话。默认是Executors.DefaultThreadFactory
7. ejectedExecutionHandler：拒接策略，如果不指定默认是AbortPolicy

下面通过Executors来看看具体的线程池如何创建：

```java
public static ExecutorService newCachedThreadPool() {
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>());
}

public static ExecutorService newCachedThreadPool(ThreadFactory threadFactory) {
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>(),
                                  threadFactory);
}
```

上面是创建一个可根据需要创建新线程的线程池，但是以前构造的线程可用时将重用它们。上面是将核心线程设置为0，也就是只要有线程加进来，就会创建一个新线程。每个空闲线程都只会保留60秒，超过这个时间就会回收。另外一个比较特殊是，它使用的队列SynchronousQueue，这是一个不会缓存任务的队列，来一个任务，只有在有线程将此任务取出之后，才会有另外的任务加进来。也确保了只要有任务来，就会去创建一个新的线程或使用空闲的线程。

```java
public static ExecutorService newFixedThreadPool(int nThreads) {
        return new ThreadPoolExecutor(nThreads, nThreads,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>());
    }
public static ExecutorService newFixedThreadPool(int nThreads, ThreadFactory threadFactory) {
        return new ThreadPoolExecutor(nThreads, nThreads,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>(),
                                      threadFactory);
```

创建一个核心线程和最大线程相同的线程池，也就是新任务了，如果进不了队列，就会被抛出，不过它使用的是LinkedBlockingQueue队列，并且没有设置队列的长度，就是可以缓存 Integer.MAX_VALUE个任务。

```java
public static ExecutorService newSingleThreadExecutor() {
        return new FinalizableDelegatedExecutorService
            (new ThreadPoolExecutor(1, 1,
                                    0L, TimeUnit.MILLISECONDS,
                                    new LinkedBlockingQueue<Runnable>()));
}
 public static ExecutorService newSingleThreadExecutor(ThreadFactory threadFactory) {
        return new FinalizableDelegatedExecutorService
            (new ThreadPoolExecutor(1, 1,
                                    0L, TimeUnit.MILLISECONDS,
                                    new LinkedBlockingQueue<Runnable>(),
                                    threadFactory));
}

```

这个是创建只有一个核心线程的线程池，只有前一个任务执行完成，后一个任务才能被执行。

## ThreadFactory:线程创建工厂

在JUC中定义了线程创建工厂接口，也就是ThreadFactory接口，源码如下

```java
public interface ThreadFactory {
  Thread newThread(Runnable r);
}
```

接口定义很简单，传递一个实现了Runnable接口的类，然后返回一个Thread对象，这和我们平常使用的new Thread其实没设么区别，只是在这里换成了工厂模式。

ThreadPoolExecutor默认使用的是Executors.DefaultThreadFactory这个类，源码如下

```java
static class DefaultThreadFactory implements ThreadFactory {
   private static final AtomicInteger poolNumber = new AtomicInteger(1);
   private final ThreadGroup group;
   private final AtomicInteger threadNumber = new AtomicInteger(1);
   private final String namePrefix;

   DefaultThreadFactory() {
       SecurityManager s = System.getSecurityManager();
       //获取当前cpu运行线程的ThreadGroup，这样便于管理线程池中线程
       group = (s != null) ? s.getThreadGroup() :
                             Thread.currentThread().getThreadGroup();
       //所有后面创建的线程，都都以这个下面这个字符串为前缀
       namePrefix = "pool-" +
                     poolNumber.getAndIncrement() +
                    "-thread-";
   }

   public Thread newThread(Runnable r) {
   	   //创建线程，指定ThreadGroup和线程名字，忽略栈的大小，也就是使用默认栈的深度
       Thread t = new Thread(group, r,
                             namePrefix + threadNumber.getAndIncrement(),
                             0);
       //设置线程的优先级和线程不是daemon线程
       if (t.isDaemon())
           t.setDaemon(false);
       // 设置线程优先级为NORM_PRIORITY
       if (t.getPriority() != Thread.NORM_PRIORITY)
           t.setPriority(Thread.NORM_PRIORITY);
       return t;
   }
}
```

分析：

是在Executors内部实现的一个内部静态类，这个类的定义很简单，就是创建一个ThreadGroup，将后面使用newThread创建的线程放到这个group中，然后设置所有的线程都不是daemon线程，并且设置线程优先级为NORM_PRIORITY。

## RejectedExecutionHandler：任务拒绝策略

线程池的拒绝策略，是指当任务添加到线程池中被拒绝，而采取的处理措施。当任务添加到线程池中之所以被拒绝，可能是由于：第一，线程池异常关闭。第二，任务数量超过线程池的最大限制。

线程池共包括4种拒绝策略，它们分别是：**AbortPolicy**, **CallerRunsPolicy**, **DiscardOldestPolicy**和**DiscardPolicy**。
源码如下

```java

// 拒绝策略的接口定义
public interface RejectedExecutionHandler {

    void rejectedExecution(Runnable r, ThreadPoolExecutor executor);
}


// 有当前提交任务的线程执行
public static class CallerRunsPolicy implements RejectedExecutionHandler {
    
        public CallerRunsPolicy() { }

        public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
            if (!e.isShutdown()) {
                r.run();
            }
        }
    }

// 抛出异常，不执行此任务
public static class AbortPolicy implements RejectedExecutionHandler {
    /**
     * Creates an {@code AbortPolicy}.
     */
    public AbortPolicy() { }

    // 
    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
        throw new RejectedExecutionException("Task " + r.toString() +
                                             " rejected from " +
                                             e.toString());
    }
}

// 不执行任务，直接丢弃也不跑出异常
public static class DiscardPolicy implements RejectedExecutionHandler {
  
    public DiscardPolicy() { }

    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    }
}

// 删除最早的任务,将当前任务放进去
public static class DiscardOldestPolicy implements RejectedExecutionHandler {
   
    public DiscardOldestPolicy() { }

    // 
    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
        if (!e.isShutdown()) {
            e.getQueue().poll();
            e.execute(r);
        }
    }
}
```

1. **AbortPolicy** ：当任务添加到线程池中被拒绝时，它将抛出 RejectedExecutionException 异常。
2. **CallerRunsPolicy** ：当任务添加到线程池中被拒绝时，会在调用execute方法的Thread线程中处理被拒绝的任务，也就是当前运行在cpu上的线程中执行，会阻塞当前正在运行的线程。
3. **DiscardOldestPolicy** ： 当任务添加到线程池中被拒绝时，线程池会放弃等待队列中最旧的未处理任务，然后将被拒绝的任务添加到等待队列中。
4. **DiscardPolicy**   ：当任务添加到线程池中被拒绝时，线程池将丢弃被拒绝的任务。
