---
title: LockSupport使用介绍以及原理分析
tags:
  - 并发
  - lock
categories:
  - java
  - juc
  - lock
abbrlink: 41442
date: 2022-04-23 17:32:16
updated: 2022-04-23 17:32:16
---

LockSupport用来创建锁和其他同步类的基本线程阻塞原语。简而言之，当调用LockSupport.park时，表示当前线程将会等待，直至获得许可，当调用LockSupport.unpark时，必须把等待获得许可的线程作为参数进行传递，好让此线程继续运行。 

<!-- more -->

## LockSupport源码分析

**类的属性** 

```java
 public class LockSupport {
    // Hotspot implementation via intrinsics API
    private static final sun.misc.Unsafe UNSAFE;
    // 表示内存偏移地址
    private static final long parkBlockerOffset;
    // 表示内存偏移地址
    private static final long SEED;
    // 表示内存偏移地址
    private static final long PROBE;
    // 表示内存偏移地址
    private static final long SECONDARY;
    
    static {
        try {
            // 获取Unsafe实例
            UNSAFE = sun.misc.Unsafe.getUnsafe();
            // 线程类类型
            Class<?> tk = Thread.class;
            // 获取Thread的parkBlocker字段的内存偏移地址
            parkBlockerOffset = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("parkBlocker"));
            // 获取Thread的threadLocalRandomSeed字段的内存偏移地址
            SEED = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("threadLocalRandomSeed"));
            // 获取Thread的threadLocalRandomProbe字段的内存偏移地址
            PROBE = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("threadLocalRandomProbe"));
            // 获取Thread的threadLocalRandomSecondarySeed字段的内存偏移地址
            SECONDARY = UNSAFE.objectFieldOffset
                (tk.getDeclaredField("threadLocalRandomSecondarySeed"));
        } catch (Exception ex) { throw new Error(ex); }
    }
}
```

说明: UNSAFE字段表示sun.misc.Unsafe类，查看其源码，点击在这里，一般程序中不允许直接调用，而long型的表示实例对象相应字段在内存中的偏移地址，可以通过该偏移地址获取或者设置该字段的值。 

**类的构造函数**

```java
// 私有构造函数，无法被实例化
private LockSupport() {}
```
  
说明: LockSupport只有一个私有构造函数，无法被实例化。 

**核心函数分析** 

在分析LockSupport函数之前，先引入sun.misc.Unsafe类中的park和unpark函数，因为LockSupport的核心函数都是基于Unsafe类中定义的park和unpark函数，下面给出两个函数的定义

```java
public native void park(boolean isAbsolute, long time);
public native void unpark(Thread thread);
```
  
说明: 对两个函数的说明如下: 
park函数，阻塞线程，并且该线程在下列情况发生之前都会被阻塞: 
① 调用unpark函数，释放该线程的许可。
② 该线程被中断。
③ 设置的时间到了。并且，当time为绝对时间时，isAbsolute为true，否则，isAbsolute为false。当time为0时，表示无限等待，直到unpark发生。

unpark函数，释放线程的许可，即激活调用park后阻塞的线程。这个函数不是安全的，调用这个函数时要确保线程依旧存活。 

**park函数** 

park函数有两个重载版本，方法摘要如下

```java
public static void park()；
public static void park(Object blocker)；
```

说明: 两个函数的区别在于park()函数没有没有blocker，即没有设置线程的parkBlocker字段。

park(Object)型函数如下。 
```java
public static void park(Object blocker) {
    // 获取当前线程
    Thread t = Thread.currentThread();
    // 设置Blocker
    setBlocker(t, blocker);
    // 获取许可
    UNSAFE.park(false, 0L);
    // 重新可运行后再此设置Blocker
    setBlocker(t, null);
}
```
  
说明: 调用park函数时，首先获取当前线程，然后设置当前线程的parkBlocker字段，即调用setBlocker函数，之后调用Unsafe类的park函数，之后再调用setBlocker函数。

那么问题来了，为什么要在此park函数中要调用两次setBlocker函数呢? 原因其实很简单，调用park函数时，当前线程首先设置好parkBlocker字段，然后再调用Unsafe的park函数，此后，当前线程就已经阻塞了，等待该线程的unpark函数被调用，所以后面的一个setBlocker函数无法运行，unpark函数被调用，该线程获得许可后，就可以继续运行了，也就运行第二个setBlocker，把该线程的parkBlocker字段设置为null，这样就完成了整个park函数的逻辑。如果没有第二个setBlocker，那么之后没有调用park(Object blocker)，而直接调用getBlocker函数，得到的还是前一个park(Object blocker)设置的blocker，显然是不符合逻辑的。

