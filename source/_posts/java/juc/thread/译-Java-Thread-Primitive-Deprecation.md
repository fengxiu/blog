---
title: 译|Java Thread Primitive Deprecation
abbrlink: 837ff6d6
categories:
  - java
  - juc
  - thread
tags:
  - thread
date: 2019-07-28 15:36:15
---
[原文](https://docs.oracle.com/javase/8/docs/technotes/guides/concurrency/threadPrimitiveDeprecation.html)

## 为何废弃 Thread.stop

因为它本质上是不安全的。stop线程将导致释放其持有的全部monitor（ThreadDeath异常在栈中传播时，monitor被解锁），若在当前线程中，这些monitor保护的对象处于不一致状态，则stop后这种不一致状态对其他线程可见。我们视为这种不一致状态的对象被“损坏”，当线程操作“损坏”对象时，可能发生任意（无法预测）行为，它们可能非常微妙且难以检测，也可能抛出这些异常。与其他非检查异常不同，ThreadDeath悄悄杀死线程，用户无法收到任何警告，用户可能到几个小时，或几天会才能发现问题。

## 是否可以捕获ThreadDeath并修复“损坏”对象

理论上可行，但这将极大地使编写正确的多线程代码的任务复杂化。由于两个原因几乎不可能做到：

1. 线程几乎可以在任何地方抛出ThreadDeath，因此所有同步方法、同步代码块都需要仔细设计；并且时刻记住这点。
2. 处理已捕获的ThreadDeath时，可能再次抛出ThreadDeath，因此必须不断重复清理，直至成功，代码会非常复杂；

因此，这样做不切实际。

## Thread.stop(Throwable) 呢

除了上面提到的所有问题之外，此方法还可以用于生成其目标线程没有准备好处理的异常（包括线程不可能抛出的已检查异常，如果不是此方法的话）。例如，下面的方法在行为上与Java的抛出操作完全相同，但绕过编译器的尝试，以确保调用方法声明了它可能抛出的所有检查异常,简单的理解这句话，就是可以抛出异常而不用捕获：

``` java
static void sneakyThrow(Throwable t) {
    Thread.currentThread().stop(t);
}
```

## 用什么替代 Thread.stop

stop的大多数用法都可以替换为只修改某个变量以指示目标线程应该停止运行的代码。目标线程应定期检查该变量，如果该变量指示它将停止运行，则应按顺序从其run方法返回。为了确保停止请求的及时通信，变量必须是volatile类型的（或者必须同步对变量的访问）

例如，假设小程序包含以下启动、停止和运行方法：

``` java 
private Thread blinker;

public void start() {
    blinker = new Thread(this);
    blinker.start();
}

public void stop() {
    blinker.stop();  // UNSAFE!
}

public void run() {
    while (true) {
        try {
            Thread.sleep(interval);
        } catch (InterruptedException e){
        }
        repaint();
    }
}
```

可修改为：

``` java
private volatile Thread blinker;

public void stop() {
    blinker = null;
}

public void run() {
    Thread thisThread = Thread.currentThread();
    while (blinker == thisThread) {  // 运行标识
        try {
            Thread.sleep(interval);
        } catch (InterruptedException e){
        }
        repaint();
    }
}
```

目标线程检测到停止请求后，可以做必要的资源清理，相比直接释放锁，进而处于不一致状态要好很多。

## 如何停止长时间等待的线程（如等待输入）

这就是thread.interrupt方法的用途。可以使用上面所示的相同“基于状态”的信令机制，但状态更改（在前一个示例中，blinker=null）之后可以调用thread.interrupt来中断等待：

``` java
public void stop() {
    Thread moribund = waiter;
    waiter = null;
    moribund.interrupt();
}
```

对于使用这种技术来运行的代码，任何捕获到中断异常但不准备立即处理它的方法都必须重新声明异常。我们说重新声明而不是重新引发，因为不可能总是重新引发异常。如果捕获InterruptedException的方法未声明为引发此（选中）异常，应该再一次进行自我中断，是可以使用下面这行代码

``` java
Thread.currentThread().interrupt();
```

这样可以确保线程能够尽快重新发出InterruptedException。

## 线程未响应Thread.interrupt怎么办

在某些情况下，您可以使用特定于应用程序的技巧。例如，如果一个线程正在等待一个已知的套接字，您可以关闭该套接字以使该线程立即返回。不幸的是，实际上没有任何一种技术在一般情况下起作用。应该注意，在所有等待线程不响应thread.interrupt的情况下，它也不会响应thread.stop。这种情况包括故意拒绝服务攻击，以及thread.stop和thread.interrupt不能正常工作的I/O操作。

## Thread.suspend和Thread.resume也被废弃了

thread.suspend天生就容易死锁。如果目标线程在挂起时在保护关键系统资源的监视器上持有锁，则在恢复目标线程之前，任何线程都无法访问此资源。如果要恢复目标线程的线程在调用resume之前尝试锁定此监视器，则会导致死锁。这种死锁通常表现为“冻结”的进程。

若线程一 suspend 时通过 monitor A 保护稀有资源，则 suspend 后线程一 不释放 minotor A，因此其他线程无法访问该资源，直至线程一 resume。若恢复线程一的线程在调用 resume 前需要获取 monitor A，则发生死锁。

resume 为服务 suspend 而存在。

对此 Thread.suspend 方法的注释也有解释：

``` txt
This method has been deprecated, as it is inherently deadlock-prone.

If the target thread holds a lock on the monitor protecting a 
critical system resource when it is suspended, no thread can 
access this resource until the target thread is resumed. 

If the thread that would resume the target thread attempts 
to lock this monitor prior to calling resume, deadlock results.  

Such deadlocks typically manifest themselves as "frozen" processes.
```

suspend 容易死锁的根因是它 不释放锁，resume 它的线程如果要请求同样的锁，则挂起线程永远无法恢复。

## 用什么替代 Thread.suspend 和 Thread.resume

与thread.stop一样，谨慎的方法是让“目标线程”轮询一个变量，该变量指示线程的所需状态（活动或挂起）。当所需状态被挂起时，线程将使用object.wait等待。当线程恢复时，将使用object.notify通知目标线程。

例如，假设小程序包含以下MousePresed事件处理程序，它切换名为blinker的线程的状态：

``` java

private boolean threadSuspended;

Public void mousePressed(MouseEvent e) {
    e.consume();

    if (threadSuspended)
        blinker.resume();
    else
        blinker.suspend();  // DEADLOCK-PRONE!

    threadSuspended = !threadSuspended;
}
```

通过将上面的事件处理程序替换为以下内容，可以避免使用thread.suspend和thread.resume：

``` java 
public synchronized void mousePressed(MouseEvent e) {
    e.consume();

    threadSuspended = !threadSuspended;

    if (!threadSuspended)
        notify();
}
```

然后在run循环中添加：

``` java
synchronized(this) {
    while (threadSuspended)
       wait();
}
```

wait方法抛出InterruptedException，因此它必须在try---catch子句。把它和sleep放在相同的区块里没关系。检查应该在sleep之后（而不是在sleep之前）进行，这样当线程“恢复”时，窗口会立即重新绘制。生成的运行方法如下：

``` java
public void run() {
    while (true) {
        try {
            Thread.sleep(interval);

            synchronized(this) {
                while (threadSuspended)
                    wait();
            }
        } catch (InterruptedException e){
        }
        repaint();
    }
}
```

请注意，mousePresed方法中的notify和run方法中的wait位于synchronized块内。这是语言所必需的，并确保wait和notify正确序列化。实际上，这消除了可能导致“挂起”线程错过通知并无限期保持挂起的争用条件。虽然Java中的同步成本随着平台的成熟而减少，但它永远不会是免费的。可以使用一个简单的技巧来删除我们在“运行循环”的每个迭代中添加的同步。添加的同步块被一段稍微复杂一些的代码替换，该代码只在线程实际挂起时才进入同步块：

``` java
if (threadSuspended) {
    synchronized(this) {
        while (threadSuspended)
            wait();
    }
}
```

在没有显式同步的情况下，threadsuspend必须是易失性的，以确保挂起请求的及时通信。

最后 run 为：

``` java
private volatile boolean threadSuspended;

public void run() {
    while (true) {
        try {
            Thread.sleep(interval);

            if (threadSuspended) {
                synchronized(this) {
                    while (threadSuspended)
                        wait();
                }
            }
        } catch (InterruptedException e) {
        }
        repaint();
    }
}
```

## 可以结合这两种技术来生成一个可以安全地“stoped”或“suspended”的线程吗

是的，这很简单。其中一个微妙之处是，目标线程可能已经在另一个线程试图停止它时挂起。如果stop方法只将状态变量（blinker）设置为空，则目标线程将保持挂起状态（等待监视器），而不是像应该的那样优雅地退出。如果重新启动小程序，多个线程可能最终同时在监视器上等待，从而导致不稳定的行为。要纠正这种情况，stop方法必须确保目标线程在挂起时立即恢复。一旦目标线程恢复，它必须立即识别它已经停止，并优雅地退出。以下是生成的运行和停止方法的外观：

``` java

public void run() {
    Thread thisThread = Thread.currentThread();
    while (blinker == thisThread) {
        try {
            Thread.sleep(interval);

            synchronized(this) {
                while (threadSuspended && blinker == thisThread)
                    wait();
            }
        } catch (InterruptedException e) {
        }
        repaint();
    }
}

public synchronized void stop() {
    blinker = null;
    notify();
}
```

若 stop 调用 Thread.interrupt，就不用调用 notify，但 stop 还是必须用 synchronized 修饰，同步可以保证目标线程不会因为竞态条件而错误中断。

## Thread.destroy呢

Thread.destroy 从来没被实现，并且已被废弃。即使实现了 destory，与 Thread.suspend 类似，destroy 容易导致死锁。

## 为什么runtime.runFinalizersonexit被废弃

因为它本质上是不安全的。它可能导致对活动对象调用终结器，而其他线程同时操作这些对象，从而导致不稳定的行为或死锁。如果对象被最终确定的类被编码为“防御”这个调用，那么这个问题就可以避免，但大多数程序员并不防御它。它们假定在调用对象的终结器时对象已死亡。
此外，在设置VM全局标志的意义上，调用不是“线程安全的”。这将强制每个类使用终结器来防御活动对象的终结！
