---
title: spring AOP一世
categories:
  - java
  - spring
  - spring 源码分析
  - Aop
abbrlink: a8dee644
date: 2019-07-14 18:04:15
tags:
---
在动态代理和CGLIB的支持下，Spring AOP框架的实现经过了两代。虽然划分成了两代，但是底层实现机制确一直没变。唯一改变的，是各种AOP概念实体的表现形式以及Spring AOP的使用方式。
下面，我们先从第一代的Spring AOP相关的概念实体说起。

## Spring AOP中的Joinpoint

之前我们已经提到，AOP的JoinPoint可以有许多种类型，如构造方法调用、字段的设置及获取、方法调用、方法执行等。但是，在Spring AOP中，仅支持方法级别的Joinpoint。更确切的说，只支持方法执行类型的Joinpoint。

虽然Spring AOP仅提供方法拦截，但是在实际的开发过程中，这已经可以满足80%的开发需求了。Spring AOP之所以如此，主要由以下几个原因。

1. 前面已经提到过，Spring AOP要提供一个简单而强大的AOP框架，并不想因大二全使得框架本身过于臃肿。
2. 对于属性级别的Joinpoint，如果提供这个级别的拦截支持，那么就破坏了面向对象的封装，而且，完全可以通过对setter和getter方法的拦截达到同样的目的。
3. 如果应用需求非常特殊，完全超出了Spring AOP提供的那80%的需求支持，不放求助于现有的其他AOP实现产品。目前看来，AspectJ是Java平台对AOP铲平支持最完整的产品。因此，Spring AOP也提供了对AspectJ的支持。

## Spring AOP中的Pointcut

Spring中以接口定义`org.springframework.aop.Pointcut`作为其AOP框架中所有Pointcut的最顶层抽象，该接口定义了俩个方法用来帮助捕捉系统中的相应Joinpoint，并提供一个TruePoint，默认会对系统中的所有对象，以及对象上所有被支持的Joinpoint进行匹配。接口具体定义如下：

``` java
public interface Pointcut {
    Pointcut TRUE = TruePointcut.INSTANCE;

    ClassFilter getClassFilter();

    MethodMatcher getMethodMatcher();
}
```

ClassFilter和MethodMatcher分别用于匹配将执行织入操作的对象以及相应的方法。之所以将类型匹配和方法匹配分开定义，是因为可以重用不同级别的匹配定义，并且可以在不同的级别或者相同的级别上进行组合操作，或者只强制让某个子类只覆写相应的方法定义等。
ClassFilter接口的作用是对Joinpoint所处的对象进行Class级别的类型匹配，其定义如下：

``` java
@FunctionalInterface
public interface ClassFilter {

    boolean matches(Class<?> clazz);

    ClassFilter TRUE = TrueClassFilter.INSTANCE;
}
```

当织入的目标对象的class类型与Pointcut所规定的类型相符时，matches方法将会返回true，否则，返回false，即意味着不会对这个类型的目标对象进行织入操作。比如，如果我们仅希望对系统的Foo类型进行织入，则可以如下这样定义ClassFilter：

``` java
public class FooclassFilter{
    public boolean matchs(Class clazz){
        return Foo.class.equals(clazz);
    }
}
```

当然如果类型对我们所捕捉的Joinpoint无所谓，那么PointCut中使用的ClassFilter可以直接使用`ClassFilter TRUE = TrueClassFilter.INSTANCE`。当Pointcut中返回的ClassFilter类型为该类型实例时，Pointcut的匹配将会只对系统中所有的目标类以及他们的实例进行。

相对于ClassFilter的简单定义，MethodMatcher则要复杂得多。毕竟spring主要支持的就是方法级别的额拦截。MethodMatcher定义如下：

``` java
public interface MethodMatcher {

    boolean matches(Method method, @Nullable Class<?> targetClass);

    boolean isRuntime();

    boolean matches(Method method, @Nullable Class<?> targetClass, Object... args);

    MethodMatcher TRUE = TrueMethodMatcher.INSTANCE;
}
```