总之，必须要保证在park(Object blocker)整个函数执行完后，该线程的parkBlocker字段又恢复为null。所以，park(Object)型函数里必须要调用setBlocker函数两次。

setBlocker方法如下。 

```java
private static void setBlocker(Thread t, Object arg) {
    // 设置线程t的parkBlocker字段的值为arg
    UNSAFE.putObject(t, parkBlockerOffset, arg);
}
```
  
说明: 此方法用于设置线程t的parkBlocker字段的值为arg。 

另外一个无参重载版本，park()函数如下。

```java
 public static void park() {
    // 获取许可，设置时间为无限长，直到可以获取许可
    UNSAFE.park(false, 0L);
}
```
  
说明: 调用了park函数后，会禁用当前线程，除非许可可用。在以下三种情况之一发生之前，当前线程都将处于休眠状态，即下列情况发生时，当前线程会获取许可，可以继续运行。 
1. 其他某个线程将当前线程作为目标调用unpark。 
2. 其他某个线程中断当前线程。 
3. 该调用不合逻辑地(即毫无理由地)返回，及虚假唤醒

**parkNanos函数** 

此函数表示在许可可用前禁用当前线程，并最多等待指定的等待时间。具体函数如下。

```
 public static void parkNanos(Object blocker, long nanos) {
    if (nanos > 0) { // 时间大于0
        // 获取当前线程
        Thread t = Thread.currentThread();
        // 设置Blocker
        setBlocker(t, blocker);
        // 获取许可，并设置了时间
        UNSAFE.park(false, nanos);
        // 设置许可
        setBlocker(t, null);
    }
}
```
  
说明: 该函数也是调用了两次setBlocker函数，nanos参数表示相对时间，表示等待多长时间。 

**parkUntil函数** 
此函数表示在指定的时限前禁用当前线程，除非许可可用, 具体函数如下: 

```java
public static void parkUntil(Object blocker, long deadline) {
    // 获取当前线程
    Thread t = Thread.currentThread();
    // 设置Blocker
    setBlocker(t, blocker);
    UNSAFE.park(true, deadline);
    // 设置Blocker为null
    setBlocker(t, null);
}
```
  
说明: 该函数也调用了两次setBlocker函数，deadline参数表示绝对时间，表示指定的时间。 

**unpark函数**

此函数表示如果给定线程的许可尚不可用，则使其可用。如果线程在park上受阻塞，则它将解除其阻塞状态。否则，保证下一次调用 park 不会受阻塞。如果给定线程尚未启动，则无法保证此操作有任何效果。具体函数如下: 

```java
public static void unpark(Thread thread) {
    if (thread != null) // 线程为不空
        UNSAFE.unpark(thread); // 释放该线程许可
}
```
  
说明: 释放许可，指定线程可以继续运行。 

## LockSupport示例说明 

### 使用wait/notify实现线程同步 

```java
class MyThread extends Thread {
    
    public void run() {
        synchronized (this) {
            System.out.println("before notify");            
            notify();
            System.out.println("after notify");    
        }
    }
}

public class WaitAndNotifyDemo {
    public static void main(String[] args) throws InterruptedException {
        MyThread myThread = new MyThread();            
        synchronized (myThread) {
            try {        
                myThread.start();
                // 主线程睡眠3s
                Thread.sleep(3000);
                System.out.println("before wait");
                // 阻塞主线程
                myThread.wait();
                System.out.println("after wait");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }            
        }        
    }
}
```
  
运行结果

```
before wait
before notify
after notify
after wait
```
  
说明: 具体的流程图如下  

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220423174308.png)

使用wait/notify实现同步时，必须先调用wait，后调用notify，如果先调用notify，再调用wait，将起不了作用。

具体代码如下 

```java
class MyThread extends Thread {
    public void run() {
        synchronized (this) {
            System.out.println("before notify");            
            notify();
            System.out.println("after notify");    
        }
    }
}

public class WaitAndNotifyDemo {
    public static void main(String[] args) throws InterruptedException {
        MyThread myThread = new MyThread();        
        myThread.start();
        // 主线程睡眠3s
        Thread.sleep(3000);
        synchronized (myThread) {
            try {        
                System.out.println("before wait");
                // 阻塞主线程
                myThread.wait();
                System.out.println("after wait");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }            
        }        
    }
}
```

