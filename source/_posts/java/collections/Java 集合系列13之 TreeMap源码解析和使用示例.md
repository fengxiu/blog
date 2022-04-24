---
title: java集合系列13TreeMap和TreeSet源码解析
tags:
  - 集合
categories:
  - java
  - collections
abbrlink: 7b22f4ce
date: 2019-03-04 22:58:00
updated: 2019-03-04 22:58:00
---

TreeMap底层通过红黑树(Red-Black tree)实现，也就意味着containsKey(), get(), put(), remove()都有着log(n)的时间复杂度。其具体算法实现参照了《算法导论》

出于性能原因，TreeMap是非同步的(not synchronized)，如果需要在多线程环境使用，需要程序员手动同步；或者通过如下方式将TreeMap包装成(wrapped)同步的: `SortedMap m = Collections.synchronizedSortedMap(new TreeMap(...))` 

红黑树是一种近似平衡的二叉查找树，它能够确保任何一个节点的左右子树的高度差不会超过二者中较低那个的一倍。具体来说，红黑树是满足如下条件的二叉查找树(binary search tree):

1. 每个节点要么是红色，要么是黑色。
2. 根节点必须是黑色
3. 红色节点不能连续(也即是，红色节点的孩子和父亲都不能是红色)。
4. 对于每个节点，从该点至null(树尾端)的任何路径，都含有相同个数的黑色节点。

在树的结构发生改变时(插入或者删除操作)，往往会破坏上述条件3或条件4，需要通过调整使得查找树重新满足红黑树的约束条件。

![红黑树](https://cdn.jsdelivr.net/gh/fengxiu/img/20220421191341.png)

TreeMap整体结构如下图所示

![类图结构](https://cdn.jsdelivr.net/gh/fengxiu/img/20220421191456.png)

TreeMap实现了NavigableMap接口，该接口主要是扩展SortedMap接口，用于搜锁离指定接口最近的匹配数据。SortedMap接口主要定义根据key值的排序来定义Map的视图顺序，如果key值实现了Comparable，则会根据返回结果进行排序，如果指定了Comparator，则会根据其进行排序。

因此在创将TreeMap对象的时候，最好指定Comparator，或者插入的key值实现了Comparable接口，否则会抛出异常。

## TreeSet

TreeSet是对TreeMap的简单包装，对TreeSet的函数调用都会转换成合适的TreeMap方法，因此TreeSet的实现非常简单。这里不再赘述。

```java
// TreeSet是对TreeMap的简单包装
public class TreeSet<E> extends AbstractSet<E>
    implements NavigableSet<E>, Cloneable, java.io.Serializable
{
	// ......
    private transient NavigableMap<E,Object> m;
    // Dummy value to associate with an Object in the backing Map
    private static final Object PRESENT = new Object();
    public TreeSet() {
        this.m = new TreeMap<E,Object>();// TreeSet里面有一个TreeMap
    }
    // ......
    public boolean add(E e) {
        return m.put(e, PRESENT)==null;
    }
    // ......
}
```
  
## 参考

1. [TreeSet&TreeMap源码解析](https://pdai.tech/md/java/collection/java-map-TreeMap&TreeSet.html)
