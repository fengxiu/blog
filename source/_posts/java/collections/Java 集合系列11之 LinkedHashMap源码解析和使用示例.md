---
title: java集合系列11之LinkedHashMap和LinkedHashSet源码解析
tags:
  - 集合
categories:
  - java
  - collections
abbrlink: 272a8849
date: 2019-03-04 20:58:00
updated: 2019-03-04 20:58:00
---

本文首先对LinkedHashMap整体进行分析，然后在介绍LinkedHashSet，其实它只是针对LinkedHashMap的简单封装。类图如下
![uml图](https://cdn.jsdelivr.net/gh/fengxiu/img/20220420174910.png)

LinkedHashMap实现了Map接口，即允许放入key为null的元素，也允许插入value为null的元素。从名字上可以看出该容器是linked list和HashMap的混合体，也就是说它同时满足HashMap和linked list的某些特性。可将LinkedHashMap看作采用linked list增强的HashMap。
存储结构如下

![整体结构](https://cdn.jsdelivr.net/gh/fengxiu/img/20220420175640.png)

事实上LinkedHashMap是HashMap的直接子类，二者唯一的区别是LinkedHashMap在HashMap的基础上，采用双向链表(doubly-linked list)的形式将所有entry连接起来，这样是为保证元素的迭代顺序跟插入顺序相同。上图给出了LinkedHashMap的结构图，主体部分跟HashMap完全一样，多了header指向双向链表的头部(是一个哑元)，该双向链表的迭代顺序就是entry的插入顺序。

除了可以保迭代历顺序，这种结构还有一个好处 : 迭代LinkedHashMap时不需要像HashMap那样遍历整个table，而只需要直接遍历header指向的双向链表即可，也就是说LinkedHashMap的迭代时间就只跟entry的个数相关，而跟table的大小无关。

首先看下LinkedHashMap的重要参数和构造函数，源码如下

```java
/**
 * 指向链表的头部
 */
transient LinkedHashMap.Entry<K,V> head;

/**
 * 指向链表的尾部
 */
transient LinkedHashMap.Entry<K,V> tail;

/**
 * 链表的插入顺序，如果是false，则按照插入顺序，如果是true按照访问顺序。
 * 注意这里时final，一旦定义不能修改
 */
final boolean accessOrder;

public LinkedHashMap(int initialCapacity,
                  float loadFactor,
                  boolean accessOrder) {
super(initialCapacity, loadFactor);
this.accessOrder = accessOrder;
}
```

除了加入以上三个属性，还扩展了节点的结构用来支持链表,主要是加入了获取其前节点以及节点的数据，具体代码如下

```java
static class Entry<K,V> extends HashMap.Node<K,V> {
        Entry<K,V> before, after;
        Entry(int hash, K key, V value, Node<K,V> next) {
            super(hash, key, value, next);
        }
    }
```

**插入**

下面来看下创建过程，整体的创建过程和HashMap一直，只是在创建节点时会有增加了链接其它节点的功能，

首选是覆盖HashMap中的创建修改节点的，从而保证每次添加和修改节点时能够加入LinkedHashMap的链表功能。

```java

// 创建新节点
Node<K,V> newNode(int hash, K key, V value, Node<K,V> e) {
    LinkedHashMap.Entry<K,V> p =
        new LinkedHashMap.Entry<K,V>(hash, key, value, e);
    linkNodeLast(p);
    return p;
}

// 取代新节点
Node<K,V> replacementNode(Node<K,V> p, Node<K,V> next) {
    LinkedHashMap.Entry<K,V> q = (LinkedHashMap.Entry<K,V>)p;
    LinkedHashMap.Entry<K,V> t =
        new LinkedHashMap.Entry<K,V>(q.hash, q.key, q.value, next);
    transferLinks(q, t);
    return t;
}

TreeNode<K,V> newTreeNode(int hash, K key, V value, Node<K,V> next) {
    TreeNode<K,V> p = new TreeNode<K,V>(hash, key, value, next);
    linkNodeLast(p);
    return p;
}

TreeNode<K,V> replacementTreeNode(Node<K,V> p, Node<K,V> next) {
    LinkedHashMap.Entry<K,V> q = (LinkedHashMap.Entry<K,V>)p;
    TreeNode<K,V> t = new TreeNode<K,V>(q.hash, q.key, q.value, next);
    transferLinks(q, t);
    return t;
}
private void transferLinks(LinkedHashMap.Entry<K,V> src,
                            LinkedHashMap.Entry<K,V> dst) {
    LinkedHashMap.Entry<K,V> b = dst.before = src.before;
    LinkedHashMap.Entry<K,V> a = dst.after = src.after;
    if (b == null)
        head = dst;
    else
        b.after = dst;
    if (a == null)
        tail = dst;
    else
        a.before = dst;
}

 private void linkNodeLast(LinkedHashMap.Entry<K,V> p) {
        LinkedHashMap.Entry<K,V> last = tail;
        tail = p;
        if (last == null)
            head = p;
        else {
            p.before = last;
            last.after = p;
        }
    }
```

接下来的插入操作和HashMap是一致的，有区别的点是在插入的过程中，会根据前面设置的accessOrder来调整LinkedHashMap链表的顺序，原理是扩展了HashMap的俩个函数

```java
// 在插入完成后，判断是否需要移除某些节点，
// 根据源码可以得出，是不会执行到if中
void afterNodeInsertion(boolean evict) { // possibly remove eldest
  LinkedHashMap.Entry<K,V> first;
  if (evict && (first = head) != null && removeEldestEntry(first)) {
      K key = first.key;
      removeNode(hash(key), key, null, false, true);
  }
}

// 主要用于扩展，什么时机删除
protected boolean removeEldestEntry(Map.Entry<K,V> eldest) {
    return false;
}

// 根据是否按照访问顺序进行排序
void afterNodeAccess(Node<K,V> e) { // move node to last
  LinkedHashMap.Entry<K,V> last;
  if (accessOrder && (last = tail) != e) {
      LinkedHashMap.Entry<K,V> p =
          (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
      p.after = null;
      if (b == null)
          head = a;
      else
          b.after = a;
      if (a != null)
          a.before = b;
      else
          last = b;
      if (last == null)
          head = p;
      else {
          p.before = last;
          last.after = p;
      }
      tail = p;
      ++modCount;
  }
}
```

从上面可以看出，LinkedHashMap和HashMap的插入基本一致，只是会在插入的每个节点中保持一条链表，链表的顺序可以根据插入或者访问顺序，在创建对象的时候就定义下来。

**访问**
访问源码如下，主要还是使用了HashMap中定义的函数，在访问完成后，会根据accessOrder来调整链表的顺序

```java
public V get(Object key) {
    Node<K,V> e;
    if ((e = getNode(hash(key), key)) == null)
        return null;
    if (accessOrder)
        afterNodeAccess(e);
    return e.value;
}
```

**移除**
在LinkedHashMap中没有定义remove方法，直接使用的是HashMap中的方法，区别是移除后，LinkeHashMap又多了一步，afterNodeRemoval，具体定义如下，其实就是删除节点之间的连接

```java
void afterNodeRemoval(Node<K,V> e) { // unlink
    LinkedHashMap.Entry<K,V> p =
        (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
    p.before = p.after = null;
    if (b == null)
        head = a;
    else
        b.after = a;
    if (a == null)
        tail = b;
    else
        a.before = b;
}
```

## LinkedHashSet

LinkedHashSet是对LinkedHashMap的简单包装，对LinkedHashSet的函数调用都会转换成合适的LinkedHashMap方法，因此LinkedHashSet的实现非常简单，这里不再赘述。

```java
public class LinkedHashSet<E>
    extends HashSet<E>
    implements Set<E>, Cloneable, java.io.Serializable {
    // ......
    // LinkedHashSet里面有一个LinkedHashMap
    public LinkedHashSet(int initialCapacity, float loadFactor) {
        map = new LinkedHashMap<>(initialCapacity, loadFactor);
    }
	// ......
    public boolean add(E e) {//简单的方法转换
        return map.put(e, PRESENT)==null;
    }
    // ......
}
```

## LinkedHashMap经典用法

LinkedHashMap除了可以保证迭代顺序外，还有一个非常有用的用法: 可以轻松实现一个采用了FIFO替换策略的缓存。具体说来，LinkedHashMap有一个子类方法`protected boolean removeEldestEntry(Map.Entry<K,V> eldest)`，该方法的作用是告诉Map是否要删除最老的Entry，所谓最老就是当前Map中最早插入的Entry，如果该方法返回true，最老的那个元素就会被删除。在每次插入新元素的之后LinkedHashMap会自动询问removeEldestEntry()是否要删除最老的元素。这样只需要在子类中重载该方法，当元素个数超过一定数量时让removeEldestEntry()返回true，就能够实现一个固定大小的FIFO策略的缓存。示例代码如下: 

```java
/** 一个固定大小的FIFO替换策略的缓存 */
class FIFOCache<K, V> extends LinkedHashMap<K, V>{
    private final int cacheSize;
    public FIFOCache(int cacheSize){
        this.cacheSize = cacheSize;
    }

    // 当Entry个数超过cacheSize时，删除最老的Entry
    @Override
    protected boolean removeEldestEntry(Map.Entry<K,V> eldest) {
       return size() > cacheSize;
    }
}
```