运行结果: 

```
before notify
after notify
before wait
```
  
说明: 由于先调用了notify，再调用的wait，此时主线程还是会一直阻塞。 

### 使用park/unpark实现线程同步 

```
import java.util.concurrent.locks.LockSupport;

class MyThread extends Thread {
    private Object object;

    public MyThread(Object object) {
        this.object = object;
    }

    public void run() {
        System.out.println("before unpark");
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        // 获取blocker
        System.out.println("Blocker info " + LockSupport.getBlocker((Thread) object));
        // 释放许可
        LockSupport.unpark((Thread) object);
        // 休眠500ms，保证先执行park中的setBlocker(t, null);
        try {
            Thread.sleep(500);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        // 再次获取blocker
        System.out.println("Blocker info " + LockSupport.getBlocker((Thread) object));

        System.out.println("after unpark");
    }
}

public class test {
    public static void main(String[] args) {
        MyThread myThread = new MyThread(Thread.currentThread());
        myThread.start();
        System.out.println("before park");
        // 获取许可
        LockSupport.park("ParkAndUnparkDemo");
        System.out.println("after park");
    }
}
  
```
运行结果:
```
before park
before unpark
Blocker info ParkAndUnparkDemo
after park
Blocker info null
after unpark
```
  
说明: 本程序先执行park，然后在执行unpark，进行同步，并且在unpark的前后都调用了getBlocker，可以看到两次的结果不一样，并且第二次调用的结果为null，这是因为在调用unpark之后，执行了Lock.park(Object blocker)函数中的setBlocker(t, null)函数，所以第二次调用getBlocker时为null。 

上例是先调用park，然后调用unpark，现在修改程序，先调用unpark，然后调用park，看能不能正确同步。具体代码如下 

```java
import java.util.concurrent.locks.LockSupport;

class MyThread extends Thread {
    private Object object;

    public MyThread(Object object) {
        this.object = object;
    }

    public void run() {
        System.out.println("before unpark");        
        // 释放许可
        LockSupport.unpark((Thread) object);
        System.out.println("after unpark");
    }
}

public class ParkAndUnparkDemo {
    public static void main(String[] args) {
        MyThread myThread = new MyThread(Thread.currentThread());
        myThread.start();
        try {
            // 主线程睡眠3s
            Thread.sleep(3000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println("before park");
        // 获取许可
        LockSupport.park("ParkAndUnparkDemo");
        System.out.println("after park");
    }
}
```
运行结果: 

```
before unpark
after unpark
before park
after park
```

说明: 可以看到，在先调用unpark，再调用park时，仍能够正确实现同步，不会造成由wait/notify调用顺序不当所引起的阻塞。因此park/unpark相比wait/notify更加的灵活。 

### 中断响应 

看下面示例 

```java
import java.util.concurrent.locks.LockSupport;

class MyThread extends Thread {
    private Object object;

    public MyThread(Object object) {
        this.object = object;
    }

    public void run() {
        System.out.println("before interrupt");        
        try {
            // 休眠3s
            Thread.sleep(3000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }    
        Thread thread = (Thread) object;
        // 中断线程
        thread.interrupt();
        System.out.println("after interrupt");
    }
}

public class InterruptDemo {
    public static void main(String[] args) {
        MyThread myThread = new MyThread(Thread.currentThread());
        myThread.start();
        System.out.println("before park");
        // 获取许可
        LockSupport.park("ParkAndUnparkDemo");
        System.out.println("after park");
    }
}
```

运行结果: 
```
before park
before interrupt
after interrupt
after park
```
  
说明: 可以看到，在主线程调用park阻塞后，在myThread线程中发出了中断信号，此时主线程会继续运行，也就是说明此时interrupt起到的作用与unpark一样。 

### 更深入的理解 

**Thread.sleep()和Object.wait()的区别**

首先，我们先来看看Thread.sleep()和Object.wait()的区别，这是一个烂大街的题目了，大家应该都能说上来两点。 
* Thread.sleep()不会释放占有的锁，Object.wait()会释放占有的锁；
* Thread.sleep()必须传入时间，Object.wait()可传可不传，不传表示一直阻塞下去； Thread.sleep()到时间了会自动唤醒，然后继续执行； 
* Object.wait()不带时间的，需要另一个线程使用Object.notify()唤醒； 
* Object.wait()带时间的，假如没有被notify，到时间了会自动唤醒，这时又分好两种情况，
  * 一是立即获取到了锁，线程自然会继续执行；
  * 二是没有立即获取锁，线程进入同步队列等待获取锁； 

