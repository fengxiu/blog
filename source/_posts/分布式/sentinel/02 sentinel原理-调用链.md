---
title: 02 sentinel原理-SPI扩展点
tags:
  - sentinel
categories:
  - 限流
abbrlink: 17382
date: 2023-03-06 21:36:35
updated: 2023-03-06 21:36:39
---

前面一篇文章多次讲到SPI机制，本篇文章主要介绍下sentinel中使用到的SPI。如果对SPI不太懂，可以参考这篇文章[SPI](/archives/22420980.html)

在sentinel-core模块的resources资源目录下，有一个 META-INF/services 目录，该目录下定义了sentinel的SPI扩展点，目前有以下三个，同时实现了自定义的SPI加载器SpiLoader，下面的扩展点都是使用这个加载器进行加载。

1. com.alibaba.csp.sentinel.init.InitFunc：用于配置InitFunc接口的实现类
2. com.alibaba.csp.sentinel.slotchain.SlotChainBuilder文件用于配置 SlotChainBuilder 接口的实现类
3. com.alibaba.csp.sentinel.slotchain.ProcessorSlot：用于配置使用到的ProcessorSlot

<!-- more -->
下面分别介绍每一种扩展点

### com.alibaba.csp.sentinel.init.InitFunc

文件的默认配置如下：

```java
  com.alibaba.csp.sentinel.metric.extension.MetricCallbackInit
```

Sentinel自定义了SPI加载机制，所以会有一些与java提供的SPI加载机制不同。对于InitFunc接口，如果配置文件注册了多个实现类，那么这些注册的InitFunc实现类都会被Sentinel加载、实例化，具体是通过SpiLoader.loadInstanceListSorted方法加载注册，源码如下

```java
public final class InitExecutor {

     public static void doInit() {
        if (!initialized.compareAndSet(false, true)) {
            return;
        }
        try {
            List<InitFunc> initFuncs = SpiLoader.of(InitFunc.class).loadInstanceListSorted();
            List<OrderWrapper> initList = new ArrayList<OrderWrapper>();
            for (InitFunc initFunc : initFuncs) {
                RecordLog.info("[InitExecutor] Found init func: {}", initFunc.getClass().getCanonicalName());
                insertSorted(initList, initFunc);
            }
            for (OrderWrapper w : initList) {
                w.func.init();
                。。。
            }
        } catch (Exception ex) {
            。。。
        } catch (Error error) {
            。。。
        }
    }
}

```

### com.alibaba.csp.sentinel.slotchain.SlotChainBuilder

文件的默认配置如下：

```java
# Default slot chain builder
  com.alibaba.csp.sentinel.slots.DefaultSlotChainBuilder
```

SlotChainBuilder如果注册多个实现类，Sentinel 只会加载和使用第一个。Sentinel 在加载 SlotChainBuilder 时，只会获取第一个非默认（非 DefaultSlotChainBuilder）实现类的实例，如果接口配置文件中除了默认实现类没有注册别的实现类，则 Sentinel 会使用这个默认的 SlotChainBuilder。其实现源码在 SpiLoader.loadFirstInstanceOrDefault 方法中，代码如下。

```java
public final class SpiLoader {
   public S loadFirstInstanceOrDefault() {
        // 加载所有的SlotChainBuilder
        load();

        for (Class<? extends S> clazz : classList) {
            if (defaultClass == null || clazz != defaultClass) {
                return createInstance(clazz);
            }
        }

        return loadDefaultInstance();
    }
}
```

Sentinel 使用 SlotChainBuilder 将多个 ProcessorSlot 构造成一个 ProcessorSlotChain，由 ProcessorSlotChain 按照 ProcessorSlot 的注册顺序去调用这些 ProcessorSlot。Sentinel 使用 Java SPI 加载 SlotChainBuilder 支持使用者自定义 SlotChainBuilder，相当于是提供了插件的功能。

Sentinel 默认使用的 SlotChainBuilder 是 DefaultSlotChainBuilder，其源码如下：

```java
@Spi(isDefault = true)
public class DefaultSlotChainBuilder implements SlotChainBuilder {

    @Override
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
}

```

DefaultSlotChainBuilder在新的版本中通过使用SpiLoader加载所有的ProcessorSlot，这样便于对ProcessorSlot进行增减

### com.alibaba.csp.sentinel.slotchain.ProcessorSlot

文件的默认配置如下

```java
# Sentinel default ProcessorSlots
com.alibaba.csp.sentinel.slots.nodeselector.NodeSelectorSlot
com.alibaba.csp.sentinel.slots.clusterbuilder.ClusterBuilderSlot
com.alibaba.csp.sentinel.slots.logger.LogSlot
com.alibaba.csp.sentinel.slots.statistic.StatisticSlot
com.alibaba.csp.sentinel.slots.block.authority.AuthoritySlot
com.alibaba.csp.sentinel.slots.system.SystemSlot
com.alibaba.csp.sentinel.slots.block.flow.FlowSlot
com.alibaba.csp.sentinel.slots.block.degrade.DegradeSlot
```

ProcessorSlot文件是在DefaultSlotChainBuilder中通过SpiLoader.loadInstanceListSorted方法进行加载，用于初始化处理链，具体的加载代码如下

```java
public List<S> loadInstanceListSorted() {
    // 加载所有的ProcessorSlot，并根据SPI注解中的order进行排序，
    // 存储在sortedClassList列表，进行初始化
    load();

    return createInstanceList(sortedClassList);
}
private List<S> createInstanceList(List<Class<? extends S>> clazzList) {
    if (clazzList == null || clazzList.size() == 0) {
        return Collections.emptyList();
    }

    List<S> instances = new ArrayList<>(clazzList.size());
    for (Class<? extends S> clazz : clazzList) {
        S instance = createInstance(clazz);
        instances.add(instance);
    }
    return instances;
}
private S createInstance(Class<? extends S> clazz) {
    Spi spi = clazz.getAnnotation(Spi.class);
    boolean singleton = true;
    if (spi != null) {
        singleton = spi.isSingleton();
    }
    return createInstance(clazz, singleton);
}
private S createInstance(Class<? extends S> clazz, boolean singleton) {
    S instance = null;
    try {
        if (singleton) {
            instance = singletonMap.get(clazz.getName());
            if (instance == null) {
                synchronized (this) {
                    instance = singletonMap.get(clazz.getName());
                    if (instance == null) {
                        instance = service.cast(clazz.newInstance());
                        singletonMap.put(clazz.getName(), instance);
                    }
                }
            }
        } else {
            instance = service.cast(clazz.newInstance());
        }
    } catch (Throwable e) {
        fail(clazz.getName() + " could not be instantiated");
    }
    return instance;
}

```

加载逻辑还是比较清晰的，这里需要注意的一点是，如果ProcessorSlot实现类上的SPI注解表示这个类是单例，则在加载的时候就会创建，并且全局都是用这个实例。其中NodeSelectorSlot和ClusterBuilderSlot不是单例，其它几个都是单例
