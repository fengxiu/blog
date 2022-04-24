---
title: java集合系列01之 总体框架
tags:
  - 集合
categories:
  - java
  - collections
abbrlink: 2d62f277
date: 2019-03-04 09:08:00
updated: 2019-03-04 09:08:00
---
集合框架是Java提供的工具包，包含了一些常用的数据结构：集合、链表、队列、栈、数组、映射等，方便我们日常开发。Java集合工具包位置是java.util.*。

Java集合主要可以划分为4个部分：列表（List）、集合（Set）、映射（Map）、工具类。

下图是java集合的整体框架图：

![collection](https://cdn.jsdelivr.net/gh/fengxiu/img/Collection.png)

![集合](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-154.png)

[java集合具体的官方描述在这](https://docs.oracle.com/javase/tutorial/collections/index.html)

<!--more -->

**大致说明：**

看上面的框架图，先抓住它的主干，即Collection和Map。

* **Collection**：是一个接口，是高度抽象出来的集合，它包含了集合的基本操作和属性。 Collection包含了List和Set两大分支。这和我们数学里面学到的集合是一样的List允许有重复的数据，Set不允许有重复数据。

* **List**：是一个有序的队列，允许有重复元素，每一个元素都有对应的整数索引，第一个元素的索引值是0。List的实现类有LinkedList, ArrayList, Vector, Stack。

* **Set**：是一个不允许有重复元素的集合，这也是他和List的最大区别。Set的实现类有HastSet和TreeSet。HashSet依赖于HashMap，它实际上是通过HashMap实现的；TreeSet依赖于TreeMap，它实际上是通过TreeMap实现的。

* **Queue**：是一个队列接口，保证先进先出（FIFO）。

* **Deque**：是一个双端队列接口，用于实现队列和栈俩种数据结构。

* **Map**：是一个映射接口，即key-value键值对。key值是不允许有重复。主要实现有HashMap，TreeMap，WeakHashMap，Hashtable。

另外，集合包提供了俩个工具类`Arrays`和`Collections`。`Arrays`用于操作数组比如排序，将数组转换成集合等操作。`Collections`:包含了多个静态方法，来方便创建集合和操作集合等。

有了上面的整体框架之后，我们接下来对每个类分别进行分析。

## 参考

本系列博客主要是参考下面博客

1. [java集合系列目录(Category)](https://www.cnblogs.com/skywang12345/p/3323085.html)
