---
title: '注解之@Inherited和@Repeatable'
tags:
  - 注解
categories:
  - java
  - 基础
  - 注解
author: fengxiu
abbrlink: ca158b7a
date: 2019-03-04 07:22:00
---
## Inherited

前面也介绍过，这个注解作用是注解其他注解，让注解具有继承的特性。但是继承是有条件的。
下面是摘自javaDOC上的一段话

``` txt
Note that this meta-annotation type has no effect if the annotated type is used to annotate anything other than a class. Note also that this meta-annotation only causes annotations to be inherited from superclasses; annotations on implemented interfaces have no effect.
```

中文意思如下

``` txt
请注意，如果带有继承特性的注解使用在其他元素而不是类上，则注解的继承特性是没有效果的。还要注意，这个元注解只会从父类继承注解;实现接口上的注解没有作用。
```

### 具体示例

#### 标记在类上的继承情况

自定义一个带有继承特性的注解

```java
@Inherited // 可以被继承
@Retention(java.lang.annotation.RetentionPolicy.RUNTIME) // 可以通过反射读取注解
public @interface BatchExec {
    String value();
}
```

<!-- more -->
被注解的父类

```java
@BatchExec(value = "类名上的注解")
public abstract class ParentClass {

    @BatchExec(value = "父类的abstractMethod方法")
    public abstract void abstractMethod();

    @BatchExec(value = "父类的doExtends方法")
    public void doExtends() {
        System.out.println(" ParentClass doExtends ...");
    }

    @BatchExec(value = "父类的doHandle方法")
    public void doHandle() {
        System.out.println(" ParentClass doHandle ...");
    }
}
```

子类：

```java
public class SubClass1 extends ParentClass {

    // 子类实现父类的抽象方法
    @Override
    public void abstractMethod() {
        System.out.println("子类实现父类的abstractMethod抽象方法");
    }
    //子类继承父类的doExtends方法

    // 子类覆盖父类的doHandle方法
    @Override
    public void doHandle() {
        System.out.println("子类覆盖父类的doHandle方法");
    }
}
```

使用反射来测试子类是否继承了父类的注解，测试代码如下：

```java
public class MainTest1 {
    public static void main(String[] args) throws SecurityException, NoSuchMethodException {

        Class<SubClass1> clazz = SubClass1.class;

        // 类上注解测试
        if (clazz.isAnnotationPresent(BatchExec.class)) {
            BatchExec cla = clazz.getAnnotation(BatchExec.class);
            System.out.println("类：子类可继承");
        } else {
            System.out.println("类：子类不能继承到父类类上Annotation");
        }

        // 实现抽象方法测试
        Method method = clazz.getMethod("abstractMethod", new Class[] {});
        if (method.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method.getAnnotation(BatchExec.class);
            System.out.println("子类实现抽象方法：子类可继承");
        } else {
            System.out.println("子类实现抽象方法：没有继承到父类抽象方法中的Annotation");
        }

        // 子类未重写的方法
        Method methodOverride = clazz.getMethod("doExtends", new Class[] {});
        if (methodOverride.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = methodOverride.getAnnotation(BatchExec.class);
            System.out.println("子类未实现方法：子类可继承，注解读取='" + ma.value() + "'");
        } else {
            System.out.println("子类未实现方法：没有继承到父类doExtends方法中的Annotation");
        }

        // 子类重写的方法
        Method method3 = clazz.getMethod("doHandle", new Class[] {});
        if (method3.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method3.getAnnotation(BatchExec.class);
            System.out.println("子类覆盖父类的方法：继承到父类doHandle方法中的Annotation“);
        } else {
            System.out.println("子类覆盖父类的方法:没有继承到父类doHandle方法中的Annotation");
        }

        // 子类重写的方法
        Method method4 = clazz.getMethod("doHandle2", new Class[] {});
        if (method4.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method4.getAnnotation(BatchExec.class);
            System.out.println("子类未实现方法doHandle2：子类可继承");
        } else {
            System.out.println("子类未实现方法doHandle2：没有继承到父类doHandle2方法中的Annotation");
        }
    }
}
```

结果：

``` txt
类：子类可继承，
子类实现抽象方法：没有继承到父类抽象方法中的Annotation
子类未实现方法：  子类可继承
子类覆盖父类的方法:没有继承到父类doHandle方法中的Annotation
子类未实现方法doHandle2：没有继承到父类doHandle2方法中的Annotation
```

#### 标记在接口上的继承情况

```java
@BatchExec(value = "接口上的注解")
public interface Parent {
    void abstractMethod();
}
```

接口的继承类

