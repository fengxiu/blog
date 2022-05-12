---
title: spring源码解析之 19 不同Scope实例的创建
tags:
  - spring源码解析
categories:
  - java
  - spring
author: fengxiutianya
abbrlink: 24d11232
date: 2019-01-15 03:33:00
updated: 2019-01-15 03:33:00
---
在Spring中存在着不同的scope，默认是singleton，还有prototype、request等其他的scope，本篇文章将进行不同作用域实例创建的解析。

<!-- more-->

## singleton作用域实例创建

Spring的scope默认为singleton，其初始化的代码如下：

```java
// singleton bean的创建
if (mbd.isSingleton()) {
    sharedInstance = getSingleton(beanName, () -> {
        try {
            return createBean(beanName, mbd, args);
        } catch (BeansException ex) {
            // 如果创建失败，需要移除缓存中的bean，因为在创建过程中，
            /**
             * 如果单例bean创建出现失败，需要移除缓存中缓存的此类型的bean
             * 创建失败还会存在这种类型的bean的原因是：单例bean中会存在循
             * 环依赖为了解决循环依赖，运行提前暴露没有完全创建成功的bean，
             * 所以缓存中会存在这种类型的bean，在创建失败后需要删除，。
             */
            destroySingleton(beanName);
            throw ex;
        }
    });
    bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
} 
```

第一部分分析了从缓存中获取单例模式的bean，但是如果缓存中不存在，则需要创建对应的bean实例，这个过程由`getSingleton()` 实现。

```java
public Object getSingleton(String beanName, ObjectFactory<?> singletonFactory) {
    Assert.notNull(beanName, "Bean name must not be null");
    // 全局变量需要同步
    synchronized (this.singletonObjects) {
        // 首先检查对一个的bean是否已经加载过，因为singleton模式其实就是复用已创建的bean
        // 所以这一步是必须的
        Object singletonObject = this.singletonObjects.get(beanName);
        // 如果为空才可以进行singleton的bean的初始化
        if (singletonObject == null) {
            // 检查bean是否在销毁，如果销毁则抛出异常
            if (this.singletonsCurrentlyInDestruction) {
                // 省略抛出异常代码
            }
            
            // 创建之前的处理工作，将当前正在创建的beanName加入到正在创建的Sdet集合中
            // 用于判断beanMame是否在被创建
            beforeSingletonCreation(beanName);
            boolean newSingleton = false;
            boolean recordSuppressedExceptions = (this.suppressedExceptions == null);
            if (recordSuppressedExceptions) {
                this.suppressedExceptions = new LinkedHashSet<>();
            }
            try {
                // 初始化bean
                singletonObject = singletonFactory.getObject();
                newSingleton = true;
            } catch (IllegalStateException ex) {
                // 判断单例缓存中是否存在对应的Bean
                singletonObject = this.singletonObjects.get(beanName);
                if (singletonObject == null) {
                    throw ex;
                }
            } catch (BeanCreationException ex) {
                // 记录错误
                if (recordSuppressedExceptions) {
                    for (Exception suppressedException : this.suppressedExceptions)
                    {
                        ex.addRelatedCause(suppressedException);
                    }
                }
                throw ex;
            } finally {
                if (recordSuppressedExceptions) {
                    this.suppressedExceptions = null;
                }
                // 创建之后的处理工作：从正在创建set集合中删除当前的beanname，
                afterSingletonCreation(beanName);
            }
            // 创建成功加入缓存
            if (newSingleton) {
                // 将结果记录至缓存并删除加载bean过程中所记录的各种辅助状态
                addSingleton(beanName, singletonObject);
            }
        }
        return singletonObject;
    }
}

```

其实这个过程并没有真正创建bean，仅仅只是做了一部分准备和预处理步骤，真正获取单例bean的方法其实是由 `singletonFactory.getObject()` 这部分实现，而singletonFactory由回调方法产生。那么这个方法做了哪些准备呢？

1. 获取同步锁，再次检查缓存是否存在对应的Bean，如果有则直接返回，没有则开始创建。
2. 调用 `beforeSingletonCreation()` 记录单例bean处于正在创建，即前置处理。
3. 调用参数传递的 ObjectFactory 的 `getObject()` 实例化 bean。
4. 调用 `afterSingletonCreation()` 进行创建成功后的处理，删除bean正在创建的状态。
5. 将结果记录并加入到单例Bean缓存中。

流程中涉及的三个方法 `beforeSingletonCreation()` 与 `afterSingletonCreation()` 在前面博客中分析过了，所以这里不再阐述了，我们看另外一个方法 `addSingleton()`。