其实，他们俩最大的区别就是Thread.sleep()不会释放锁资源，Object.wait()会释放锁资源。 

**Object.wait()和Condition.await()的区别**

Object.wait()和Condition.await()的原理是基本一致的，不同的是Condition.await()底层是调用LockSupport.park()来实现阻塞当前线程的。 实际上，它在阻塞当前线程之前还干了两件事，一是把当前线程添加到条件队列中，二是“完全”释放锁，也就是让state状态变量变为0，然后才是调用LockSupport.park()阻塞当前线程。

**Thread.sleep()和LockSupport.park()的区别**

LockSupport.park()还有几个兄弟方法——parkNanos()、parkUtil()等，我们这里说的park()方法统称这一类方法。 

* 从功能上来说，Thread.sleep()和LockSupport.park()方法类似，都是阻塞当前线程的执行，且都不会释放当前线程占有的锁资源； 
* Thread.sleep()没法从外部唤醒，只能自己醒过来； LockSupport.park()方法可以被另一个线程调用LockSupport.unpark()方法唤醒； 
* Thread.sleep()方法声明上抛出了InterruptedException中断异常，所以调用者需要捕获这个异常或者再抛出； LockSupport.park()方法不需要捕获中断异常；
* Thread.sleep()本身就是一个native方法； LockSupport.park()底层是调用的Unsafe的native方法； 

**Object.wait()和LockSupport.park()的区别**

 二者都会阻塞当前线程的运行，他们有什么区别呢? 经过上面的分析相信你一定很清楚了，真的吗? 往下看！ 

* Object.wait()方法需要在synchronized块中执行； LockSupport.park()可以在任意地方执行；
* Object.wait()方法声明抛出了中断异常，调用者需要捕获或者再抛出； LockSupport.park()不需要捕获中断异常； 
* Object.wait()不带超时的，需要另一个线程执行notify()来唤醒，但不一定继续执行后续内容； LockSupport.park()不带超时的，需要另一个线程执行unpark()来唤醒，一定会继续执行后续内容；

park()/unpark()底层的原理是“二元信号量”，你可以把它相像成只有一个许可证的Semaphore，只不过这个信号量在重复执行unpark()的时候也不会再增加许可证，最多只有一个许可证。

**如果在wait()之前执行了notify()会怎样?** 

如果当前的线程不是此对象锁的所有者，却调用该对象的notify()或wait()方法时抛出IllegalMonitorStateException异常； 如果当前线程是此对象锁的所有者，wait()将一直阻塞，因为后续将没有其它notify()唤醒它。 

**如果在park()之前执行了unpark()会怎样?** 

线程不会被阻塞，直接跳过park()，继续执行后续内容 

**LockSupport.park()会释放锁资源吗?**

不会，它只负责阻塞当前线程，释放锁资源实际上是在Condition的await()方法中实现的

## LockSupport底层原理介绍

其实底层是通过mutex和condition来实现的，mutex被称为互斥量锁，类似于Java的锁，即用来保证线程安全，一次只有一个线程能够获取到互斥量mutex，获取不到的线程则可能会阻塞。而这个condition可以类比于java的Condition，被称为条件变量，用于将不满足条件的线程挂起在指定的条件变量上，而当条件满足的时候，再唤醒对应的线程让其执行。

Condition的操作本身不是线程安全的，没有锁的功能，只能让线程等待或者唤醒，因此mutex与Condition常常一起使用，这又可以类比Java中的Lock与Condition，或者synchronized与监视器对象。通常是线程获得mutex锁之后，判断如果线程不满足条件，则让线程在某个Condition上挂起并释放mutex锁，当另一个线程获取mutex锁并发现某个条件满足的时候，可以将调用Conditon的方法唤醒在指定Conditon上等待的线程并获取锁，然后被唤醒的线程由于条件满足以及获取了锁，则可以安全并且符合业务规则的执行下去。
mutex与condition的实现，实际他们内部都使用到了队列，可以类比Java中AQS的同步队列和条件队列。同样，在condition的条件队列中被唤醒的线程，将会被放入同步队列等待获取mutex锁，当获取到所之后，才会真正的返回，这同样类似于AQS的await和signal的实现逻辑。

上面介绍LockSupport时，说每个线程都与一个许可(permit)关联，这个许可对应着上面介绍了Condition，当有许可时就不会阻塞，没有许可时就阻塞，只是许可只有0和1之分，没有更细粒度的划分。

