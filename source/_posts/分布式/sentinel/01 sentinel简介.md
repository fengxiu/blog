---
title: 01 sentinel简介
tags:
  - sentinel
categories:
  - 限流
abbrlink: 44592
date: 2023-03-06 21:36:25
updated: 2023-03-06 21:36:30
---


[Sentinel](https://sentinelguard.io/zh-cn/index.html)是阿里中间件团队开源的，面向分布式服务架构的轻量级高可用流量控制组件，主要以流量为切入点，从流量控制、熔断降级、系统负载保护等多个维度来帮助用户保护服务的稳定性。

本文从一个简单的例子介绍如何使用sentinel，然后对链路进行简单的介绍，为后面的原理分析做个铺垫。

```java
Entry entry = null;
try {
    entry = SphU.entry("demo1");//（1）
    // 被保护的业务逻辑
    // do something...
} catch (BlockException ex) {
    // 资源访问阻止后的处理
}  finally {
    if (entry != null) {
        entry.exit();//（3）
    }
}
```

这是一个很普通的例子，不过已经足以说明sentinel的流程，主要做了以下三件事

1. 定义资源：资源是Sentinel的关键概念。它可以是Java应用程序中的任何内容，例如，由应用程序提供的服务，或由应用程序调用的其它应用提供的服务，甚至可以是一段代码。只要通过 Sentinel API 定义的代码，就是资源，能够被 Sentinel 保护起来。大部分情况下，可以使用方法签名，URL，甚至服务名称作为资源名来标示资源。
2. 当资源访问被阻止后，进行处理
3. 退出限流 `entry.exit()`

<!-- more -->
## 源码解读

### SphU.entry()

首先从入口开始：SphU.entry() 。这个方法会去申请一个entry，如果能够申请成功，则说明没有被限流，否则会抛出BlockException，表面已经被限流了。

从`SphU.entry()`方法往下执行会进入到 Sph.entry() ，Sph的默认实现类是 CtSph ，在CtSph中最终会执行到 entry(ResourceWrapper resourceWrapper, int count, Object... args) throws BlockException 这个方法。

我们来看一下这个方法的具体实现：

```java

public Entry entry(ResourceWrapper resourceWrapper, int count, Object... args) throws BlockException {
    Context context = ContextUtil.getContext();
    if (context instanceof NullContext) {
        // Init the entry only. No rule checking will occur.
        return new CtEntry(resourceWrapper, null, context);
    }

    if (context == null) {
        context = MyContextUtil.myEnter(Constants.CONTEXT_DEFAULT_NAME, "", resourceWrapper.getType());
    }

    // Global switch is close, no rule checking will do.
    if (!Constants.ON) {
        return new CtEntry(resourceWrapper, null, context);
    }

    // 获取该资源对应的SlotChain
    ProcessorSlot<Object> chain = lookProcessChain(resourceWrapper);

    /*
     * Means processor cache size exceeds {@link Constants.MAX_SLOT_CHAIN_SIZE}, so no
     * rule checking will be done.
     */
    if (chain == null) {
        return new CtEntry(resourceWrapper, null, context);
    }

    Entry e = new CtEntry(resourceWrapper, chain, context);
    try {
        // 执行Slot的entry方法
        chain.entry(context, resourceWrapper, null, count, args);
    } catch (BlockException e1) {
        e.exit(count, args);
        // 抛出BlockExecption
        throw e1;
    } catch (Throwable e1) {
        RecordLog.info("Sentinel unexpected exception", e1);
    }
    return e;
}
```

这个方法可以分为以下几个部分：

1. 对参数和全局配置项做检测，如果不符合要求就直接返回了一个CtEntry对象，不会再进行后面的限流检测，否则进入下面的检测流程。
2. 根据包装过的资源对象获取对应的SlotChain
3. 执行SlotChain的entry方法
    3.1. 如果SlotChain的entry方法抛出了BlockException，则将该异常继续向上抛出
    3.2. 如果SlotChain的entry方法正常执行了，则最后会将该entry对象返回
4. 如果上层方法捕获了BlockException，则说明请求被限流了，否则请求能正常执行
其中比较重要的是第2、3两个步骤，我们来分解一下这两个步骤。

### 创建SlotChain

首先看一下lookProcessChain的方法实现：

```java
ProcessorSlot<Object> lookProcessChain(ResourceWrapper resourceWrapper) {
    ProcessorSlotChain chain = chainMap.get(resourceWrapper);
    if (chain == null) {
        synchronized (LOCK) {
            chain = chainMap.get(resourceWrapper);
            if (chain == null) {
                // Entry size limit.
                if (chainMap.size() >= Constants.MAX_SLOT_CHAIN_SIZE) {
                    return null;
                }

                chain = SlotChainProvider.newSlotChain();
                Map<ResourceWrapper, ProcessorSlotChain> newMap = new HashMap<ResourceWrapper, ProcessorSlotChain>(
                    chainMap.size() + 1);
                newMap.putAll(chainMap);
                newMap.put(resourceWrapper, chain);
                chainMap = newMap;
            }
        }
    }
    return chain;
}
```

该方法使用了一个HashMap做了缓存，key是资源对象。这里加了锁，并且做了 double check 。具体构造chain的方法是通过： SlotChainProvider.newSlotChain()这句代码创建的。源码如下

```java
public static ProcessorSlotChain newSlotChain() {
    if (slotChainBuilder != null) {
        return slotChainBuilder.build();
    }

    // Resolve the slot chain builder SPI.
    slotChainBuilder = SpiLoader.of(SlotChainBuilder.class).loadFirstInstanceOrDefault();

    if (slotChainBuilder == null) {
        // Should not go through here.
        RecordLog.warn("[SlotChainProvider] Wrong state when resolving slot chain builder, using default");
        slotChainBuilder = new DefaultSlotChainBuilder();
    } else {
        RecordLog.info("[SlotChainProvider] Global slot chain builder resolved: {}",
            slotChainBuilder.getClass().getCanonicalName());
    }
    return slotChainBuilder.build();
}
```

上面主要做了两件事

1. 通过SPI加载SlotChainBuilder，默认是DefaultSlotChainBuilder
2. 调用DefaultSlotChainBuilder.build()方法创建ProcessorSlotChain

看下DefaultSlotChainBuilder.build()

```java
public ProcessorSlotChain build() {
    ProcessorSlotChain chain = new DefaultProcessorSlotChain();

    List<ProcessorSlot> sortedSlotList = SpiLoader.of(ProcessorSlot.class).loadInstanceListSorted();
    for (ProcessorSlot slot : sortedSlotList) {
        if (!(slot instanceof AbstractLinkedProcessorSlot)) {
            RecordLog.warn("The ProcessorSlot(" + slot.getClass().getCanonicalName() + ") is not an instance of AbstractLinkedProcessorSlot, can't be added into ProcessorSlotChain");
            continue;
        }

        chain.addLast((AbstractLinkedProcessorSlot<?>) slot);
    }

    return chain;
}
```

上面代码也是通过SPI加载ProcessorSlot，然后分别进行实例化，具体的SPI加载机制会在后面介绍。上面的代码，其实功能如下，只是这种写法更容易扩展

```java
public ProcessorSlotChain build() {
    ProcessorSlotChain chain = new DefaultProcessorSlotChain();
    chain.addLast(new NodeSelectorSlot());
    chain.addLast(new ClusterBuilderSlot());
    chain.addLast(new LogSlot());
    chain.addLast(new StatisticSlot());
    chain.addLast(new SystemSlot());
    chain.addLast(new AuthoritySlot());
    chain.addLast(new FlowSlot());
    chain.addLast(new DegradeSlot());
    return chain;
}
```

### ProcessorSlotChain

ProcessorSlotChain结构如下

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20230306222626.png)

