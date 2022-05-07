---
title: Spring源码解析之 08bean标签：BeanDefinition简单介绍与bean节点解析
tags:
  - spring源码解析
categories:
  - java
  - spring
author: fengxiutianya
abbrlink: 48fb5eaf
date: 2019-01-14 05:12:00
updated: 2019-01-14 05:12:00
---

### 概述

1. BeanDefinition 简介
2. 解析Bean标签

### BeanDefinition简介

BeanDefinition 是一个接口，它描述了一个 Bean 实例，包括属性值、构造方法值和继承自其它的类的更多信息。Spring通过BeanDefinition将配置文件中的`< bean >`配置文件转换为容器的内部表示，并将这些BeanDefinition注册到BeanDefinitionRegistry中。Spring容器的BeanDefinitionRegistry就像是spring配置信息的内存数据库，主要以map的形式保存，后续操作直接从BeanDefinitionRegistry中直接获取配置信息。
<!-- more-->

它继承 AttributeAccessor 和 BeanMetadataElement 接口。两个接口定义如下：

* AttributeAccessor ：定义了与其它对象的（元数据）进行连接和访问的约定，即对属性的修改，包括获取、设置、删除。
* BeanMetadataElement：Bean元对象持有的配置元素可以通过getSource() 方法来获取。

BeanDefinition继承关系图

