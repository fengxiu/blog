---
title: java多线程系列-JUC线程池之06 CompletionService
abbrlink: fac740ad
categories:
  - java
  - juc
  - Executors
date: 2019-07-08 20:09:20
updated: 2019-07-08 20:09:20
tags:
  - 线程池
  - JUC
---
## 简介

前面提过，如果Future集合用于存放执行结果，执行任务，最后遍历Future集合获取结果；因为`Future.get()`方法是阻塞的，因此不能及时获取已完成任务的执行结果。所以JUC提供了一个`ExecutorService`来获取结果，使得任务的提交和结果的获取都能做到异步，从而实现真正的异步。

<!-- more -->

## 简单示例

下面是一个使用ExecutorService的简单demo，这个例子演示了`poll`方法的使用，方法poll的作用是获取并移除表示下一个已完成任务的Future，如果不存在这样的任务，则返回null，方法poll是无阻塞的。

``` java
public class ExecutorServiceStudy {
    public static void main(String[] args) throws Exception {
        ExecutorService executorService = Executors.newCachedThreadPool();
        CompletionService<String> service = new ExecutorCompletionService<String>(executorService);
        service.submit(new Callable<String>() {
            @Override
            public String call() throws Exception {
                TimeUnit.SECONDS.sleep(3);
                System.out.println("3 seconds pass.");
                return "3秒";
            }
        });
        System.out.println(service.poll());
        executorService.shutdown();
    }
}
```

## 源码分析

下面是我从javaDoc，翻译的ExecutorService的官方解释，如果您的英文比较好，可以直接看英文原文，毕竟我的英语也只是个二把刀

``` txt
一个Service用于解耦任务的异步提交和任务完成结果的获取。生产者提交任务执行。消费者取出完成的任务并按照完成的顺序来获取结果。（注意这里的完成顺序不一定是任务的提交顺序）。例如，CompletionService可用于管理异步I/O，其中执行读取的任务在程序或系统的某个部分中提交，然后在读取完成时在程序的不同部分中执行，可能在不同于他们提交的顺序。通常，CompletiongService依赖一个单独的线程池去执行任务，所有CompletionService仅仅管理内部的任务完成队列。ExecutorCompletionService是它的一个默认实现。
```

我们首先看看ExecutorService这个接口的定义：

``` java
public interface CompletionService<V> {
    // 提交任务
    Future<V> submit(Callable<V> task);
    
    // 提交任务
    Future<V> submit(Runnable task, V result);

    // 检索并移除Future代表的接下来完成任务，如果没有完成的任务则阻塞
    Future<V> take() throws InterruptedException;

     // 检索和移除Future代表的接下来完成的任务，如果没有完成的则返回null
    Future<V> poll();

     // 检索和移除Future代表的接下来完成的任务，等待指定的时间，如果没有完成的则返回null
    Future<V> poll(long timeout, TimeUnit unit) throws InterruptedException;
}

```

从上面看，接口的定义相对来说比较简单，定义了来个提交任务的方法，和三个获取任务结果的方法，其中一个会阻塞等待直到有任务完成，另俩个非阻塞获取任务结果的方法。

### 具体实现：ExecutorCompletionService

首先谈谈我还没看这个类时的想法，我一看这个类的功能，想着实现这个接口肯定需要大量的代码，而且也会超级复杂。但是当我看到代码的时候，真的不得不佩服doug lea大师的抽象能力。

这里首先看下属性和一个内部类，这个后面都会用到：

``` java
    // 线程池，用于执行任务
    private final Executor executor;

    // 存储是AbstractExecutorService的线程池，用于创建任务
    private final AbstractExecutorService aes;

    // 存储完成任务的队列
    private final BlockingQueue<Future<V>> completionQueue;

     // 下面这个方法只是简单的继承FutureTask，然后扩展了任务完成时的方法
    private class QueueingFuture extends FutureTask<Void> {
        QueueingFuture(RunnableFuture<V> task) {
            super(task, null);
            this.task = task;
        }
        // 扩展done方法，存储结果
        protected void done() {

         completionQueue.add(task);

        }
        private final Future<V> task;
    }

```

### 任务的提交：submit

``` java

    public Future<V> submit(Callable<V> task) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<V> f = newTaskFor(task);
        executor.execute(new QueueingFuture(f));
        return f;
    }

    public Future<V> submit(Runnable task, V result) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<V> f = newTaskFor(task, result);
        executor.execute(new QueueingFuture(f));
        return f;
    }

    private RunnableFuture<V> newTaskFor(Callable<V> task) {
        if (aes == null)
            return new FutureTask<V>(task);
        else
            return aes.newTaskFor(task);
    }

    private RunnableFuture<V> newTaskFor(Runnable task, V result) {
        if (aes == null)
            return new FutureTask<V>(task, result);
        else
            return aes.newTaskFor(task, result);
    }

```

整体代码还是比较简单，使用newTaskFor对提交的任务进行同意封装，然后提交到线程池中运行，不过这里需要对任务进一步封装，使用QueueingFuture来进行包装一层，而这个类前面已经说过就是个简单的扩展了FutureTask方法done的类。

### 完成任务的获取

``` java
    public Future<V> take() throws InterruptedException {
        return completionQueue.take();
    }

    public Future<V> poll() {
        return completionQueue.poll();
    }

    public Future<V> poll(long timeout, TimeUnit unit)
            throws InterruptedException {
        return completionQueue.poll(timeout, unit);
    }
```

这个我觉得都不需要解释，就是对队列的操作。队列可以是JUC里面的任意队列类，这里默认使用的是LinkedBlockQueue。我觉得构造方法比较简单，就没有在这里列出，里面定义了如何传入BlockQueue。

## 总结

从这个其实我们可以看出，类的实现非常简单，基本上都是在复用JUC中已经存在的类，但是这个是因为JUC的整体抽象设计的非常好，所以这里才会做的那么简单，但功能实现却很完美，这个真的值得我们去思考，如何才能设计出这样的工具类。
