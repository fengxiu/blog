---
categories:
  - java
  - 教程
title: Hiberate Validator使用教程之自定义约束
abbrlink: 76d29d45
date: 2021-07-28 10:09:53
---

# Hiberate Validator使用教程之自定义约束

<!-- 
    1. 创建自定义约束
    2. 自定义错误信息配置
 -->
 前面一篇文章已经讲解了Hibernate Validator的基本使用。虽然校验库本身已经提供了许多的约束，但是不一定能够满足不同功能的需要，这时就需要自定义一些约束，本篇文章主要就是来学习如何自定义约束。

## 简单例子

创建一个简单的自定义约束分为以下三步

1. 创建一个约束注解
2. 实现一个约束注解对应的Validator
3. 定义一个默认的错误信息

下面的这个例子，是用来判断某个String字段是否是全部大小字段或者小写字段。
<!-- more -->
### 自定义注解

``` java
@Target({ FIELD, METHOD, PARAMETER, ANNOTATION_TYPE, TYPE_USE })
@Retention(RUNTIME)
@Constraint(validatedBy = CheckCaseValidator.class)
@Documented
@Repeatable(List.class)
public @interface CheckCase {

    String message() default "{org.hibernate.validator.referenceguide.chapter06.CheckCase." +"message}";

    Class<?>[] groups() default { };

    Class<? extends Payload>[] payload() default { };

    CaseMode value();

    @Target({ FIELD, METHOD, PARAMETER, ANNOTATION_TYPE })
    @Retention(RUNTIME)
    @Documented
    @interface List {
        CheckCase[] value();
    }
}

public enum CaseMode {
    UPPER,
    LOWER;
}
```

在我们自定义约束注解的时候，需要满足下面几个规定，这样Hibernate Validator才能够进行验证。

在注解中必须包含message，groups，payload这三个属性 ，他们的作用是

1. message:定义违反约束时，展示的错误信息
2. groups：用于指定约束对应的分组
3. payload：用于个性化配置，这个很少用，这里先不讲解了。

其它的和自定义注解没什么区别，

* value :用于表示注解对应值，这里定义的是CaseMode这个枚举
* 另外定义了这个注解可以重复定义，所以在注解上用@Repeatable，另外需要注意的一点是，Hibernate Validator规定，@Repeatable中的值，最好是List.class，所以在内部定义了List注解。用来承载可重复注解

### 自定义Validator

上面介绍了自定义注解中重要的属性，但是对@Constraint(validatedBy = CheckCaseValidator.class)这一块没有介绍，这个用来告诉Hibernate Validator当检测到这个注解时，应该调用的Validator是哪一个，这里对应的是CheckCaseValidator，源码如下

``` java
public class CheckCaseValidator implements ConstraintValidator<CheckCase, String> {

    private CaseMode caseMode;

    @Override
    public void initialize(CheckCase constraintAnnotation) {
        this.caseMode = constraintAnnotation.value();
    }

    @Override
    public boolean isValid(String object, ConstraintValidatorContext constraintContext) {
        if ( object == null ) {
            return true;
        }

        if ( caseMode == CaseMode.UPPER ) {
            return object.equals( object.toUpperCase() );
        }
        else {
            return object.equals( object.toLowerCase() );
        }
    }
}
```

