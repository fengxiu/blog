---
title: Java并发工具类之LongAdder原理总结
abbrlink: 3ade2f8f
categories:
  - java
  - juc
  - atomic
date: 2019-06-17 21:38:22
tags:
  - JUC
  - Atomic
  - LongAdder
---
`java.util.concurrency.atomic.LongAdder`是Java8新增的一个类，提供了原子累计值的方法。根据文档的描述其性能要优于AtomicLong，下面是一个简单的测试对比demo(平台:MBP):
``` java
package com.zhangke.basic;

import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.runner.Runner;
import org.openjdk.jmh.runner.RunnerException;
import org.openjdk.jmh.runner.options.Options;
import org.openjdk.jmh.runner.options.OptionsBuilder;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.LongAdder;

/**************************************
 *      Author : zhangke
 *      Date   : 2019-06-19 10:53
 *      email  : 398757724@qq.com
 *      Desc   : 对比AtomicInteger和LongAdder性能
 ***************************************/
@State(Scope.Group)
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 3, time = 5, timeUnit = TimeUnit.SECONDS)
@Measurement(iterations = 3, time = 5, timeUnit = TimeUnit.SECONDS)
public class AtomicToLongAdder {

    private AtomicInteger atomicInteger;
    private LongAdder longAdder;

    @Setup
    public void setup() {
        atomicInteger = new AtomicInteger();
        longAdder = new LongAdder();
    }

    @Benchmark
    @Group("rw")
    @GroupThreads(20)
    public Integer atomicInc() {
        return atomicInteger.incrementAndGet();
    }

    @Benchmark
    @Group("rw")
    @GroupThreads(1)
    public long atomicGet() {
        return atomicInteger.get();
    }

    @Benchmark
    @Group("ld")
    @GroupThreads(20)
    public void longAdderInc() {
        longAdder.increment();
    }

    @Benchmark
    @Group("ld")
    @GroupThreads(1)
    public long longAdderGet() {
        return longAdder.sum();
    }

    public static void main(String[] args) throws RunnerException {
        Options opt = new OptionsBuilder()
                .include(AtomicToLongAdder.class.getSimpleName())
                .forks(1)
                .build();
        new Runner(opt).run();
    }
}

```
```
Benchmark                          Mode  Cnt    Score     Error  Units
AtomicToLongAdder.ld               avgt    3   91.834 ±  60.177  ns/op
AtomicToLongAdder.ld:longAdderGet  avgt    3  260.959 ± 508.102  ns/op
AtomicToLongAdder.ld:longAdderInc  avgt    3   83.378 ±  83.854  ns/op
AtomicToLongAdder.rw               avgt    3  328.864 ±  89.448  ns/op
AtomicToLongAdder.rw:atomicGet     avgt    3  132.681 ± 346.180  ns/op
AtomicToLongAdder.rw:atomicInc     avgt    3  338.673 ±  79.338  ns/op
```
这里测试时基于JDK1.8进行的，从上面结果可以，看出在多线程情况下，LongAdder的写性能要比AtomicInteger要好，但是读性能相对来说要差很多，所以LongAdder适合于一些多写少读的环境。

