---
categories:
  - java
  - 教程
title: Spring Validation教程
abbrlink: a61a4fcc
date: 2020-09-13 17:22:53
---
# Spring Validation教程

<!-- 
1. 阐述validation DataBinder的关系
2. BeanWrapper
3. PropertyEditorSupport  PropertyEditor 解析属性，这个符合JavaBean标准
   core.convert 提供通用类型转换的能力和format提供UI 属性值的转换能力
   org.springframework.beans.propertyeditors 这个包下面提供了默认的字符串转换成对象

   字符串转成对象，通过java.beans.PropertyEditor接口来实现，Spring遵循了这套标准，然后进行转换。
4. spring自身提供了一个Validator 适配器

1. 通过实现Validator接口验证bean

-->

前面已经有俩篇文章介绍了Hibernate Validator的使用，而Spring Validation就是对Hibernate Validator又一层封装，方便在Spring中使用。这里我们先介绍Spring Validation的基本用法，包含在Service层中使用和在Controller中使用。

在Spring中有俩种校验Bean的方式，一种是通过实现org.springframework.validation.Validator接口，然后在代码中调用这个类，另外一种是按照Bean Validation方式来进行校验，即通过注解的方式，这一种和前面介绍的使用Hibernate Validator来进行校验基本一致。
<!-- more -->
## 继承org.springframework.validation.Validator实现校验例子

定义Person值对象

``` java
public class Person {

    private String name;
    private int age;

    // the usual getters and setters...
}
```

假设Person值对象，保证其名称不能为空，年龄不能小于0大于110，其对应的校验代码如下

``` java
public class PersonValidator implements Validator {

    /**
     * This Validator validates only Person instances
     */
    public boolean supports(Class clazz) {
        return Person.class.equals(clazz);
    }

    public void validate(Object obj, Errors e) {
        ValidationUtils.rejectIfEmpty(e, "name", "name.empty");
        Person p = (Person) obj;
        if (p.getAge() < 0) {
            e.rejectValue("age", "negativevalue");
        } else if (p.getAge() > 110) {
            e.rejectValue("age", "too.darn.old");
        }
    }
}
```

上面定义了一个简单的实现org.springframework.validation.Validator的例子，其实就是实现接口中国对应的方法，supports方法用来表示此校验用在哪个类型上，validate是设置校验逻辑的地点。其中ValidationUtils，是Spring封装的校验工具类，帮助快速实现校验。

使用上述Validator

``` java
Person person = new Person();
// 创建Person对应的DataBinder
DataBinder binder = new DataBinder(person);
// 设置校验
binder.setValidator(new PersonValidator());

// 由于Person对象中的属性为空，所以校验不通过
binder.validate();
BindingResult results = binder.getBindingResult();
System.out.println(results.hasErrors());
```

上面的例子比较简单，其中DataBinder是一个用来绑定对象的属性值和校验的工具类。

## Bean Validation校验方法

使用这一种校验方式，就是如何将Bean Validation需要使用的javax.validation.ValidatorFactory 和javax.validation.Validator如果和注入到容器中。spring默认有一个实现类LocalValidatorFactoryBean，它实现了上面Bean Validation中的俩个接口，并且也实现了org.springframework.validation.Validator接口。

首先定义一个配置类，将LocalValidatorFactoryBean注入到Spring容器中

```java
@Configuration
public class AppConfig {

    @Bean
    public LocalValidatorFactoryBean validator() {
        return new LocalValidatorFactoryBean();
    }
}
```

由于LocalValidatorFactoryBean实现了三个接口，因此想要使用Validator或者ValidatorFactory 只需要自动注入的方式注入到指定Bean中即可。下面给出了俩个例子如何使用org.springframework.validation.Validator，和javax.validation.Validator

首先定义一个Person值对象

``` java
@Data
public class Person {
    @NotNull
    private String name;
    @Min(0)
    @Max(110)
    private int age;
}
```

例子一，javax.validation.Validator

``` java
import javax.validation.Validator;

@Service
public class MyService {

    @Autowired
    private Validator validator;

    public  boolean validator(Person person){
        Set<ConstraintViolation<Person>> sets =  validator.validate(person);
        return sets.isEmpty();
    }

}
```

例子二，org.springframework.validation.Validator

```java
import org.springframework.validation.Validator;

@Service
public class MyService {

    @Autowired
    private Validator validator;

   public boolean validaPersonByValidator(Person person) {
      BindException bindException = new BindException(person, person.getName());
      validator.validate(person, bindException);
      return bindException.hasErrors();
   }
}
  
```

上面的例子都是校验JavaBean类型，在Hibernate Validation中还有一类是校验方法参数。在Spring Validation中使用例子如下。

首先需要注入MethodValidationPostProcessor，这个Bean会自动校验被@Validated注解的类中的方法。

使用例子如下

配置MethodValidationPostProcessor

```java
@Configuration
public class AppConfig {

    @Bean
    public MethodValidationPostProcessor validationPostProcessor() {
        return new MethodValidationPostProcessor();
    }
}
```

定义PersonService类，用于操作Person值对象，

``` java
@Service
@Validated
public class PersonService {

    public String testParams(@NotNull @Valid Person person) {
        return person.toString();
    }
}
```

验证上面的约束被执行

``` java
public class MyServiceTest extends CommonTest {

    @Test
    public void testValidator() {
        ApplicationContext context = new AnnotationConfigApplicationContext(AppConfig.class.getPackage().getName());
        PersonService myService = context.getBean(PersonService.class);
        Person person = new Person();
        myService.testParams(person);
    }

}
```

输出结果

``` text
javax.validation.ConstraintViolationException: testParams.arg0.name: 不能为null, testParams.arg0.age: 最小不能小于2
```

再次这里可能会出现如下的错误，如果遇到可以看这篇文章[记一次Spring配置事故](https://www.cnblogs.com/asfeixue/p/9535851.html),简单点就是Bean实例提前实例化，这里的AOP没有在这个实例上生效。
对于本文中的例子，可以在AppConfig中的方法声明为static方法，这样MethodValidationPostProcessor就可以提前实例化，并作用于AppConfigBean上

``` java
java信息: Bean 'XXX' of type [XXX] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
```

## 总结

本文主要介绍了Spring Validation相关的内容，首选是Spring本身提供了Validator接口，在使用时，配合DataBinder,其实这种和我们自己在代码中实现校验逻辑本身没有区别，只是说将校验逻辑封装了一层。另外一个部分介绍了如何在Spring中使用Bean Validation，分为俩类，一种是通过Validator注入到对应的Bean中，然后手动的校验对应的JavaBean，一种是使用Spring提供MethodValidationPostProcessor，来完成对方法参数的校验。