自定义Validator要求实现ConstraintValidator接口，这个接口有俩个类型参数，第一个参数表示检测的注解，第二个表示这个注解检测对象类型。接口定义了俩个方法，initialize是一个默认方法，用来初始化，参数是当前检测对象对应的注解。isValid用来判断当前约束是否满足，其中ConstraintValidatorContext这个参数用来设置一些自定义的配置，平常用到的不多，等用到时候再补充。具体的可以看[ConstraintValidatorContext](https://docs.jboss.org/hibernate/stable/validator/reference/en-US/html_single/#validator-customconstraints-simple)。

### 自定义错误信息

如果想要自定义错误信息模板，可以在项目目录下创建一个ValidationMessages.properties ，配置对应的键值对。下面是一个例子

``` java
org.hibernate.validator.referenceguide.chapter06.CheckCase.message=Case mode must be {value}.
```

在运行的时候，Hibernate Validator会自动的去查找这个文件， 并去除对应的键值对配置到注解上。

### 使用自定义约束

``` java
public class Car {

    @NotNull
    private String manufacturer;

    @NotNull
    @Size(min = 2, max = 14)
    @CheckCase(CaseMode.UPPER)
    private String licensePlate;

    @Min(2)
    private int seatCount;

    public Car(String manufacturer, String licencePlate, int seatCount) {
        this.manufacturer = manufacturer;
        this.licensePlate = licencePlate;
        this.seatCount = seatCount;
    }

    //getters and setters ...
}
```

验证上面的自定义注解

```java
//invalid license plate
Car car = new Car( "Morris", "dd-ab-123", 4 );
Set<ConstraintViolation<Car>> constraintViolations =
        validator.validate( car );
assertEquals( 1, constraintViolations.size() );
assertEquals(
        "Case mode must be UPPER.",
        constraintViolations.iterator().next().getMessage()
);

//valid license plate
car = new Car( "Morris", "DD-AB-123", 4 );

constraintViolations = validator.validate( car );

assertEquals( 0, constraintViolations.size() );
```

类级别的约束基本上和这个差不多，这里就不具体介绍了，下面介绍下自定义Cross-parameter constraints。

## 自定义Cross-parameter约束

首先自定义Cross-parameter注解和上面的一样，下面这个例子比较参数的日期是否在正确的顺序。

代码如下

``` java
@Constraint(validatedBy = ConsistentDateParametersValidator.class)
@Target({ METHOD, CONSTRUCTOR, ANNOTATION_TYPE })
@Retention(RUNTIME)
@Documented
public @interface ConsistentDateParameters {

    String message() default "参数顺序错误";

    Class<?>[] groups() default { };

    Class<? extends Payload>[] payload() default { };
}
```

但是对应的验证器需要加上这个注解，@SupportedValidationTarget(ValidationTarget.PARAMETERS)，表示这个验证器应用在验证Cross-parameter参数上。

```java
@SupportedValidationTarget(ValidationTarget.PARAMETERS)
public class ConsistentDateParametersValidator implements
        ConstraintValidator<ConsistentDateParameters, Object[]> {

    @Override
    public void initialize(ConsistentDateParameters constraintAnnotation) {
    }

    @Override
    public boolean isValid(Object[] value, ConstraintValidatorContext context) {
        if ( value.length != 2 ) {
            throw new IllegalArgumentException( "Illegal method signature" );
        }

        //leave null-checking to @NotNull on individual parameters
        if ( value[0] == null || value[1] == null ) {
            return true;
        }

        if ( !( value[0] instanceof Date ) || !( value[1] instanceof Date ) ) {
            throw new IllegalArgumentException(
                    "Illegal method signature, expected two " +
                            "parameters of type Date."
            );
        }

        return ( (Date) value[0] ).before( (Date) value[1] );
    }
}
```

注意上面的类型参数，传递的是Object[]数组，其它的和前面的自定义约束没什么区别。

## 组合约束

有时一个属性需要同时满足多个约束，这时就可能要写很多的注解。或者有一些注解需要联合使用，这时组合约束就发会作用了，极大的简化我们的代码。自定义组合约束其实就是讲需要的注解组合起来。具体的例子如下

``` java
@NotNull
@Size(min = 2, max = 14)
@CheckCase(CaseMode.UPPER)
@Target({ METHOD, FIELD, ANNOTATION_TYPE, TYPE_USE })
@Retention(RUNTIME)
@Constraint(validatedBy = { })
@Documented
public @interface ValidLicensePlate {

    String message() default "{org.hibernate.validator.referenceguide.chapter06." +
            "constraintcomposition.ValidLicensePlate.message}";

    Class<?>[] groups() default { };

    Class<? extends Payload>[] payload() default { };
}
```

上面这个注解表示，需要同时满足@Size，@CheckCase，@NotNull三个约束。注意这里的@Constraint(validatedBy = { })是空。

使用这个注解和之前使用注解一样，例子如下

``` java
public class Car {

    @ValidLicensePlate
    private String licensePlate;

    //...
}
```

<!-- 如果需要快速报错，也就是只要发现组合注解里面有一个约束报错，则直接抛出来，可以在定义组合约束的时候，加上下面这个注解

```
ReportAsSingleViolation
``` -->

## 总结

这里介绍了如何简单的自定义约束，当然这里只能满足基本的需要，如果需要自定义错误信息，还有如果想在container上使用约束，可能还需要配置Value extraction相关的内容，但是这里已经足够使用。后续如果要用到会继续更新这篇文章。