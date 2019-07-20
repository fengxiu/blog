---
title: Spring AOP概述及其实现机制
categories:
  - java
  - spring
  - spring 源码分析
  - Aop
abbrlink: 32045bf1
date: 2019-07-14 16:27:41
tags:
---
上一篇文章中已经详细介绍了AOP是什么和AOP中重要的概念。因此，本篇文章将进入我们的正题，来对Spring AOP进行概述和介绍器实现的原理。

## spring AOP 概述

Spring AOP采用Java作为AOP的实现语言（AOL），SPring AOP可以更快捷地融入开发过程，学习曲线相对要平滑得多。而且，Spring AOP的设计哲学也是简单而强大，他不打算将所有的AOP需求全部囊括在内，而是要以有限的20%的AOP支持，来满足80%的AOP需求。如果Spring AOP无法满足需求，可以求助于AspectJ，Spring AOP对AspectJ也提供了很好的集成。

Spring AOP的AOL语言为Java。在此基础上，Spring AOP对AOP概念进行了适当的抽象和实现，使得每个AOP概念都可以落到实处，这些概念的抽象和实现，都以我们所熟悉的JAva语言的结构呈现在我们眼前。

## Spring AOP实现机制

Spring AOP属于第二代AOP，代用动态代理机制和字节码生成技术实现。动态代理机制和字节码生成都是在运行期间为目标对象生成一个代理对象，而将横切逻辑织入到这个代理对象中，系统最终使用的是织入了横切逻辑的代理对象，而不是真正的目标对象。

下面为了理解这种差别以及最中国可以达到的想过，我们这有必要先从动态代理机制的根源--代理模式开始说起

### 设计模式之代理模式

说到代理，我们大家应该都不会陌生。类如房产中介就是一种代理，我们偶尔也会使用到网络代理，等等。代理处于访问者与被访问者之间，可以隔离这俩者之间的直接交互，访问者与代理打交道就好像在跟被访问者在打交道一样，因为代理通常几乎会全权拥有被代理者的职能。
在软件系统中，代理机制的实现有现成的设计模式支持，就叫代理模式。在代理模式中，通常涉及4中角色，如下图所示：
![Xnip2019-07-14_16-51-26](/images/Xnip2019-07-14_16-51-26.jpg)

* **ISubject**:该接口是对被访问者或被访问资源的抽象。在严格的设计模式中，这样的抽象接口是必须的，但往宽了说，某些场景下不使用类似的统一抽象接口也是可以的。
* **SubjectImpl**：被访问者或被访问资源的具体实现类。
* **SubjectProxy**：被访问者或被访问资源的代理实现类，该类持有一个ISubject接口的具体事例。
* **Client**：代表访问者的抽象角色，Client将会访问ISubject类型的对象或者资源。在这个场景中，Client将无法请求具体的SubjectImpl，而是必须通过ISubject资源的访问代理类SubjectProxy进行。

在将请求转发给被代理对象SubjectImpl之前或者之后，都可以根据情况插入其他处理逻辑，比如在转发之前记录方法执行开始时间，在转发之后记录结束时间，这样就能够对SubjectImpl的request执行的时间进行检测。当然也可以做其他的事情。甚至也可以不做请求转发。具体的调用关系如下图所示
![Xnip2019-07-14_16-57-55](/images/Xnip2019-07-14_16-57-55.jpg)
代理对象SubjectProxy就像是SubjectImpl的影子，只不过这个影子通常拥有更多功能。如果SubjectImpl是系统中的Joinpoint所在的对象，即目标对象，那么就可以为这个目标对象创建一个代理对象，然后将横切逻辑添加到这个代理对象中。当系统使用这个代理对象运行的时候，原有逻辑实现和横切逻辑完全融合到一个系统中。
Spring AOP本质上就是采用这种代理机制实现的。但是，具体实现细节有所不同。
假设对系统中所有的request方法进行拦截，在每天午夜0点到次日6点之间，request调用不被接受，那么我们应该WieSubjectImpl提供一个ServiceControlSubjectProxy，已添加这样横切逻辑。这样就有了下面这份代码清单：

``` java
public class ServiceControlSubjectProxy implements ISubject{
    private ISubject subject;

    public ServiceControlSubjectProxy(ISubject s){
        this.subject = s;
    }
    public String request(){
        TimeOfDay startTime = new TimeOfDay(0,0,0);
        TimeOfDay endTime = new TimeOfDay(5,59,59);
        TImeOfDay currentTime = new TimeOfDay();
        if(currentTime.isAfter(startTime) && 
                currentTime.isBefore(endTime)){
                    return null;
                }
        String originResult = subject.request;
        return originResut;
    }
}
```

有了这个代理类之后，就可以像使用SUbjectImpl一样使用这个类。
但是系统中可不一定就ISubject的实现类有request方法，IRequestable接口以及相应实现类可能也有request方法，他们也是我们需要横切的关注点。IRequestable及其实现类的代理如同上面ServiceControlSubjectProxy的代码差不多，只不过将接口换成了Irequest。
这里就会出现一个问题，虽然JoinPoint相同（request方法的执行），但是对应的目标对象类型是不一样的。针对不一样的目标对象类型，我们要为器单独实现一个代理对象。而实际上，这些代理对象所要添加的横切逻辑是一样的。当系统中存在成百上千的复合Pointcut匹配条件的目标对象时，我们就要为这成百上千的目标单独创建成百上千的代理对象，。
这种为对应的目标对象创建静态代理的方法，原理上是可行的，但具体应用上存在问题，所以要找到一种办法，来解决这种困境。

