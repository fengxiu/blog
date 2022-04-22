---
title: Java集合系列14之WeakHashMap源码解析和使用示例
tags:
  - 集合
categories:
  - java
  - collections
abbrlink: 8ab0f653
date: 2019-03-04 23:58:00
updated: 2019-03-04 23:58:00
---

WeakHashMap，从名字可以看出它是某种Map。它的特殊之处在于WeakHashMap里的entry可能会被GC自动删除，即使程序员没有调用remove()或者clear()方法。

WeakHashMap 的这个特点特别适用于需要缓存的场景。在缓存场景下，由于内存是有限的，不能缓存所有对象；对象缓存命中可以提高系统效率，但缓存MISS也不会造成错误，因为可以通过计算重新得到。 要明白 WeakHashMap 的工作原理，还需要引入一个概念 : 弱引用(WeakReference)。我们都知道Java中内存是通过GC自动管理的，GC会在程序运行过程中自动判断哪些对象是可以被回收的，并在合适的时机进行内存释放。GC判断某个对象是否可被回收的依据是，是否有有效的引用指向该对象。如果没有有效引用指向该对象(基本意味着不存在访问该对象的方式)，那么该对象就是可回收的。这里的有效引用 并不包括弱引用。也就是说，虽然弱引用可以用来访问对象，但进行垃圾回收时弱引用并不会被考虑在内，仅有弱引用指向的对象仍然会被GC回收。 WeakHashMap 内部是通过弱引用来管理entry的，弱引用的特性对应到 WeakHashMap 上意味着什么呢？将一对key, value放入到 WeakHashMap 里并不能避免该key值被GC回收，除非在 WeakHashMap 之外还有对该key的强引用。

关于强引用，弱引用等概念可以参考[Java Reference详解](/archives/2e7bd07f.html)，这里只需要知道Java中引用也是分种类的，并且不同种类的引用对GC的影响不同就够了。

具体的实现和HashMap基本一致，只是当多个对象的hash冲突时，在hashMap中会形成链表或者红黑树，但是在WeakHashMap只会存在链表的情形。其实个人看来，使用红黑树反而会增加其成本，好不容易维护好了一颗树，但是不知道什么时候这棵树就被删除。因此还不如不维护的好。
