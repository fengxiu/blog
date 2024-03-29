---
title: 什么是GC
abbrlink: f1158e94
categories:
  - java
  - jvm
tags:
  - 垃圾回收
date: 2019-04-19 15:03:49
updated: 2019-04-19 15:03:49
---
翻译自[what-is-garbage-collection](https://plumbr.io/handbook/what-is-garbage-collection)
本篇文章主要讨论什么是GC，为什么要有GC？

## 什么是GC(Garbage Collection)

乍一看，垃圾收集应该处理名称所暗示的 ----找到并扔掉垃圾。实际上它恰恰相反。垃圾收集器追踪仍在使用的所有对象，并将其余对象标记为垃圾。考虑到这一点，我们开始深入研究Java虚拟机是如何实现内存的自动回收，在Java中这个过程叫做GC。

这篇文章不会一开始就深入GC的细节，而是先介绍垃圾收集器的一般性质，然后介绍核心概念和方法。

免责声明：此内容侧重于Oracle Hotspot和OpenJDK。在其他JVM（例如jRockit或IBM J9）上，本文中涉及的某些方面可能表现不同。
<!-- more  -->

## 手动内存管理

在我们开始介绍垃圾收集之前，让我们快速回顾一下您必须手动并明确地为数据分配和释放内存的日子。如果你忘了释放它，你将无法重复使用内存。内存被声明但没有使用。这种情况称为内存泄漏。

下面是一个C语言写的例子，手动管理内存

```c
int send_request() {
    size_t n = read_size();
    // 申请内存
    int *elements = malloc(n * sizeof(int));

    if(read_elements(n, elements) < n) {
        // elements not freed!
        return -1;
    }

    // …
    // 释放内存
    free(elements)
    return 0;
}
```

我们可以看到，这是很容易忘记释放申请的内存。内存泄漏过问题在去是比现在更常见的问题。你只能通过修复代码来释放它们。因此，更好的方法是自动回收未使用的内存，完全消除人为错误的可能性。这种自动化称为垃圾收集（简称GC）。

### 智能指针

自动化的第一种方法之一是使用析构函数。例如，在C++中vector就是利用使用的这种方式，当它检测到对象不再使用范围时，析构函数将被自动调用：

``` c++
int send_request() {
    size_t n = read_size();
    vector<int> elements = vector<int>(n);

    if(read_elements(elements.size(), &elements[0]) < n) {
        return -1;
    }

    return 0;
}
```

但是在更复杂的情况下，特别是在跨多个线程共享对象时，只有析构函数是不够的。最简单的垃圾收集形式：引用计数。对于每个对象，您只需知道它被引用的次数以及该计数何时达到零，就可以安全地回收该对象。一个众所周知的例子是C++的共享指针：

``` c++
int send_request() {
    size_t n = read_size();
    auto elements = make_shared<vector<int>>();

    // read elements

    store_in_cache(elements);

    // process elements further

    return 0;
}
```

现在，为了避免在下次调用函数时读取元素，我们可能希望缓存它们。在这种情况下，当向量超出范围时销毁它不是一种选择。因此，我们使用shared_ptr。它会跟踪对它的引用数量。传递它时这个数字会增加，而当它离开范围时会减少。一旦引用数达到零，shared_ptr就会自动删除基础向量。

## 自动内存管理

在上面的C++代码中，我们仍然必须明确说明何时需要处理内存管理。但是，如果我们能够使所有对象都以这种方式运行呢？这将非常方便，因为开发人员不再需要考虑自己清理。运行时将自动了解某些内存不再使用并释放它。换句话说，它会自动回收对象，第一个垃圾收集器是在1959年为Lisp创建的，从那时起该技术才得以发展。

### 引用计数

我们用C++的共享指针演示的想法可以应用于所有对象。许多语言，如Perl，Python或PHP都采用这种方法。最好用图片说明：
![引用计数](https://cdn.jsdelivr.net/gh/fengxiu/img/Java-GC-counting-references1.png)
绿色云表示他们指向的对象仍然由程序使用。从技术上讲，这些可能是当前正在执行的方法中的局部变量或静态变量或其他内容。它可能因编程语言而异，因此我们不会在此处关注它。蓝色圆圈是内存中的活动对象，其中的数字表示其引用计数。最后，灰色圆圈是未从任何仍明确使用的对象引用的对象（这些对象由绿色云直接引用）。灰色对象因此是垃圾，可以由垃圾收集器清理。这一切看起来都很好，不是吗？嗯，确实如此，但整个方法都有很大的缺点。由于循环引用，它们的引用计数不为零，因此很容易最终得到一个分离的对象循环，这些对象都不在范围内。这是一个例子：
![Java-GC-cyclical-dependencies](https://cdn.jsdelivr.net/gh/fengxiu/img/Java-GC-cyclical-dependencies.png)

### 标记-清除

首先，JVM更具体地说明了对象的可达性。我们有一个非常具体和明确的对象集，称为GC ROOTS，而不是我们在前面章节中看到的模糊定义的绿云。

* 局部变量
* 活动线程
* 静态字段
* JNI引用

JVM用于跟踪所有可到达（实时）对象并确保不可访问对象声明的内存可以重用的方法称为标记和清除算法。它包括两个步骤：

* **标记：**正在遍历所有可到达的对象，从GC ROOTS开始并在本机内存中保留有关所有和GC ROOTS对象的关联的对象。
* **扫描：**确保下一次分配可以重用不可到达对象占用的内存地址。

JVM中的不同GC算法（例如并行清除，并行标记+复制或CMS）正在以稍微不同的方式实现这些阶段，但在概念级别，该过程仍然类似于上述两个步骤。关于这种方法的一个至关重要的事情是循环不再泄漏：
![Java-GC-mark-and-sweep](https://cdn.jsdelivr.net/gh/fengxiu/img/Java-GC-mark-and-sweep.png)

不太好的事情是需要停止应用程序线程以便于收集无用对象的程序执行，因为如果它们一直在不断变化，你就无法真正计算引用。当应用程序暂时停止以便JVM可以专门来进行信息的收集，这种情况称为“stop the world”（STW）。它们可能由于多种原因而发生，但垃圾收集是迄今为止最受欢迎的一种。