```java
protected void addSingleton(String beanName, Object singletonObject) {
    synchronized (this.singletonObjects) {
        this.singletonObjects.put(beanName, singletonObject);
        this.singletonFactories.remove(beanName);
        this.earlySingletonObjects.remove(beanName);
        this.registeredSingletons.add(beanName);
    }
}
```

一个 put、一个 add、两个 remove。singletonObjects单例bean的缓存，singletonFactories存放创建Bean实例的ObjectFactory的缓存，earlySingletonObjects提前暴露的单例bean的缓存，registeredSingletons已经注册的单例缓存。

创建单例bean后，调用`getObjectForBeanInstance()`进一步处理Bean，该方法已经在前面博客详细分析了。

上面就剩一个创建单例bean没有分析，这里先把剩下的流程分析完了，一起分析创建，因为后面的创建Bean是差不多的，只是条件的处理不同。

##  Prototype作用域实例创建

```java
else if (mbd.isPrototype()) {
    Object prototypeInstance = null;
    try {
        beforePrototypeCreation(beanName);
        prototypeInstance = createBean(beanName, mbd, args);
    }
    finally {
        afterPrototypeCreation(beanName);
    }
    bean = getObjectForBeanInstance(prototypeInstance, name,
                                    beanName, mbd);
}
```

原型模式的初始化过程很简单：直接创建一个新的实例就可以了。过程如下：

1. 调用` beforePrototypeCreation()` 记录加载原型模式 bean 之前的加载状态，即前置处理。
2. 调用 `createBean()` 创建一个 bean 实例对象。
3. 调用 `afterPrototypeCreation()` 进行加载原型模式 bean 后的后置处理。
4. 调用 `getObjectForBeanInstance()` 对创建的bean实例进一步的处理。

上面有一个点需要注意的，前面也说过，就是Prototype类型的bean创建的状态是存储到线程的私有变量中，代码如下：

```java
protected void beforePrototypeCreation(String beanName) {
    // 获取当前线程所有正在创建的BeanName
    Object curVal = this.prototypesCurrentlyInCreation.get();
    // 如果为空，则直接将BeanName加入
    if (curVal == null) {
        this.prototypesCurrentlyInCreation.set(beanName);
        // 其他的则创建HashSet并加入。
    } else if (curVal instanceof String) {
        Set<String> beanNameSet = new HashSet<>(2);
        beanNameSet.add((String) curVal);
        beanNameSet.add(beanName);
        this.prototypesCurrentlyInCreation.set(beanNameSet);
    } else {
        Set<String> beanNameSet = (Set<String>) curVal;
        beanNameSet.add(beanName);
    }
}
```

至于删除正在创建的状态，看了上面的代码相信你能够大概猜出来，这里就不具体讲解。

## 其他作用域

```java
// 获取作用域的名称
String scopeName = mbd.getScope();
// 获取作用于对象
final Scope scope = this.scopes.get(scopeName);
if (scope == null) {
	。。。省略异常
 }
try {
    // 创建对象
    Object scopedInstance = scope.get(beanName, () -> {
        beforePrototypeCreation(beanName);
        try {
            return createBean(beanName, mbd, args);
        }
        finally {
            afterPrototypeCreation(beanName);
        }
    });
	bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
}catch (IllegalStateException ex) {
  	//抛出异常代码省略
}
```

核心流程和原型模式一样，只不过获取bean实例是由`scope.get()` 实现，后面会单独讲讲Spring中其他的Scope是如何保存Bean实例，毕竟创建过程是一样的。

对于上面三个模块，其中最重要的有两个方法，一个是 `createBean()`、一个是 `getObjectForBeanInstance()`。这两个方法在上面三个模块都有调用，`createBean()` 后续详细说明，`getObjectForBeanInstance()` 在前面博客中有详细讲解，这里再次阐述下（此段内容来自《Spring源码深度解析》）：这个方法主要是验证我们得到的bean的正确性，其实就是检测当前bean是否是FactoryBean类型的 bean，如果是，那么需要调用该bean对应的FactoryBean实例的 `getObject()` 作为返回值。无论是从缓存中获得到的bean还是通过不同的scope策略加载的bean都只是最原始的bean 状态，并不一定就是我们最终想要的 bean。举个例子，加入我们需要对工厂bean进行处理，那么这里得到的其实是工厂bean的初始状态，但是我们真正需要的是工厂bean中定义factory-method方法中返回的bean，而`getObjectForBeanInstance()`就是完成这个工作的。