ProcessorSlotChain 之所以能够形成链表，是因为它继承了 AbstractLinkedProcessorSlot

```java
public abstract class AbstractLinkedProcessorSlot<T> implements ProcessorSlot<T> {
    //指向下一个节点，形成链表
    private AbstractLinkedProcessorSlot<?> next = null;

}
```

而继承自 ProcessorSlotChain 的 DefaultProcessorSlotChain 又增加了一个首节点

```java
public class DefaultProcessorSlotChain extends ProcessorSlotChain {
    //首节点
    AbstractLinkedProcessorSlot<?> first = new AbstractLinkedProcessorSlot<Object>() {
        @Override
        public void entry(Context context, ResourceWrapper resourceWrapper, Object t, int count, boolean prioritized, Object... args)
            throws Throwable {
            super.fireEntry(context, resourceWrapper, t, count, prioritized, args);
        }
        @Override
        public void exit(Context context, ResourceWrapper resourceWrapper, int count, Object... args) {
            super.fireExit(context, resourceWrapper, count, args);
        }
    };
    //将end指向first
    AbstractLinkedProcessorSlot<?> end = first;
}
```

并在初始化时将 end 指向 first

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20230306222714.png)

当调用 addLast 创建新节点时，会将 first 的 next 指向新节点，再将 end 指向新节点，变成

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20230306222758.png)

