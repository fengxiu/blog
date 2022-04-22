---
title: Java Reference详解
author: 枫秀天涯
tags:
  - 引用
categories:
  - java
  - jvm
abbrlink: 2e7bd07f
date: 2019-01-04 10:25:00
updated: 2019-01-04 10:25:00
---

Java引用体系中我们最熟悉的就是强引用类型，如 `A a= new A()`;这是我们经常说的强引用StrongReference，jvm gc时会检测对象是否存在强引用，如果存在由根对象对其有传递的强引用，则不会对其进行回收，即使内存不足抛出OutOfMemoryError。

除了强引用外，Java还引入了SoftReference（软引用），WeakReference（弱引用），PhantomReference（虚引用），FinalReference ，这些类放在java.lang.ref包下，类的继承体系如下图。

![类图](https://raw.githubusercontent.com/fengxiu/img/master/21153037_ubGO.png)

Java额外引入这个四种类型引用主要目的是在jvm在gc时，按照引用类型的不同，在回收时采用不同的逻辑。可以把这些引用看作是对对象的一层包裹，jvm根据外层不同的包裹，对其包裹的对象采用不同的回收策略，或特殊逻辑处理。 这几种类型的引用主要在jvm内存缓存、资源释放、对象可达性事件处理等场景会用到。

<!-- more -->

本文会首先讲解SoftReference，WeakReference和PhantomReference的使用，然后在对Reference和ReferenceQueue的源码进行分析。至于FinalRefeence会在另一篇文章中讲解。

主要内容如下

1. 对象可达性判断
2. ReferenceQueue 简介
3. SoftReference简介及使用
4. WeakReference简介及使用
5. PhantomReference简介及使用
6. 总结
7. 
<!-- more -->

**本文名称使用说明**：Reference指代引用对象本身，Referent指代被引用对象，下文介绍会以Reference，Referent形式出现。

## 对象可达性判断

jvm gc时，判断一个对象是否存在引用时，都是从根结合引用(Root Set of References)开始去标识,往往到达一个对象的引用路径会存在多条，如下图。

![可达性图](https://static.oschina.net/uploads/img/201701/21165610_kkb9.png)

那么 垃圾回收时会依据两个原则来判断对象的可达性：

- 单一路径中，以最弱的引用为准
- 多路径中，以最强的引用为准

例如Obj4的引用，存在3个路径:1->6、2->5、3->4, 那么从根对象到Obj4最强的引用是2->5，因为它们都是强引用。如果仅仅存在一个路径对Obj4有引用时，比如现在只剩1->6,那么根对象到Obj4的引用就是以最弱的为准，就是SoftReference引用,Obj4就是softly-reachable对象。如果是WeakReference引用，就称作weakly-reachable对象。只要一个对象是强引用可达，那么这个对象就不会被gc，即使发生OOM也不会回收这个对象。

## ReferenceQueue 简介

引用队列，在检测到适当的可到达性更改后，即Referent对象的可达性发生适当的改变时，垃圾回收器将已注册的引用对象reference添加到该队列中。

简单用下面代码来说明

```java
Object object = new Object();
ReferenceQueue  queue = new ReferenceQueue();
SoftReference<Objecct> soft = new SoftReference<>(object,queue);
object = null;
Systen.gc();
//休眠一会，等待gc完成
Thread.sleep(100);
System.out.println(queue.poll() == soft);
System.out.println(soft.get() == null)
```

输出结果：

```java
true
true
```

结果分析：

对应上面第一句话，就是说当soft引用对象包含的object对象被gc之后，其可达性就会发生改变，同时会将soft对象注册到queue这个引用队列中。可以使用poll()这个方法取出被所有可达性改变的引用对象。

ReferenceQueue实现了一个队列的入队(enqueue)和出队(poll,remove)操作，内部元素就是泛型的Reference，并且Queue的实现，是由Reference自身的链表结构( 单向循环链表 )所实现的。

ReferenceQueue名义上是一个队列，但实际内部并非有实际的存储结构，它的存储是依赖于内部节点之间的关系来表达。可以理解为queue是一个类似于链表的结构，这里的节点其实就是reference本身。可以理解为queue为一个链表的容器，其自己仅存储当前的head节点，而后面的节点由每个reference节点自己通过next来保持即可。

因此可以看出，当reference与referenQueue联合使用的主要作用就是当reference指向的referent回收时，提供一种通知机制，通过queue取到这些reference，来做额外的处理工作。当然，如果我们不需要这种通知机制，在创建Reference对象时不传入queue对象即可。

## java引用种类简介


* 强引用是最传统的“引用”的定义，是指在程序代码之中普遍存在的引用赋值，即类似“Object obj=new Object()”这种引用关系。无论任何情况下，只要强引用关系还存在，垃圾收集器就永远不会回 收掉被引用的对象。
* 软引用是用来描述一些还有用，但非必须的对象。只被软引用关联着的对象，在系统将要发生内 存溢出异常前，会把这些对象列进回收范围之中进行第二次回收，如果这次回收还没有足够的内存， 才会抛出内存溢出异常。在JDK 1.2版之后提供了SoftReference类来实现软引用。
* 弱引用也是用来描述那些非必须对象，但是它的强度比软引用更弱一些，被弱引用关联的对象只 能生存到下一次垃圾收集发生为止。当垃圾收集器开始工作，无论当前内存是否足够，都会回收掉只 被弱引用关联的对象。在JDK 1.2版之后提供了WeakReference类来实现弱引用。
* 虚引用也称为“幽灵引用”或者“幻影引用”，它是最弱的一种引用关系。一个对象是否有虚引用的 存在，完全不会对其生存时间构成影响，也无法通过虚引用来取得一个对象实例。为一个对象设置虚 引用关联的唯一目的只是为了能在这个对象被收集器回收时收到一个系统通知。

## SoftReference简介及使用

根据上面我们讲的对象可达性原理，我们把一个对象存在根对象对其有直接或间接的SoftReference，并没有其他强引用路径，我们把该对象成为softly-reachable对象。JVM保证在抛出OutOfMemoryError前会回收这些softly-reachable对象。JVM会根据当前内存的情况来决定是否回收softly-reachable对象，但只要referent有强引用存在，该referent就一定不会被清理，因此SoftReference适合用来实现memory-sensitive caches。

可见，SoftReference在一定程度上会影响JVM GC的，例如softly-reachable对应的referent多次垃圾回收仍然不满足释放条件，那么它会停留在heap old区，占据很大部分空间，在JVM没有抛出OutOfMemoryError前，它有可能会导致频繁的Full GC。

下面是我使用SoftReference做的一个简单的缓存图片的测试

```java
public class SoftReferenceImageTest {
    public static void main(String[] args) throws IOException {
        testImageLoad();
    }

    public static void testImageLoad() throws IOException {
        String s = "xmind.png";
        HashMap<String, SoftReference<byte[]>> map = new HashMap<>(100);
        for (int i = 0; i < 100; i++) {
            FileInputStream inputStream = new FileInputStream(s);
            byte[] bytes = new byte[(int) inputStream.getChannel().size()];
            while (inputStream.read(bytes) > 0) ;
            inputStream.close();
            map.put(s + i, new SoftReference<byte[]>(bytes));
        }
        for (int i = 0; i < map.size(); i++) {

            Optional.ofNullable(map.get(s + i))
                    .filter(softReference -> softReference.get() != null)
                    .ifPresent(softReference -> {
                        System.out.println("ok");
                    });
        }

    }
}
```

运行这段代码时，加上jvm参数(**-Xms10M -Xmx10M -Xmn5M -XX:+PrintGCDetails**)

运行结果为空，因为我加载的图片是5M，而分配给运行时的jvm是10M,所以每次加载完一张图片之后，在下一次加载就会清理这个SoftReference对象，因此最后得到的结果为空。

## WeakReference简介及使用

当一个对象被WeakReference引用时，处于weakly-reachable状态时，只要发生GC时，就会被清除，同时会把WeakReference注册到引用队列中(如果存在的话)。 WeakReference不阻碍或影响它们对应的referent被终结(finalized)和回收(reclaimed)，因此，WeakReference经常被用作实现规范映射(canonicalizing mappings)。相比SoftReference来说，WeakReference对JVM GC几乎是没有影响的。

下面是一个简单的demo

```java
public class WeakReferenceTest {
    public static void main(String[] args) {
        weak();
    }

    public static void weak() {
        ReferenceQueue<Integer> referenceQueue = new ReferenceQueue<>();
        WeakReference<Integer> weak = new WeakReference<Integer>(new Integer(100), 
                                                                 referenceQueue);
        System.out.println("GC 前===>" + weak.get());
        System.gc();
        System.out.println("GC 后===>" + weak.get());
      
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println(referenceQueue.poll() == weak);
    }
}
```

运行结果

```java
GC 前===>100
GC 后===>null
true
```

结果分析：

从上面我么可以看到，WeakReference所对应的Referent对象被回收了，因此验证了只要发生gc，weakly-reachable对象就会被gc回收。

另外可以查看这篇文章，仔细说明jdk中WeakHashMap在Tomact中使用的场景[WeakHashMap使用场景](https://blog.csdn.net/kaka0509/article/details/73459419)

## PhantomReference简介及使用

PhantomReference 不同于WeakReference、SoftReference，它存在的意义不是为了获取referent,因为你也永远获取不到，因为它的get如下

```java
 public T get() {
        return null;
 }
```

PhantomReference主要作为其指向的referent被回收时的一种通知机制,它就是利用上文讲到的ReferenceQueue实现的。当referent被gc回收时，JVM自动把PhantomReference对象(reference)本身加入到ReferenceQueue中，像发出信号通知一样，表明该reference指向的referent被回收。然后可以通过去queue中取到reference，此时说明其指向的referent已经被回收，可以通过这个通知机制来做额外的清场工作。 因此有些情况可以用PhantomReference 代替finalize()，做资源释放更明智。

下面举个例子，用PhantomReference来自动关闭文件流。

```java
public class ResourcePhantomReference<T> extends PhantomReference<T> {

    private List<Closeable> closeables;

    public ResourcePhantomReference(T referent, ReferenceQueue<? super T> q, List<Closeable> resource) {
        super(referent, q);
        closeables = resource;
    }

    public void cleanUp() {
        if (closeables == null || closeables.size() == 0)
            return;
        for (Closeable closeable : closeables) {
            try {
                closeable.close();
                System.out.println("clean up:"+closeable);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}
```

```java
public class ResourceCloseDeamon extends Thread {

    private static ReferenceQueue QUEUE = new ReferenceQueue();

    //保持对reference的引用,防止reference本身被回收
    private static List<Reference> references=new ArrayList<>();
    @Override
    public void run() {
        this.setName("ResourceCloseDeamon");
        while (true) {
            try {
                ResourcePhantomReference reference = (ResourcePhantomReference) QUEUE.remove();
                reference.cleanUp();
                references.remove(reference);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    public static void register(Object referent, List<Closeable> closeables) {
        references.add(new ResourcePhantomReference(referent,QUEUE,closeables));
    }


}
```

```java
public class FileOperation {

    private FileOutputStream outputStream;

    private FileInputStream inputStream;

    public FileOperation(FileInputStream inputStream, FileOutputStream outputStream) {
        this.outputStream = outputStream;
        this.inputStream = inputStream;
    }

    public void operate() {
        try {
            inputStream.getChannel().transferTo(0, inputStream.getChannel().size(), outputStream.getChannel());
        } catch (IOException e) {
            e.printStackTrace();
        }
    }


}
```

测试代码：

```java
public class PhantomTest {

    public static void main(String[] args) throws Exception {
        //打开回收
        ResourceCloseDeamon deamon = new ResourceCloseDeamon();
        deamon.setDaemon(true);
        deamon.start();

        // touch a.txt b.txt
        // echo "hello" > a.txt

        //保留对象,防止gc把stream回收掉,其不到演示效果
        List<Closeable> all=new ArrayList<>();
        FileInputStream inputStream;
        FileOutputStream outputStream;

        for (int i = 0; i < 100000; i++) {
            inputStream = new FileInputStream("/Users/robin/a.txt");
            outputStream = new FileOutputStream("/Users/robin/b.txt");
            FileOperation operation = new FileOperation(inputStream, outputStream);
            operation.operate();
            TimeUnit.MILLISECONDS.sleep(100);

            List<Closeable>closeables=new ArrayList<>();
            closeables.add(inputStream);
            closeables.add(outputStream);
            all.addAll(closeables);
            ResourceCloseDeamon.register(operation,closeables);
            //用下面命令查看文件句柄,如果把上面register注释掉,就会发现句柄数量不断上升
            //jps | grep PhantomTest | awk '{print $1}' |head -1 | xargs  lsof -p  | grep /User/robin
            System.gc();

        }


    }
}
```

运行上面的代码，通过jps | grep PhantomTest | awk '{print $1}' |head -1 | xargs lsof -p | grep /User/robin ｜ wc -l 可以看到句柄没有上升，而去掉ResourceCloseDeamon.register(operation,closeables);时，句柄就不会被释放。

PhantomReference使用时一定要传一个referenceQueue,当然也可以传null,但是这样就毫无意义了。因为PhantomReference的get结果为null,如果在把queue设为null,那么在其指向的referent被回收时，reference本身将永远不会可能被加入队列中，这里我们可以看ReferenceQueue的源码。

## Reference和ReferenceQueue源码分析

### Reference源码分析

java.lang.ref.Reference 为 软（soft）引用、弱（weak）引用、虚（phantom）引用的父类。

因为Reference对象和垃圾回收密切配合实现，该类可能不能被直接子类化。
可以理解为Reference的直接子类都是由jvm定制化处理的,因此在代码中直接继承于Reference类型没有任何作用。但可以继承jvm定制的Reference的子类。
例如：Cleaner 继承了 PhantomReference

 ```java
 public class Cleaner extends PhantomReference<Object>
 ```

老规矩，先看下Reference的重要属性，方便后面讲解函数的时候使用

Reference链表结构内部主要的成员有

**pending 和 discovered**

```java
    /* List of References waiting to be enqueued.  The collector adds
     * References to this list, while the Reference-handler thread removes
     * them.  This list is protected by the above lock object. The
     * list uses the discovered field to link its elements.
     */
    private static Reference<Object> pending = null;

    /* When active:   next element in a discovered reference list maintained by GC (or this if last)
     *     pending:   next element in the pending list (or null if last)
     *   otherwise:   NULL
     */
    transient private Reference<T> discovered;  /* used by VM */
```

上面俩个字段都是jvm来赋值。

pending: 可以理解为jvm在gc时会将要处理的对象放到这个静态字段上面。同时，另一个字段discovered：。

discovered：表示要处理下一个对象，当是最后一个元素时discovered=this

通过这俩个字段，可以将jvm在gc时处理的引用对象集合变成一个链表，通过discovered插入下一个待处理的对象。

在处理这些已经被GC处理过的对象时，通过discovered不断地拿到下一个对象，然后处理对象的pending，直到最后没有可处理的对象。

**referent**

```java
 private T referent; /* Treated specially by GC */
 ```

referent字段由GC特别处理,表示其引用的对象，即我们在构造的时候需要被包装在其中的对象。对象即将被回收的定义：此对象除了被reference引用之外没有其它引用了( 并非确实没有被引用，而是gcRoot可达性不可达,以避免循环引用的问题 )。如果一旦被回收，则会直接置为null，而外部程序可通过引用对象本身( 而不是referent，这里是reference#get() )了解到回收行为的产生( PhntomReference除外 )。

**next**

```java
/* When active:   NULL
    *     pending:   this
    *    Enqueued:   next reference in queue (or this if last)
    *    Inactive:   this
    */
@SuppressWarnings("rawtypes")
volatile Reference next;
```

next：即描述当前引用节点所存储的下一个即将被处理的节点。但next仅在放到queue中才会有意义( 因为，只有在enqueue的时候，会将next设置为下一个要处理的Reference对象 )。为了描述相应的状态值，在放到队列当中后，其queue就不会再引用这个队列了。而是引用一个特殊的ENQUEUED。因为已经放到队列当中，并且不会再次放到队列当中。

**lock**

```java
static private class Lock { }
private static Lock lock = new Lock();
```

lock：在垃圾收集中用于同步的对象。收集器必须获取该锁在每次收集周期开始时。因此这是至关重要的：任何持有该锁的代码应该尽快完成，不分配新对象，并且避免调用用户代码。

**pending**

```java
/* List of References waiting to be enqueued.  The collector adds
    * References to this list, while the Reference-handler thread removes
    * them.  This list is protected by the above lock object. The
    * list uses the discovered field to link its elements.
    */
private static Reference<Object> pending = null;
```

pending：等待被入队的引用列表。收集器会添加引用到这个列表，直到Reference-handler线程移除了它们。这个列表被上面的lock对象保护。这个列表使用discovered字段来连接它自己的元素( 即pending的下一个元素就是discovered对象 )。

**queue**

```java
 volatile ReferenceQueue<? super T> queue;
```

queue：是对象即将被回收时所要通知的队列。当对象即被回收时，整个reference对象( 而不是被回收的对象 )会被放到queue里面，然后外部程序即可通过监控这个queue拿到相应的数据了。

这里的queue( 即，ReferenceQueue对象 )名义上是一个队列，但实际内部并非有实际的存储结构，它的存储是依赖于内部节点之间的关系来表达。可以理解为queue是一个类似于链表的结构，这里的节点其实就是reference本身。可以理解为queue为一个链表的容器，其自己仅存储当前的head节点，而后面的节点由每个reference节点自己通过next来保持即可。

Reference实例( 即Reference中的真是引用对象referent )的4中可能的内部状态值
Queue的另一个作用是可以区分不同状态的Reference。

Reference有4种状态，不同状态的reference其queue也不同：

* Active：新创建的引用对象都是这个状态，在 GC 检测到引用对象已经到达合适的reachability时，GC 会根据引用对象是否在创建时制定ReferenceQueue参数进行状态转移，如果指定了，那么转移到Pending，如果没指定，转移到Inactive。
* Pending：pending-Reference列表中的引用都是这个状态，它们等着被内部线程ReferenceHandler处理入队（会调用ReferenceQueue.enqueue方法）。没有注册的实例不会进入这个状态。
* Enqueued：相应的对象已经为待回收，并且相应的引用对象已经放到queue当中了。准备由外部线程来询问queue获取相应的数据。调用ReferenceQueue.enqueued方法后的Reference处于这个状态中。当Reference实例从它的ReferenceQueue移除后，它将成为Inactive。没有注册的实例不会进入这个状态。
* Inactive：即此对象已经由外部从queue中获取到，并且已经处理掉了。即意味着此引用对象可以被回收，并且对内部封装的对象也可以被回收掉了( 实际的回收运行取决于clear动作是否被调用 )。可以理解为进入到此状态的肯定是应该被回收掉的。一旦一个Reference实例变为了Inactive，它的状态将不会再改变。

jvm并不需要定义状态值来判断相应引用的状态处于哪个状态，只需要通过计算next和queue即可进行判断。

* Active：queue为创建一个Reference对象时传入的ReferenceQueue对象；如果ReferenceQueue对象为空或者没有传入ReferenceQueue对象，则为ReferenceQueue.NULL；next==null；
* Pending：queue为初始化时传入ReferenceQueue对象；next==this(由jvm设置)；
* Enqueue：当queue!=null && queue != ENQUEUED 时；设置queue为ENQUEUED；next为下一个要处理的reference对象，或者若为最后一个了next==this；
* Inactive：queue = ReferenceQueue.NULL; next = this.

通过这个组合，收集器只需要检测next属性为了决定是否一个Reference实例需要特殊的处理：如果next==null，则实例是active；如果next!=null，为了确保并发收集器能够发现active的Reference对象，而不会影响可能将enqueue()方法应用于这些对象的应用程序线程，收集器应通过discovered字段链接发现的对象。discovered字段也用于链接pending列表中的引用对象。

![](https://raw.githubusercontent.com/fengxiu/img/master/20220421205039.png)

![](https://raw.githubusercontent.com/fengxiu/img/master/20220421205054.png)

外部从queue中获取Reference

* WeakReference对象进入到queue之后,相应的referent为null。
* SoftReference对象，如果对象在内存足够时，不会进入到queue，自然相应的referent不会为null。如果需要被处理( 内存不够或其它策略 )，则置相应的referent为null，然后进入到queue。通过debug发现，SoftReference是pending状态时，referent就已经是null了，说明此事referent已经被GC回收了。
* FinalReference对象，因为需要调用其finalize对象，因此其reference即使入queue，其referent也不会为null，即不会clear掉。
* PhantomReference对象，因为本身get实现为返回null。因此clear的作用不是很大。因为不管enqueue还是没有，都不会清除掉。

如果PhantomReference对象不管enqueue还是没有，都不会清除掉reference对象，那么怎么办？这个reference对象不就一直存在这了？而且JVM是会直接通过字段操作清除相应引用的，那么是不是JVM已经释放了系统底层资源，但java代码中该引用还未置null？
 
不会的，虽然PhantomReference有时候不会调用clear，如Cleaner对象 。但Cleaner的clean()方法只调用了remove(this)，这样当clean()执行完后，Cleaner就是一个无引用指向的对象了，也就是可被GC回收的对象。

* active ——> pending ：Reference#tryHandlePending
* pending ——> enqueue ：ReferenceQueue#enqueue
* enqueue ——> inactive ：Reference#clear

![](https://raw.githubusercontent.com/fengxiu/img/master/20220421205346.png)

**构造函数**
其内部提供2个构造函数，一个带queue，一个不带queue。其中queue的意义在于，我们可以在外部对这个queue进行监控。即如果有对象即将被回收，那么相应的reference对象就会被放到这个queue里。我们拿到reference，就可以再作一些事务。

而如果不带的话，就只有不断地轮询reference对象，通过判断里面的get是否返回null( phantomReference对象不能这样作，其get始终返回null，因此它只有带queue的构造函数 )。这两种方法均有相应的使用场景，取决于实际的应用。如weakHashMap中就选择去查询queue的数据，来判定是否有对象将被回收。而ThreadLocalMap，则采用判断get()是否为null来作处理。

```java
Reference(T referent) {
    this(referent, null);
}

Reference(T referent, ReferenceQueue<? super T> queue) {
    this.referent = referent;
    this.queue = (queue == null) ? ReferenceQueue.NULL : queue;
}
```

如果我们在创建一个引用对象时，指定了ReferenceQueue，那么当引用对象指向的对象达到合适的状态（根据引用类型不同而不同）时，GC会把引用对象本身添加到这个队列中，方便我们处理它，因为引用对象指向的对象GC会自动清理，但是引用对象本身也是对象（是对象就占用一定资源），所以需要我们自己清理。

**重要方法**
clear()

    /**
     * Clears this reference object.  Invoking this method will not cause this
     * object to be enqueued.
     *
     * <p> This method is invoked only by Java code; when the garbage collector
     * clears references it does so directly, without invoking this method.
     */
    public void clear() {
        this.referent = null;
    }
调用此方法不会导致此对象入队。此方法仅由Java代码调用；当垃圾收集器清除引用时，它直接执行，而不调用此方法。
 clear的语义就是将referent置null。
 清除引用对象所引用的原对象，这样通过get()方法就不能再访问到原对象了( PhantomReference除外 )。从相应的设计思路来说，既然都进入到queue对象里面，就表示相应的对象需要被回收了，因为没有再访问原对象的必要。此方法不会由JVM调用，而JVM是直接通过字段操作清除相应的引用，其具体实现与当前方法相一致。

ReferenceHandler线程，其优先级最高，可以理解为需要不断地处理引用对象

```java
    static {
        ThreadGroup tg = Thread.currentThread().getThreadGroup();
        for (ThreadGroup tgn = tg;
             tgn != null;
             tg = tgn, tgn = tg.getParent());
        Thread handler = new ReferenceHandler(tg, "Reference Handler");
        /* If there were a special system-only priority greater than
         * MAX_PRIORITY, it would be used here
         */
        handler.setPriority(Thread.MAX_PRIORITY);
        handler.setDaemon(true);
        handler.start();

        // provide access in SharedSecrets
        SharedSecrets.setJavaLangRefAccess(new JavaLangRefAccess() {
            @Override
            public boolean tryHandlePendingReference() {
                return tryHandlePending(false);
            }
        });
    }

    private static class ReferenceHandler extends Thread {

        private static void ensureClassInitialized(Class<?> clazz) {
            try {
                Class.forName(clazz.getName(), true, clazz.getClassLoader());
            } catch (ClassNotFoundException e) {
                throw (Error) new NoClassDefFoundError(e.getMessage()).initCause(e);
            }
        }

        static {
            // pre-load and initialize InterruptedException and Cleaner classes
            // so that we don't get into trouble later in the run loop if there's
            // memory shortage while loading/initializing them lazily.
            ensureClassInitialized(InterruptedException.class);
            ensureClassInitialized(Cleaner.class);
        }

        ReferenceHandler(ThreadGroup g, String name) {
            super(g, name);
        }

        public void run() {
            while (true) {
                tryHandlePending(true);
            }
        }
    }
```

tryHandlePending()

```java
    /**
     * Try handle pending {@link Reference} if there is one.<p>
     * Return {@code true} as a hint that there might be another
     * {@link Reference} pending or {@code false} when there are no more pending
     * {@link Reference}s at the moment and the program can do some other
     * useful work instead of looping.
     *
     * @param waitForNotify if {@code true} and there was no pending
     *                      {@link Reference}, wait until notified from VM
     *                      or interrupted; if {@code false}, return immediately
     *                      when there is no pending {@link Reference}.
     * @return {@code true} if there was a {@link Reference} pending and it
     *         was processed, or we waited for notification and either got it
     *         or thread was interrupted before being notified;
     *         {@code false} otherwise.
     */
    static boolean tryHandlePending(boolean waitForNotify) {
        Reference<Object> r;
        Cleaner c;
        try {
            // 加锁是为了防止竞争产生同步问题
            synchronized (lock) {
                if (pending != null) {
                    r = pending;
                    // 'instanceof' might throw OutOfMemoryError sometimes
                    // so do this before un-linking 'r' from the 'pending' chain...
                    c = r instanceof Cleaner ? (Cleaner) r : null;
                    // unlink 'r' from 'pending' chain
                    pending = r.discovered;
                    r.discovered = null;
                } else {
                    // The waiting on the lock may cause an OutOfMemoryError
                    // because it may try to allocate exception objects.
                    if (waitForNotify) {
                        lock.wait();
                    }
                    // retry if waited
                    return waitForNotify;
                }
            }
        } catch (OutOfMemoryError x) {
            // Give other threads CPU time so they hopefully drop some live references
            // and GC reclaims some space.
            // Also prevent CPU intensive spinning in case 'r instanceof Cleaner' above
            // persistently throws OOME for some time...
            Thread.yield();
            // retry
            return true;
        } catch (InterruptedException x) {
            // retry
            return true;
        }

        // Fast path for cleaners
        if (c != null) {
            c.clean();
            return true;
        }

        ReferenceQueue<? super Object> q = r.queue;
        if (q != ReferenceQueue.NULL) q.enqueue(r);
        return true;
    }
```

这个线程在Reference类的static构造块中启动，并且被设置为高优先级和daemon状态。此线程要做的事情，是不断的检查pending是否为null，如果pending不为null，则将pending进行enqueue，否则线程进入wait状态。

由此可见，pending是由jvm来赋值的，当Reference内部的referent对象的可达状态改变时，jvm会将Reference对象放入pending链表。并且这里enqueue的队列是我们在初始化( 构造函数 )Reference对象时传进来的queue，如果传入了null( 实际使用的是ReferenceQueue.NULL )，则ReferenceHandler则不进行enqueue操作，所以只有非RefernceQueue.NULL的queue才会将Reference进行enqueue。

### ReferenceQueue源码

引用队列，在检测到适当的可到达性更改后，垃圾回收器将已注册的引用对象添加到该队列中

实现了一个队列的入队(enqueue)和出队(poll还有remove)操作，内部元素就是泛型的Reference，并且Queue的实现，是由Reference自身的链表结构( 单向循环链表 )所实现的。

ReferenceQueue名义上是一个队列，但实际内部并非有实际的存储结构，它的存储是依赖于内部节点之间的关系来表达。可以理解为queue是一个类似于链表的结构，这里的节点其实就是reference本身。可以理解为queue为一个链表的容器，其自己仅存储当前的head节点，而后面的节点由每个reference节点自己通过next来保持即可。

**属性**
**head**：始终保存当前队列中最新要被处理的节点，可以认为queue为一个后进先出的队列。当新的节点进入时，采取以下的逻辑：

```java
    r.next = (head == null) ? r : head;
    head = r;
```

然后，在获取的时候，采取相应的逻辑：

```java
Reference<? extends T> r = head;
        if (r != null) {
            head = (r.next == r) ?
                null :
                r.next; // Unchecked due to the next field having a raw type in Reference
            r.queue = NULL;
            r.next = r;
```

方法
**enqueue()**：待处理引用入队

```java
    boolean enqueue(Reference<? extends T> r) { /* Called only by Reference class */
        synchronized (lock) {
            // Check that since getting the lock this reference hasn't already been
            // enqueued (and even then removed)
            ReferenceQueue<?> queue = r.queue;
            if ((queue == NULL) || (queue == ENQUEUED)) {
                return false;
            }
            assert queue == this;
            r.queue = ENQUEUED;
            r.next = (head == null) ? r : head;
            head = r;
            queueLength++;
            if (r instanceof FinalReference) {
                sun.misc.VM.addFinalRefCount(1);
            }
            lock.notifyAll(); // ①
            return true;
        }
    }
```

lock.notifyAll(); 通知外部程序之前阻塞在当前队列之上的情况。( 即之前一直没有拿到待处理的对象，如ReferenceQueue的remove()方法 )

## 总结

引用类型对比

| 序号 | 引用类型 | 取得目标对象方式 | 垃圾回收条件   | 是否可能内存泄漏 |
| ---- | -------- | ---------------- | -------------- | ---------------- |
| 1    | 强引用   | 直接调用         | 不回收         | 可能             |
| 2    | 软引用   | 通过 get()方法   | 视内存情况回收 | 不可能           |
| 3    | 弱引用   | 通过 get()方法   | 永远回收       | 不可能           |
| 4    | 虚引用   | 无法取得         | 不回收         | 可能             |

通过对SoftReference，WeakReference，PhantomReference 的介绍，可以看出JDK提供这些类型的reference 主要是用来和GC交互的，根据reference的不同，让JVM采用不同策略来进行对对象的回收(reclaim)。softly-reachable的referent在保证在OutOfMemoryError之前回收对象，weakly-reachable的referent在发生GC时就会被回收,同时这些reference和referenceQueue在一起提供通知机制，PhantomReference的作用就是仅仅就是提供对象回收通知机制，Finalizer借助这种机制实现referent的finalize执行，SoftReference、WeakReference也可以配合referenceQueue使用，实现对象回收通知机制。

## 参考

1. [Java中的四种引用类型](https://www.jianshu.com/p/147793693edc)
2. [Java Reference详解](https://my.oschina.net/robinyao/blog/829983)
3. [用弱引用堵住内存泄漏](https://www.ibm.com/developerworks/cn/java/j-jtp11225/)
4. [Reference及ReferenceQueue 详解](https://cloud.tencent.com/developer/article/1152608)