### 动态代理
JDK1.3之后引入了一种称之为动态代理的机制。使用该机制，我们可以为指定的接口在系统运行期间动态地生成代理对象，从而帮助我们走出最初使用静态代理实现AOP的窘境。
动态代理机制的实现主要是有一个类和一个接口组成，即java.lang.reflect.Proxy和java..lang.reflect.InvocationHandler接口。下面，我们看一下如何使用动态代理来实现之前的**request访问时间控制**功能。虽然要为ISubject和IRequestable俩种类型提供代理对象，但因为代理对象要添加的横切逻辑是一样的，所以，我们只需要实现一个InvocationHAndler就可以了，实现代码如下：

``` java
 public class ReuqestCtrlInvocationHandler implements InvocationHandler{
    private Object target;
    public ReuqestCtrlInvocationHandler(Object target){
        this.target = target;
    }

    public Object invoke(Object proxy,Method method,Object[] args)
    throws Throwable{
        if(method.getName().equals("request")){
               TimeOfDay startTime = new TimeOfDay(0,0,0);
                TimeOfDay endTime = new TimeOfDay(5,59,59);
                TImeOfDay currentTime = new TimeOfDay();
                if(currentTime.isAfter(startTime) && 
                        currentTime.isBefore(endTime)){
                            return null;
                        }
                String originResult = subject.request;
                return originResut;  
        }
    }
 }
```

然后，我们就可以使用Proxy类，根据RequestCtrlinvocationHandler的逻辑，为ISubject和IRequestable俩种类型生成相应的代理对象实例。代码如下：

``` java
ISubject subject = (ISubject)Proxy.newProxyInstance(ProxyRunner.class.getClassLoader(),new Class[]{ISubject.class},
new ReuqestCtrlInvocationHandler());

IRequstable requestable .....大体上与上面类似
```

即使还有更多的目标对象类型，只要他们依然织入的横切逻辑相同，用ReuqestCtrlInvocationHandler一个类并通过Proxy为他们生成响应的动态代理实例就可以满足要求。当Proxy动态生成的代理对象上相应的接口方法被调用时，对应的InvocationHandler就会拦截响应的方法调用，并进行逻辑处理。

InvocationHandler就是我们实现横切逻辑的地方，它是横切逻辑的载体，作用跟Advice是一样的。所以，在使用动态代理机制实现AOP的过程中，我们可以在InnvocationHandler的基础上细化程序结构，并根据Advice的类型，分化出对应不同Advice类型的程序结构。
动态代理虽然好，但不能满足所有的需求。因为动态代理机制只能对实现了相应Interface的类使用。因此对于没有实现任何Interface的目标对象，我们需要寻找其他方式为其动态的生成代理对象。
默认情况下，如果Spring AOP发现目标对象实现了相应Interface，则采用动态代理机制为其生成代理对象实例。而如果目标对象没有实现任何Interface，Spring AOP会尝试使用一个称谓CGLIB的开源的动态字节码生成类库，为目标对象生成动态的代理对象实例。

### 动态字节码生成

使用动态字节码生成技术扩展对象行为的原理是，我们可以对目标对象进行继承扩展，为其生成相应的子类，而子类可以通过覆写来扩展父类的行为，只要将横切逻辑的实现放到子类中，然后让系统使用扩展后的目标对象的子类，就可以达到与代理模式相同的效果。
但是，使用继承的方式来扩展对象定义，也不能像静态代理模式那样，为每个不同类型目标对象都单独创建相应的扩展子类。所以，我们要借助于CGLIB这样的同台字节码生成库，在系统运行期间动态地为目标对象生成相应的扩展子类。
为了演示CGLIB的使用以及最终可以达到的效果，我们定义的目标类如下所示：

``` java
public class Requestable{
    public void request(){
        System.out.println("rg in Requestable without inplement any interface")
    }
}
```

CGLIB可以对实现了某种接口的类，或者没有实现任何接口的类进行扩展。但我们已经说过，可以使用动态dialing机制来扩展实现了某种接口的饿目标类，所以，这里主要演示没有实现任何接口的目标类是如何使用CGLIB来进行扩展。

要对Requestable类进行扩展，首先要实现一个net.sf.cglib.proxy.Callback。不过更多的时候，我们会直接使用net.sf.cglin.proxy.MethodInterceptor接口（MethodInterceptor扩展了Callback接口）。代码清单8-6给出了针对我们的Requestable所提供的Callback实现。

``` java
public class RequestCtrlCallback implements MethodInterceptor{
    public object intercept(Object object,Method method,Object[] args,MethodProxy proxy) throws Throwable{
        if(method.getName().equals("request")){
                TimeOfDay startTime = new TimeOfDay(0,0,0);
                TimeOfDay endTime = new TimeOfDay(5,59,59);
                TImeOfDay currentTime = new TimeOfDay();
                if(currentTime.isAfter(startTime) && 
                        currentTime.isBefore(endTime)){
                            return null;
                }
                String originResult = proxy.invokeSuper(object,args);
                return originResut;  
        }
    }
}
```

这样，RequestCtrlCallback就实现了对Request方法请求进行访问扩展的逻辑。想在我们要通过CGLIB的Enchaner为目标对象动态地生成一个子类，并将RequestCtrlCallback中的横切逻辑附加到该子类中，代码如下所示：

``` java
Enchacner enchacner = new Enchacner();
enchancer.setSuperClass(Requestable.class);
enchancer.setCallback(new RequestCtrlCallback() );
Requestable proxy = (Requestable)enchancer.create();
proxy.request();
```

通过为enchancer指定需要生成的子类对应的父类，以及Callback实现，enhancer最终为我们生成了需要的代理对象示例。使用CGLIB对类进行扩展的唯一限制就是无法对final方法进行覆写。