最后所有 Slot 都添加完之后就形成了一条调用链，每一个 Slot 都是继承自 AbstractLinkedProcessorSlot。而 AbstractLinkedProcessorSlot 是一种责任链的设计，每个对象中都有一个 next 属性，指向的是另一个 AbstractLinkedProcessorSlot 对象。

将所有的节点都加入到链表中后，整个链表的结构变成了如下图所示：

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20230306222937.png)

### chain.entry()

lookProcessChain方法获得的ProcessorSlotChain的实例是DefaultProcessorSlotChain，那么执行chain.entry方法，就会执行DefaultProcessorSlotChain的entry方法，而DefaultProcessorSlotChain的entry方法是这样的：

```java
@Override
public void entry(Context context, ResourceWrapper resourceWrapper, Object t, int count, Object... args)
    throws Throwable {
    first.transformEntry(context, resourceWrapper, t, count, args);
}
```

也就是说，DefaultProcessorSlotChain的entry实际是执行的first属性的transformEntry方法。

而transformEntry方法会执行当前节点的entry方法，在DefaultProcessorSlotChain中first节点重写了entry方法，具体如下：

```java
@Override
public void entry(Context context, ResourceWrapper resourceWrapper, Object t, int count, Object... args)
    throws Throwable {
    super.fireEntry(context, resourceWrapper, t, count, args);
}
```

first节点的entry方法，实际又是执行的super的fireEntry方法，那继续把目光转移到fireEntry方法，具体如下：

```java
@Override
public void fireEntry(Context context, ResourceWrapper resourceWrapper, Object obj, int count, Object... args)
    throws Throwable {
    if (next != null) {
        next.transformEntry(context, resourceWrapper, obj, count, args);
    }
}
```

从这里可以看到，从fireEntry方法中就开始传递执行entry了，这里会执行当前节点的下一个节点transformEntry方法，上面已经分析过了，transformEntry方法会触发当前节点的entry，也就是说fireEntry方法实际是触发了下一个节点的entry方法。具体的流程如下图所示：

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20230306224214.png)

从图中可以看出，从最初的调用Chain的entry()方法，转变成了调用SlotChain中Slot的entry()方法。从上面的分析可以知道，SlotChain中的第一个Slot节点是NodeSelectorSlot。

执行Slot的entry方法
现在可以把目光转移到SlotChain中的第一个节点NodeSelectorSlot的entry方法中去了，具体的代码如下：