![BeanDefinition继承关系图](https://cdn.jsdelivr.net/gh/fengxiu/img/pasted-10.png)

我们常用的三个实现类有：ChildBeanDefinition、GenericBeanDefinition、RootBeanDefinition，三者都继承 AbstractBeanDefinition。如果配置文件中定义了父 `<bean>` 和 子 `<bean>` ，则父 `<bean>` 用 RootBeanDefinition表示，子 `<bean>` 用 ChildBeanDefinition 表示，而没有父 `<bean>` 的就使用RootBeanDefinition 表示。GenericBeanDefinition是提供的一站式服务类,通常在解析xml配置文件时，先将BeanDefinition解析为此类型。AbstractBeanDefinition对三个子类共同的类信息进行抽象。

### 解析Bean标签

在 `BeanDefinitionParserDelegate.parseBeanDefinitionElement()` 中完成Bean标签的解析，返回的是一个已经完成对 `<bean>` 标签解析的 BeanDefinition 实例。在该方法内部，首先调用 `createBeanDefinition()` 方法创建一个用于承载属性的 GenericBeanDefinition 实例，如下：

```java
protected AbstractBeanDefinition createBeanDefinition(@Nullable 
    String className, @Nullable String parentName)
    throws ClassNotFoundException {

    return BeanDefinitionReaderUtils.createBeanDefinition(
        parentName, className, this.readerContext.getBeanClassLoader());
}
```

委托 BeanDefinitionReaderUtils 创建，如下：

```java
public static AbstractBeanDefinition createBeanDefinition(
    @Nullable String parentName, @Nullable String className, 
    @Nullable ClassLoader classLoader) throws ClassNotFoundException {

    GenericBeanDefinition bd = new GenericBeanDefinition();
    bd.setParentName(parentName);
    if (className != null) {
        if (classLoader != null) {
            bd.setBeanClass(ClassUtils.forName(className, classLoader));
        }
        else {
            bd.setBeanClassName(className);
        }
    }
    return bd;
}
```

该方法主要是设置 parentName 、className、classLoader。

创建完 GenericBeanDefinition 实例后，再调用 `parseBeanDefinitionAttributes()` ，该方法将创建好的 GenericBeanDefinition实例当做参数，对Bean标签的所有属性进行解析，如下：

```java
public AbstractBeanDefinition parseBeanDefinitionAttributes(Element ele,
                      String beanName, @Nullable BeanDefinition containingBean, 
                                  AbstractBeanDefinition bd) {
        // 解析 scope 标签，下面这个首先判断是否使用了老版本的spring配置
        if (ele.hasAttribute(SINGLETON_ATTRIBUTE)) {
            error("Old 1.x 'singleton' attribute in use 
                  		- upgrade to 'scope' declaration", ele);
        }
        else if (ele.hasAttribute(SCOPE_ATTRIBUTE)) {
            bd.setScope(ele.getAttribute(SCOPE_ATTRIBUTE));
        }
        else if (containingBean != null) {
            bd.setScope(containingBean.getScope());
        }

        // 解析 abstract 属性
        if (ele.hasAttribute(ABSTRACT_ATTRIBUTE)) {
            bd.setAbstract(TRUE_VALUE.equals(ele.getAttribute(ABSTRACT_ATTRIBUTE)));
        }

        // 解析 lazy-init 属性
        String lazyInit = ele.getAttribute(LAZY_INIT_ATTRIBUTE);
        if (DEFAULT_VALUE.equals(lazyInit)) {
            lazyInit = this.defaults.getLazyInit();
        }
        bd.setLazyInit(TRUE_VALUE.equals(lazyInit));

        // 解析 autowire 属性
        String autowire = ele.getAttribute(AUTOWIRE_ATTRIBUTE);
        bd.setAutowireMode(getAutowireMode(autowire));

        // 解析 depends-on 属性
        if (ele.hasAttribute(DEPENDS_ON_ATTRIBUTE)) {
            String dependsOn = ele.getAttribute(DEPENDS_ON_ATTRIBUTE);
            bd.setDependsOn(StringUtils.tokenizeToStringArray(dependsOn, 
                                MULTI_VALUE_ATTRIBUTE_DELIMITERS));
        }

        // 解析 autowire-candidate 属性
        String autowireCandidate = ele.getAttribute(AUTOWIRE_CANDIDATE_ATTRIBUTE);
        if ("".equals(autowireCandidate) || DEFAULT_VALUE.equals(autowireCandidate)) {
            String candidatePattern = this.defaults.getAutowireCandidates();
            if (candidatePattern != null) {
                String[] patterns = 
                    StringUtils.commaDelimitedListToStringArray(candidatePattern);
                bd.setAutowireCandidate(PatternMatchUtils.simpleMatch(patterns, 
                                                                      beanName));
            }
        }
        else {
            bd.setAutowireCandidate(TRUE_VALUE.equals(autowireCandidate));
        }

        // 解析 primay 属性
        if (ele.hasAttribute(PRIMARY_ATTRIBUTE)) {
            bd.setPrimary(TRUE_VALUE.equals(ele.getAttribute(PRIMARY_ATTRIBUTE)));
        }

        // 解析 init-method 属性
        if (ele.hasAttribute(INIT_METHOD_ATTRIBUTE)) {
            String initMethodName = ele.getAttribute(INIT_METHOD_ATTRIBUTE);
            bd.setInitMethodName(initMethodName);
        }
        else if (this.defaults.getInitMethod() != null) {
            bd.setInitMethodName(this.defaults.getInitMethod());
            bd.setEnforceInitMethod(false);
        }

        // 解析 destroy-mothod 属性
        if (ele.hasAttribute(DESTROY_METHOD_ATTRIBUTE)) {
            String destroyMethodName = ele.getAttribute(DESTROY_METHOD_ATTRIBUTE);
            bd.setDestroyMethodName(destroyMethodName);
        }
        else if (this.defaults.getDestroyMethod() != null) {
            bd.setDestroyMethodName(this.defaults.getDestroyMethod());
            bd.setEnforceDestroyMethod(false);
        }

        // 解析 factory-method 属性
        if (ele.hasAttribute(FACTORY_METHOD_ATTRIBUTE)) {
            bd.setFactoryMethodName(ele.getAttribute(FACTORY_METHOD_ATTRIBUTE));
        }
        if (ele.hasAttribute(FACTORY_BEAN_ATTRIBUTE)) {
            bd.setFactoryBeanName(ele.getAttribute(FACTORY_BEAN_ATTRIBUTE));
        }
        return bd;
    }

```

从上面代码我们可以清晰地看到对Bean标签属性的解析，这些属性我们在工作中都或多或少用到过。完成 Bean 标签基本属性解析后，会依次调用`parseMetaElements()` 、`parseLookupOverrideSubElements()` 、 

`parseReplacedMethodSubElements()` 对子元素 meta、lookup-method、replace-method 完成解析。下篇博文将会对这三个子元素进行详细说明。