```java
public  class ParentClass3  {

    public void abstractMethod() {
        System.out.println("ParentClass3");    
    }

    @BatchExec(value = "父类中新增的doExtends方法")
    public void doExtends() {
        System.out.println(" ParentClass doExtends ...");
    }
}
```

该继承类的注解可见测试：

```java
public class MainTest3 {
    public static void main(String[] args) throws SecurityException, NoSuchMethodException {

        Class<ParentClass3> clazz = ParentClass3.class;

        if (clazz.isAnnotationPresent(BatchExec.class)) {
            BatchExec cla = clazz.getAnnotation(BatchExec.class);
            System.out.println("类：子类可继承");
        } else {
            System.out.println("类：子类不能继承到接口类上Annotation");
        }

        // 实现抽象方法测试
        Method method = clazz.getMethod("abstractMethod", new Class[] {});
        if (method.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method.getAnnotation(BatchExec.class);
            System.out.println("子类实现抽象方法：子类可继承");
        } else { 
            System.out.println("子类实现抽象方法：没有继承到接口抽象方法中的Annotation");
        }

        //子类中新增方法
        Method methodOverride = clazz.getMethod("doExtends", new Class[] {});
        if (methodOverride.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = methodOverride.getAnnotation(BatchExec.class);
            System.out.println("子类中新增方法：可被读取注解");
        } else {
            System.out.println("子类中新增方法：不能读取注解");
        }

    }
}
```

结果：

```txt
类：子类不能继承到接口类上Annotation
子类实现抽象方法：没有继承到接口抽象方法中的Annotation
子类中新增方法：注解读取='父类中新增的doExtends方法
```

#### 子类的子类注解继承情况

```java
public class SubClass3 extends ParentClass3 {

    // 子类实现父类的抽象方法
    @Override
    public void abstractMethod() {
        System.out.println("子类实现父类的abstractMethod抽象方法");
    }

    // 子类覆盖父类的doExtends方法
}
```

测试类：

```java
public class MainTest33 {
    public static void main(String[] args) throws SecurityException, NoSuchMethodException {

        Class<SubClass3> clazz = SubClass3.class;

        if (clazz.isAnnotationPresent(BatchExec.class)) {
            BatchExec cla = clazz.getAnnotation(BatchExec.class);
            System.out.println("类：子类可继承");
        } else {
            System.out.println("类：子类不能继承到父类类上Annotation");
        }

        // 实现抽象方法测试
        Method method = clazz.getMethod("abstractMethod", new Class[] {});
        if (method.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method.getAnnotation(BatchExec.class);
            System.out.println("子类实现抽象方法：子类可继承");
        } else { 
            System.out.println("子类实现抽象方法：没有继承到父类抽象方法中的Annotation");
        }

        //子类未重写的方法
        Method methodOverride = clazz.getMethod("doExtends", new Class[] {});
        if (methodOverride.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = methodOverride.getAnnotation(BatchExec.class);
            System.out.println("子类未实现方法：子类可继承");
        } else {
            System.out.println("子类未实现方法：没有继承到父类doExtends方法中的Annotation");
        }

    }
}
```

结果：

```txt
类：子类不能继承到父类类上Annotation
子类实现抽象方法：没有继承到父类抽象方法中的Annotation
子类未实现方法：子类可继承
```

### 总结

从上面可以看出，被`@Inherited`标记过的注解，标记在类上面可以被子类继承，标记在方法上，如果子类实现了此方法，则不能继承此注解，如果子类是继承了方法，而没有重新实现方法则可以继承此方法的注解。

## Repetable

允许在同一申明类型（类，属性，或方法）的多次使用同一个注解

一个简单的例子
java 8之前也有重复使用注解的解决方案，但可读性不是很好，比如下面的代码：

``` java
public @interface Authority {
     String role();
}

public @interface Authorities {
    Authority[] value();
}

public class RepeatAnnotationUseOldVersion {
    
    @Authorities({@Authority(role="Admin"),@Authority(role="Manager")})
    public void doSomeThing(){
    }
}
```

由另一个注解来存储重复注解，在使用时候，用存储注解Authorities来扩展重复注解，我们再来看看java 8里面的做法：

``` java
@Repeatable(Authorities.class)
public @interface Authority {
     String role();
}

public @interface Authorities {
    Authority[] value();
}

public class RepeatAnnotationUseNewVersion {
    @Authority(role="Admin")
    @Authority(role="Manager")
    public void doSomeThing(){ }
}
```

不同的地方是，创建重复注解Authority时，加上@Repeatable,指向存储注解Authorities，在使用时候，直接可以重复使用Authority注解。从上面例子看出，java 8里面做法更适合常规的思维，可读性强一点