```java

@Override
public void entry(Context context, ResourceWrapper resourceWrapper, Object obj, int count, Object... args)
    throws Throwable {

    DefaultNode node = map.get(context.getName());
    if (node == null) {
        synchronized (this) {
            node = map.get(context.getName());
            if (node == null) {
                node = Env.nodeBuilder.buildTreeNode(resourceWrapper, null);
                HashMap<String, DefaultNode> cacheMap = new HashMap<String, DefaultNode>(map.size());
                cacheMap.putAll(map);
                cacheMap.put(context.getName(), node);
                map = cacheMap;
            }
            // Build invocation tree
            ((DefaultNode)context.getLastNode()).addChild(node);
        }
    }

    context.setCurNode(node);
    // 由此触发下一个节点的entry方法
    fireEntry(context, resourceWrapper, node, count, args);
}
```

从代码中可以看到，NodeSelectorSlot节点做了一些自己的业务逻辑处理，具体的大家可以深入源码继续追踪，这里大概的介绍下每种Slot的功能职责：

* NodeSelectorSlot 负责收集资源的路径，并将这些资源的调用路径，以树状结构存储起来，用于根据调用路径来限流降级；
* ClusterBuilderSlot 则用于存储资源的统计信息以及调用者信息，例如该资源的 RT, QPS, thread count 等等，这些信息将用作为多维度限流，降级的依据；
* StatistcSlot 则用于记录，统计不同纬度的 runtime 信息；
* FlowSlot 则用于根据预设的限流规则，以及前面 slot 统计的状态，来进行限流；
* AuthorizationSlot 则根据黑白名单，来做黑白名单控制；
* DegradeSlot 则通过统计信息，以及预设的规则，来做熔断降级；
* SystemSlot 则通过系统的状态，例如 load1 等，来控制总的入口流量；

执行完业务逻辑处理后，调用了fireEntry()方法，由此触发了下一个节点的entry方法。此时我们就知道了sentinel的责任链就是这样传递的：每个Slot节点执行完自己的业务后，会调用fireEntry来触发下一个节点的entry方法。

所以可以将上面的图完整了，具体如下：

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20230306224318.png)

至此就通过SlotChain完成了对每个节点的entry()方法的调用，每个节点会根据创建的规则，进行自己的逻辑处理，当统计的结果达到设置的阈值时，就会触发限流、降级等事件，具体是抛出BlockException异常。

### entry.exit()

退出时最终会调用到 exitForContext() 方法

```java
protected void exitForContext(Context context, int count, Object... args) throws ErrorEntryFreeException {
    if (context != null) {
        // Null context should exit without clean-up.
        if (context instanceof NullContext) {
            return;
        }
        if (context.getCurEntry() != this) {
            String curEntryNameInContext = context.getCurEntry() == null ? null
                : context.getCurEntry().getResourceWrapper().getName();
            // Clean previous call stack.
            CtEntry e = (CtEntry) context.getCurEntry();
            while (e != null) {
                e.exit(count, args);
                e = (CtEntry) e.parent;
            }
            String errorMessage = String.format("The order of entry exit can't be paired with the order of entry"
                    + ", current entry in context: <%s>, but expected: <%s>", curEntryNameInContext,
                resourceWrapper.getName());
            throw new ErrorEntryFreeException(errorMessage);
        } else {
            // Go through the onExit hook of all slots.
            if (chain != null) {
                chain.exit(context, resourceWrapper, count, args);（1）
            }
            // Go through the existing terminate handlers (associated to this invocation).
            callExitHandlersAndCleanUp(context);
            // Restore the call stack.
            context.setCurEntry(parent);
            if (parent != null) {
                ((CtEntry) parent).child = null;
            }
            if (parent == null) {
                // Default context (auto entered) will be exited automatically.
                if (ContextUtil.isDefaultContext(context)) {
                    ContextUtil.exit();
                }
            }
            // Clean the reference of context in current entry to avoid duplicate exit.
            clearEntryContext();
        }
    }
}
```

1. 第一步为判断要退出的 entry 是否为当前的 entry，不是的话抛出异常
2. 接下来看到 chain.exit() 时想必你已经发现了，这和上面我们刚分析完的chain.entry()如出一辙，只是调用方法从 entry() 换成了 exit()
3. 清理上下文信息，将 curEntry 变成 parent，这部分有点像 jvm 的函数调用栈，在函数结束后出栈