AtomicLong从Java8开始针对x86平台进行了优化，使用XADD替换了CAS操作，我们知道JUC下面提供的原子类都是基于Unsafe类实现的，并由Unsafe来提供CAS的能力。CAS (compare-and-swap)本质上是由现代CPU在硬件级实现的原子指令，允许进行无阻塞，多线程的数据操作同时兼顾了安全性以及效率。大部分情况下,CAS都能够提供不错的性能，但是在高竞争的情况下开销可能会成倍增长，具体的研究可以参考这篇[文章](https://arxiv.org/abs/1305.5800), 我们直接看下代码:
``` java
public class AtomicLong {
public final long incrementAndGet() {
        return unsafe.getAndAddLong(this, valueOffset, 1L) + 1L;
    }
}

public final class Unsafe {
public final long getAndAddLong(Object var1, long var2, long var4) {
        long var6;
        do {
            var6 = this.getLongVolatile(var1, var2);
        } while(!this.compareAndSwapLong(var1, var2, var6, var6 + var4));
        return var6;
    }
}
```
getAndAddLong方法会以volatile的语义去读需要自增的域的最新值，然后通过CAS去尝试更新，正常情况下会直接成功后返回，但是在高并发下可能会同时有很多线程同时尝试这个过程，也就是说线程A读到的最新值可能实际已经过期了，因此需要在while循环中不断的重试，造成很多不必要的开销，而xadd的相对来说会更高效一点，伪码如下,最重要的是下面这段代码是原子的,也就是说其他线程不能打断它的执行或者看到中间值，这条指令是在硬件级直接支持的:
``` c
function FetchAndAdd(address location, int inc) {
    int value := *location
    *location := value + inc
    return value
}
```
而LongAdder的性能比上面那种还要好很多，于是就研究了一下。首先它有一个基础的值base，在发生竞争的情况下，会有一个Cell数组用于将不同线程的操作离散到不同的节点上去(会根据需要扩容，最大为CPU核数)，sum()会将所有Cell数组中的value和base累加作为返回值。核心的思想就是将AtomicLong一个value的更新压力分散到多个value中去，从而降低更新热点。
``` java
public class LongAdder extends Striped64 implements Serializable {
//...
}
```
LongAdder继承自Striped64，Striped64内部维护了一个懒加载的数组以及一个额外的base实例域，数组的大小是2的N次方，使用每个线程Thread内部的哈希值访问。
``` java
abstract class Striped64 extends Number {
    /** Number of CPUS, to place bound on table size */
    static final int NCPU = Runtime.getRuntime().availableProcessors();

    /**
     * Table of cells. When non-null, size is a power of 2.
     */
    transient volatile Cell[] cells;
     
    @sun.misc.Contended 
    static final class Cell {
            volatile long value;

            Cell(long x) { 
              value = x; 
            }
            final boolean cas(long cmp, long val) {
                return UNSAFE.compareAndSwapLong(this, valueOffset, cmp, val);
            }

            // Unsafe mechanics
            private static final sun.misc.Unsafe UNSAFE;
            private static final long valueOffset;
            static {
                try {
                    UNSAFE = sun.misc.Unsafe.getUnsafe();
                    Class<?> ak = Cell.class;
                    valueOffset = UNSAFE.objectFieldOffset
                        (ak.getDeclaredField("value"));
                } catch (Exception e) {
                    throw new Error(e);
                }
            }
    }
}
```
数组的元素是Cell类，可以看到Cell类用Contended注解修饰，这里主要是解决false sharing(伪共享的问题)，具体的可以看这篇文章[伪共享（false sharing）并发编程无声的性能杀手](/posts/50d898f6)。
下面是LongAdder中的部分源码：
``` java
/**
 * 底竞争下直接更新base，类似AtomicLong
 * 高并发下，会将每个线程的操作hash到不同的
 * cells数组中，从而将AtomicLong中更新
 * 一个value的行为优化之后，分散到多个value中
 * 从而降低更新热点，而需要得到当前值的时候，直接
 * 将所有cell中的value与base相加即可，但是跟
 * AtomicLong(compare and change -> xadd)的CAS不同，
 * incrementAndGet操作及其变种
 * 可以返回更新后的值，而LongAdder返回的是void
 */
public class LongAdder {

    public void add(long x) {
        Cell[] as; long b, v; int m; Cell a;
        /**
         *  如果是第一次执行，则直接case操作base
         */
        if ((as = cells) != null || !casBase(b = base, b + x)) {
            boolean uncontended = true;
            /**
             * as数组为空(null或者size为0)
             * 或者当前线程取模as数组大小为空
             * 或者cas更新Cell失败
             */
            if (as == null || (m = as.length - 1) < 0 ||
                (a = as[getProbe() & m]) == null ||
                !(uncontended = a.cas(v = a.value, v + x)))
                longAccumulate(x, null, uncontended);
        }
    }

    public long sum() {
       //通过累加base与cells数组中的value从而获得sum
        Cell[] as = cells; Cell a;
        long sum = base;
        if (as != null) {
            for (int i = 0; i < as.length; ++i) {
                if ((a = as[i]) != null)
                    sum += a.value;
            }
        }
        return sum;
    }
}

  /**
  * openjdk.java.net/jeps/142
  */
  @sun.misc.Contended 
  static final class Cell {
      volatile long value;
      Cell(long x) { value = x; }
      final boolean cas(long cmp, long val) {
          return UNSAFE.compareAndSwapLong(this, valueOffset, cmp, val);
      }

      // Unsafe mechanics
      private static final sun.misc.Unsafe UNSAFE;
      private static final long valueOffset;
      static {
          try {
              UNSAFE = sun.misc.Unsafe.getUnsafe();
              Class<?> ak = Cell.class;
              valueOffset = UNSAFE.objectFieldOffset
                  (ak.getDeclaredField("value"));
          } catch (Exception e) {
              throw new Error(e);
          }
      }
  }

abstract class Striped64 extends Number {

    final void longAccumulate(long x, LongBinaryOperator fn,
                              boolean wasUncontended) {
        int h;
        if ((h = getProbe()) == 0) {
            /**
             * 若getProbe为0，说明需要初始化
             */
            ThreadLocalRandom.current(); // force initialization
            h = getProbe();
            wasUncontended = true;
        }
        boolean collide = false;      // True if last slot nonempty
        /**
         * 失败重试
         */
        for (;;) {
            Cell[] as; Cell a; int n; long v;
            if ((as = cells) != null && (n = as.length) > 0) {
                /**
                 *  若as数组已经初始化,(n-1) & h 即为取模操作，相对 % 效率要更高
                 */
                if ((a = as[(n - 1) & h]) == null) {
                    if (cellsBusy == 0) {       // Try to attach new Cell
                        Cell r = new Cell(x);   // Optimistically create
                        if (cellsBusy == 0 && casCellsBusy()) {//这里casCellsBusy的作用其实就是一个spin lock
                            //可能会有多个线程执行了`Cell r = new Cell(x);`,
                            //因此这里进行cas操作，避免线程安全的问题，同时前面在判断一次
                            //避免正在初始化的时其他线程再进行额外的cas操作
                            boolean created = false;
                            try {               // Recheck under lock
                                Cell[] rs; int m, j;
                                //重新检查一下是否已经创建成功了
                                if ((rs = cells) != null &&
                                    (m = rs.length) > 0 &&
                                    rs[j = (m - 1) & h] == null) {
                                    rs[j] = r;
                                    created = true;
                                }
                            } finally {
                                cellsBusy = 0;
                            }
                            if (created)
                                break;
                            continue;           // Slot 现在是非空了，continue到下次循环重试
                        }
                    }
                    collide = false;
                }
                else if (!wasUncontended)       // CAS already known to fail
                    wasUncontended = true;      // Continue after rehash
                else if (a.cas(v = a.value, ((fn == null) ? v + x :
                                             fn.applyAsLong(v, x))))
                    break;//若cas更新成功则跳出循环，否则继续重试
                else if (n >= NCPU || cells != as) // 最大只能扩容到CPU数目， 或者是已经扩容成功，这里只有的本地引用as已经过期了
                    collide = false;            // At max size or stale
                else if (!collide)
                    collide = true;
                else if (cellsBusy == 0 && casCellsBusy()) {
                    try {
                        if (cells == as) {      // 扩容
                            Cell[] rs = new Cell[n << 1];
                            for (int i = 0; i < n; ++i)
                                rs[i] = as[i];
                            cells = rs;
                        }
                    } finally {
                        cellsBusy = 0;
                    }
                    collide = false;
                    continue;                   // Retry with expanded table
                }
                //重新计算hash(异或)从而尝试找到下一个空的slot
                h = advanceProbe(h);
            }
            else if (cellsBusy == 0 && cells == as && casCellsBusy()) {
                boolean init = false;
                try {                           // Initialize table
                    if (cells == as) {
                        /**
                         * 默认size为2
                         */
                        Cell[] rs = new Cell[2];
                        rs[h & 1] = new Cell(x);
                        cells = rs;
                        init = true;
                    }
                } finally {
                    cellsBusy = 0;
                }
                if (init)
                    break;
            }
            else if (casBase(v = base, ((fn == null) ? v + x : // 若已经有另一个线程在初始化，那么尝试直接更新base
                                        fn.applyAsLong(v, x))))
                break;                          // Fall back on using base
        }
    }

    final boolean casCellsBusy() {
        return UNSAFE.compareAndSwapInt(this, CELLSBUSY, 0, 1);
    }

    static final int getProbe() {
        /**
         * 通过Unsafe获取Thread中threadLocalRandomProbe的值
         */
        return UNSAFE.getInt(Thread.currentThread(), PROBE);
    }

        // Unsafe mechanics
        private static final sun.misc.Unsafe UNSAFE;
        private static final long BASE;
        private static final long CELLSBUSY;
        private static final long PROBE;
        static {
            try {
                UNSAFE = sun.misc.Unsafe.getUnsafe();
                Class<?> sk = Striped64.class;
                BASE = UNSAFE.objectFieldOffset
                    (sk.getDeclaredField("base"));
                CELLSBUSY = UNSAFE.objectFieldOffset
                    (sk.getDeclaredField("cellsBusy"));
                Class<?> tk = Thread.class;
                //返回Field在内存中相对于对象内存地址的偏移量
                PROBE = UNSAFE.objectFieldOffset
                    (tk.getDeclaredField("threadLocalRandomProbe"));
            } catch (Exception e) {
                throw new Error(e);
            }
        }
}
```
由于Cell相对来说比较占内存，因此这里采用懒加载的方式，在无竞争的情况下直接更新base域，在第一次发生竞争的时候(CAS失败)就会创建一个大小为2的cells数组，每次扩容都是加倍，只到达到CPU核数。同时我们知道扩容数组等行为需要只能有一个线程同时执行，因此需要一个锁，这里通过CAS更新cellsBusy来实现一个简单的spin lock。
数组访问索引是通过Thread里的threadLocalRandomProbe域取模实现的，这个域是ThreadLocalRandom更新的，cells的数组大小被限制为CPU的核数，因为即使有超过核数个线程去更新，但是每个线程也只会和一个CPU绑定，更新的时候顶多会有cpu核数个线程，因此我们只需要通过hash将不同线程的更新行为离散到不同的slot即可。
我们知道线程、线程池会被关闭或销毁，这个时候可能这个线程之前占用的slot就会变成没人用的，但我们也不能清除掉，因为一般web应用都是长时间运行的，线程通常也会动态创建、销毁，很可能一段时间后又会被其他线程占用，而对于短时间运行的，例如单元测试，清除掉有啥意义呢？

## 总结
总的来说，LongAdder从性能上来说要远远好于AtomicLong，一般情况下是可以直接替代AtomicLong使用的，Netty也通过一个接口封装了这两个类，在Java8下直接采用LongAdder。但是AtomicLong的一系列方法不仅仅可以自增，还可以获取更新后的值，如果是例如获取一个全局唯一的ID还是采用AtomicLong会方便一点。

## 参考
1. [Java并发工具类之LongAdder原理总结](https://juejin.im/entry/5a5b7e8a51882573443ca7ee)