下面看下linux下LockSupport里park底层实现流程，其中_counter对应着许可


1. 首先检查许可_counter是否大于0，如果是那么表示此前执行过unpark，那么将_counter重置为0，直接返回，此时没有并且也不需要获取mutex。
2. 如果当前线程被中断了，那么直接返回。
3. 如果time时间值小于0，或者是绝对时间并且time值等于0，那么也直接返回。
4. 如果当前线程被中断了，那么直接返回，否则非阻塞式的获取mutex锁，如果没有获取到，那么表示此时可能有其他线程已经在unpark该线程并获取了mutex锁，那么也直接返回。
5. 获取到了锁之后，再次判断_counter是否大于0，如果是，那么表示已经有了许可，那么将_counter置为0，释放mutex锁，然后返回。
6. 根据参数设置_cur_index的值（0或1）并调用pthread_cond_wait 或者safe_cond_timedwait进入对应的条件变量等待，并自动释放mutex锁。此时后续代码不会执行。
7. 被唤醒后，并没有主动获取mutex锁，因为内核会自动帮我们重新获取mutex锁，将 \_counter重置为 0，表示消耗了许可；将_cur_index重置为-1，表示没有线程在等待。park方法结束。

unpark相对park方法来说简单了不少,大概步骤为：

1. 首先阻塞式的获取mutex锁，获取不到则一直阻塞在此，直到获取成功。
2. 获取到mutex锁之后，获取当前的许可_counter的值保存在变量s中，然后将_counter的值置为1。
3. 如果s小于1，表示没有了许可，此时可能存在线程被挂起，也可能不存在，继续向下判断：
4. 如果_cur_index不为-1，那么肯定有在_cur_index对应索引的条件变量上挂起，那么需要唤醒：如果设置了WorkAroundNPTLTimedWaitHang（linux默认设置），那么先signal唤醒在条件变量上等待的线程然后释放mutex锁，方法结束；否则先释放mutex锁然后signal唤醒在条件变量上等待的线程，方法结束。
4. 否则_cur_index等于-1，表示没有线程在条件变量上等待，直接释放mutex锁，方法结束。


### 虚假唤醒

如果存在多条线程使用同一个_counter，那么进行挂起的方法pthread_cond_wait和safe_cond_timedwait的调用必须使用while循环包裹，在被唤醒之后，判断条件是否真的满足，否则可能被唤醒的同时其他线程消耗了条件导致不满足，这时就发生了“虚假唤醒”，即虽然阻塞的线程被唤醒了，但是实际上条件并不满足，那么此时需要继续等待。 比如这样的写法就是正确的：

```java
while(_counter==0){
    status = pthread_cond_wait();
}
```


但是在park方法中，pthread_cond_wait和safe_cond_timedwait方法仅会被调用一次，并没有死循环包裹，这是因为一条线程对应一个Parker实例，不同的线程具有不同的Parker，每个Parker中的_counter仅仅记录当前绑定的线程的许可计数，虽然Parker仍然可能会由多个线程竞争（因为需要由其他线程通过unpark方法控制Parker绑定的线程的唤醒），但某个线程的pthread_cond_wait和safe_cond_timedwait方法（也就是park方法）不存在多线程竞争调用的可能，因为调用park方法的线程都是把自己进行wait，所以也没必要使用while循环，如果某线程被唤醒一般就是其他线程调用了针对此线程的unpark方法，此时许可一般都是充足的，这样看来不使用while循环确实没什么问题。

但是，某些极端情况下仍然会造成“虚假唤醒（spurious wakeup）”，这时即使许可不足，那么仍然可以从park方法返回。
在park方法只是调用线程进行wait的情况下仍然可能“虚假唤醒”的原因主要是在linux环境下，在Condition的条件队列中wait的线程，即使没有signal或者signalAll的调用，wait也可能返回。因为这里线程的阻塞通常是使用一些底层工具实现的，比如Futex组件，如果这是底层组件进程被中断，那么会终止线程的阻塞，然后直接返回EINTR错误状态。这也是在park方法中写到的返回的第三个原因。


作者：刘Java
链接：https://juejin.cn/post/7082954879815122958
来源：稀土掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。

## 参考

1. [LockSupport详解](https://pdai.tech/md/java/thread/java-thread-x-lock-LockSupport.html)
2. [Java LockSupport以及park、unpark方法源码深度解析](https://juejin.cn/post/7082954879815122958#heading-18)