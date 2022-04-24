---
categories:
  - java
  - 教程
title: Hibernate Validator 学习与使用
abbrlink: fc06a9d1
date: 2020-09-28 10:09:53
---
# Hibernate Validator 学习与使用

<!-- 
    1.  配置
    2.  简单的demo
    3.  如何声明和校验约束 : 约束集成，级联约束
    4.  自定义约束
    5.  配置约束错误语句
    6.  配置ValueExectuao
    7.  配置Validator
    8.  
 -->
在项目，校验数据是必不可少的一步。因此如果能写出一个好的校验代码，必定能提高项目的鲁棒性。目前我做的项目大部分使用的是SpringBoot，基本上都是在控制器那一层通过注解@Valid等来校验参数，虽然经常使用，但是没有好好的进行整理。所以接下来会写几篇文章，对这一块进行整理。

大概会整理如下几个部分

1. Hibernate Validator的用法，
2. 如何在Spring中使用Hibernate Validator
3. 介绍如何在Spring MVC中使用。
4. 分析Spring MVC使用Validator的原理。

本篇文章主要是对Hibernate Validator用法进行简单的介绍

## Hibernate Validator简介

验证数据是贯穿所有应用程序层（从应用层到持久层）的常见任务。通常在每一层都实现相同的验证逻辑，这是非常耗时和容易出错的。为了避免这些验证的重复，开发人员经常将验证逻辑直接绑定到域模型中，用验证代码（实际上是关于类本身的元数据）将域类弄乱。
![application-layers](https://cdn.jsdelivr.net/gh/fengxiu/img/application-layers.png)

Jakarta Bean Validation 2.0——为Entity和方法的验证定义了一个元数据模型和API。默认的元数据源是Annotation，同时也能够通过使用XML覆盖和扩展元数据。API没有绑定到特定的应用层或者programming model.。它与web层或持久层都没有强绑定，可用于服务器端应用程序编程和客户端上应用程序。
![application-layers2](https://cdn.jsdelivr.net/gh/fengxiu/img/application-layers2.png)

Hibernate Validator和Jakarta Bean Validation的区别：Jakarta Bean Validation是一种规范，Hibernate Validator是对个规范的一种实现。
<!-- more -->
## 简单使用例子

maven 配置如下

``` xml
<dependency>
    <groupId>org.hibernate.validator</groupId>
    <artifactId>hibernate-validator</artifactId>
    <version>6.1.5.Final</version>
</dependency>
<dependency>
    <groupId>org.glassfish</groupId>
    <artifactId>jakarta.el</artifactId>
    <version>3.0.3</version>
</dependency>
```

应用约束在Java Bean上

``` java
package org.hibernate.validator.referenceguide.chapter01;

import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;

public class Car {

    @NotNull
    private String manufacturer;

    @NotNull
    @Size(min = 2, max = 14)
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

1. @NotNull：表明这个属性不能为null
2. @Size： 表明licensePlate的长度在2到14个字符之间
3. @Min ：表明seatCount最小是2

上面的例子已经完整的定义了对这个Bean的约束，下面的代码是如何验证这些约束

``` java
import java.util.Set;
import javax.validation.ConstraintViolation;
import javax.validation.Validation;
import javax.validation.Validator;
import javax.validation.ValidatorFactory;

import org.junit.BeforeClass;
import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class CarTest {

    private static Validator validator;

    @BeforeClass
    public static void setUpValidator() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @Test
    public void manufacturerIsNull() {
        Car car = new Car( null, "DD-AB-123", 4 );

        Set<ConstraintViolation<Car>> constraintViolations =
                validator.validate( car );

        assertEquals( 1, constraintViolations.size() );
        assertEquals( "must not be null", constraintViolations.iterator().next().getMessage() );
    }

    @Test
    public void licensePlateTooShort() {
        Car car = new Car( "Morris", "D", 4 );

        Set<ConstraintViolation<Car>> constraintViolations =
                validator.validate( car );

        assertEquals( 1, constraintViolations.size() );
        assertEquals(
                "size must be between 2 and 14",
                constraintViolations.iterator().next().getMessage()
        );
    }

    @Test
    public void seatCountTooLow() {
        Car car = new Car( "Morris", "DD-AB-123", 1 );

        Set<ConstraintViolation<Car>> constraintViolations =
                validator.validate( car );

        assertEquals( 1, constraintViolations.size() );
        assertEquals(
                "must be greater than or equal to 2",
                constraintViolations.iterator().next().getMessage()
        );
    }

    @Test
    public void carIsValid() {
        Car car = new Car( "Morris", "DD-AB-123", 2 );

        Set<ConstraintViolation<Car>> constraintViolations =
                validator.validate( car );

        assertEquals( 0, constraintViolations.size() );
    }
}
```

在setUp()方法中，使用ValidatorFactory创建一个Validator对象。Validator实例是线程安全的，可以多次重用。因此，它可以安全地存储在static属性中，并用于测试方法，以验证不同的Car实例。

调用validate()方法返回一组ConstraintViolation实例，您可以对其进行迭代，以查看发生了哪些验证错误。

前三个测试方法显示了一些预期的约束冲突：

* 在manufacturerIsNull()中违反了对manufacturer的@NotNull约束
* licensePlateTooShort()中违反了对licensePlateTooShort上的@Size约束
* seatCountTooLow()中违反了seatCount上的@Min约束

如果对象验证成功，validate()将返回一个空集，如carIsValid()方法中所示。

## 如何声明和校验约束

约束声明即约束可以放置的位置，主要有以下俩大类，一种是放置在Bean上，另外一种是放置在方法上。校验约束根据校验的对象，也分为俩种，一种是对Bean约束校验，一种是对方法约束校验。

### 声明bean约束

Jakarta Bean Validation中的约束通过Java注解表示。在Bean上声明约束，主要有以下四种类型的bean约束：

* field constraints
* property constraints
* container element constraints
* class constraints

#### 属性约束(field constraints)

约束可以通过注解类的字段来表示。下面是一个实例

``` java
public class Car {

    @NotNull
    private String manufacturer;

    @AssertTrue
    private boolean isRegistered;

    public Car(String manufacturer, boolean isRegistered) {
        this.manufacturer = manufacturer;
        this.isRegistered = isRegistered;
    }

    //getters and setters...
}
```

当使用field-leve级别的约束时，约束可以应用于任何访问类型（public、private等）的字段。不过，不支持对静态字段的约束。

<!-- 这里我的猜想它是通过反射来获取属性值进行验证。 -->

注意：验证字节码增强的对象时，应该使用property level约束，因为字节码增强库无法通过反射确定字段访问。

#### Property-level constraints

如果定义的model遵从JavaBean规范，也可以注解这些properties代替注解field。这里需要说明的一点是，Field大概是指类的内部成员变量，property是指在可以被外部通过getter/setter方法读取或者设置的属性
区别可以看这篇文章[Java中field和property的区别](https://xinxingastro.github.io/2018/07/21/Java/Java%E4%B8%ADfield%E5%92%8Cproperty%E7%9A%84%E5%8C%BA%E5%88%AB/)

实例如下：

``` java
public class Car {

    private String manufacturer;

    private boolean isRegistered;

    public Car(String manufacturer, boolean isRegistered) {
        this.manufacturer = manufacturer;
        this.isRegistered = isRegistered;
    }

    @NotNull
    public String getManufacturer() {
        return manufacturer;
    }

    public void setManufacturer(String manufacturer) {
        this.manufacturer = manufacturer;
    }

    @AssertTrue
    public boolean isRegistered() {
        return isRegistered;
    }

    public void setRegistered(boolean isRegistered) {
        this.isRegistered = isRegistered;
    }
}
```

这里需要注意的一点是，是Property的getter方法被注解，不是setter方法。另外在使用约束的时候，在一个class里面最好field和Property俩个只选择一个，否则会出现校验俩次的现象。

#### Container element 约束

可以直接在参数化类型的类型参数上指定约束：这些约束称为Container element约束。

Hibernate Validator 支持的container element约束有以下几种

* 实现了Java.tuil.Iterable(List ,Set)
* 实现了java.util.Map，支持验证key和value
* Java.util.Optional 一类的
* 实现了javafx.beans.observable.ObservableValue

另外也可以自定义container element 约束在自定义的container类型上。

下面是一个Set的例子，其它的Container element约束和这个差不多

``` java
public class Car {
    private Set<@NotNull String> parts = new HashSet<>();

    public void addPart(String part) {
        parts.add(part);
    }
}
```

#### Class-level 约束

约束也可以放在class-level上，在这种情况下，不是单一的属性被验证，而是验证完整的对象。

``` java
@ValidPassengerCount
public class Car {

    private int seatCount;

    private List<Person> passengers;

    //...
}
```

ValidPassengerCount这个是自定义约束，用于验证passengers的长度是否小于seatCount。

### 校验bean约束

主要是通过Validator进行校验，Validator是一个接口、下一节将展示如何获取Validator实例。
之后，您将学习如何使用Validator接口的不同方法。

#### 获取Validator实例

通常是通过Validation和ValidatorFactory类来获取，示例如下

``` java
ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
validator = factory.getValidator();
```

#### Validator 方法介绍

Validator接口主要有三个方法，被用于验证整个实体或者实体的属性。

这三个方法都会返回Set< ConstraintViolation>类型的对象，如果为空，则表示没有错误。

所有的验证方法都有一个可变参数，用于指定验证的Group，如果参数没有指定，则表示使用默认的组。同时也可以指定多个group。

##### validate()

这个方法用于验证一个Bean的所有约束。
示例如下

``` java
Car car = new Car( null, true );

Set<ConstraintViolation<Car>> constraintViolations = validator.validate( car );

assertEquals( 1, constraintViolations.size() );
assertEquals( "must not be null", constraintViolations.iterator().next().getMessage() );
```

##### validateProperty()

可以用于验证一个给定对象的单个Property。

实例如下

``` java
Car car = new Car( null, true );

Set<ConstraintViolation<Car>> constraintViolations = validator.validateProperty(
        car,
        "manufacturer"
);

assertEquals( 1, constraintViolations.size() );
assertEquals( "must not be null", constraintViolations.iterator().next().getMessage() );
```

##### validateValue()

可以验证一个对象的单独Property或者完整对象，如果没有指定Property，则验证完整对象。

``` java
Set<ConstraintViolation<Car>> constraintViolations = validator.validateValue(
        Car.class,
        "manufacturer",
        null
);

assertEquals( 1, constraintViolations.size() );
assertEquals( "must not be null", constraintViolations.iterator().next().getMessage() );
```

### 声明方法约束

方法约束主要分为俩大类，一个是对参数的约束，另外一个是对方法返回值的约束。

#### 参数约束

声明参数约束和声明Bean约束大体上是差不多的，例子如下

``` java
public class RentalStation {

    public RentalStation(@NotNull String name) {
        //...
    }

    public void rentCar(
            @NotNull Customer customer,
            @NotNull @Future Date startDate,
            @Min(1) int durationInDays) {
        //...
    }
}
```

上面的声明表达的意思和在Bean约束中表达的意思是一样的，只是用的地点不一样而已。这里需要注意的一点是，方法本身执行的时候，并不会去验证这些约束，需要在方法执行前，调用ExecutableValidator来验证这些约束，这些约束才会生效。一般会通过代理，Aop等方式来在方法调用前进行拦截，验证这些约束。通常情况下，约束仅用于实例方法。

#### Cross-parameter（交叉验证）

有时一个方法的约束，可能需要保证参数一起满足特定的条件，这时就需要Cross-parameter。声明例子如下。

``` java
public class Car {
    @LuggageCountMatchesPassengerCount(piecesOfLuggagePerPassenger = 2)
    public void load(List<Person> passengers, List<PieceOfLuggage> luggage) {
        //...
    }
}
```
LuggageCountMatchesPassengerCount 这个是一种自定义约束，用来限制，passengers和luggage的数量一致。

#### 返回值约束

方法返回值约束，声明如下

``` java
public class RentalStation {

    @ValidRentalStation
    public RentalStation() {
        //...
    }

    @NotNull
    @Size(min = 1)
    public List<@NotNull Customer> getCustomers() {
        //...
        return null;
    }
}
```
其中方法参数约束和返回值约束使用位置一样，主要通过以下方式来区分，在注解中指定validationAppliesTo的值，例子如下

```
public class Garage {

    @ELAssert(expression = "...", validationAppliesTo = ConstraintTarget.PARAMETERS)
    public Car buildCar(List<Part> parts) {
        //...
        return null;
    }

    @ELAssert(expression = "...", validationAppliesTo = ConstraintTarget.RETURN_VALUE)
    public Car paintCar(int color) {
        //...
        return null;
    }
}
```

以下三种情况，不用指定，验证方法自动可以判断

1. 没有返回值的方法，默认为参数类型验证。
2. 没有参数的方法，默认为返回值类型约束
3. Bean约束不用指定。

### 验证方法约束

主要是通过ExecutableValidator接口来进行验证

#### 获取实例

``` java
ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
executableValidator = factory.getValidator().forExecutables();
```

#### 方法使用

主要有以下四个方法

1. validateParameters ：验证方法参数
2. validateConstructorParameters：验证构造器方法
3. validateReturnValue：验证方法返回值
4. validateConstructorReturnValue：验证构造器返回值

使用方式都差不多，这里介绍下方法相关的验证

参数验证

``` java
Car object = new Car( "Morris" );
Method method = Car.class.getMethod( "drive", int.class );
Object[] parameterValues = { 80 };
Set<ConstraintViolation<Car>> violations = executableValidator.validateParameters(
        object,
        method,
        parameterValues
);

assertEquals( 1, violations.size() );
Class<? extends Annotation> constraintType = violations.iterator()
        .next()
        .getConstraintDescriptor()
        .getAnnotation()
        .annotationType();
assertEquals( Max.class, constraintType );
```

返回值验证

``` java
Car object = new Car( "Morris" );
Method method = Car.class.getMethod( "getPassengers" );
Object returnValue = Collections.<Passenger>emptyList();
Set<ConstraintViolation<Car>> violations = executableValidator.validateReturnValue(
        object,
        method,
        returnValue
);

assertEquals( 1, violations.size() );
Class<? extends Annotation> constraintType = violations.iterator()
        .next()
        .getConstraintDescriptor()
        .getAnnotation()
        .annotationType();
assertEquals( Size.class, constraintType );
```
### 内置的Bean约束

这一块具体可以看[内置约束](https://docs.jboss.org/hibernate/validator/4.3/reference/zh-CN/html_single/#validator-defineconstraints-builtin)
不过这个是比较老的版本，如果你的英文还可以，可以去看官方文档。

## 约束继承

对于声明在Bean上的约束，当一个类实现一个接口或者类时，所有父类上的约束都会应用在子类上。

例子如下

``` java
public class Car {

    private String manufacturer;

    @NotNull
    public String getManufacturer() {
        return manufacturer;
    }

    //...
}

public class RentalCar extends Car {

    private String rentalStation;

    @NotNull
    public String getRentalStation() {
        return rentalStation;
    }

    //...
}
```

比如上面的RentCar继承了Car，当进行约束验证的时候，同时会验证manufacturer是否符合要求。

对于方法上的约束集成，则不允许覆盖参数类型的约束，也就是父类型的方法参数上指定了约束，子类的方法参数只能继承此约束，而不能覆盖或者重写。对于返回值，则是采用累加的策略。

下面这个类实现的例子，就是违反了方法约束规则，运行时会报错

``` java
public interface Vehicle {

    void drive(@Max(75) int speedInMph);
}

public class Car implements Vehicle {

    @Override
    public void drive(@Max(55) int speedInMph) {
        //...
    }
}
```

返回值约束继承的例子

``` java
public interface Vehicle {

    @NotNull
    List<Person> getPassengers();
}

public class Car implements Vehicle {

    @Override
    @Size(min = 1)
    public List<Person> getPassengers() {
        //...
        return null;
    }
}
```

这个例子中，对于getPassengers这个方法，会同时校验@NotNull和@Size俩个约束


## 级联验证

Jakarta Bean Validation API不仅允许验证单个类实例，同时还会验证Object graphs，看下面的例子，你就可以理解这是什么意思

``` java
public class Car {

    @NotNull
    @Valid
    private Person driver;

    //...
}
public class Person {

    @NotNull
    private String name;

    //...
}
```

当校验上面的Car对象时，属性引用的Person对象也会被校验。这是因为在Car的Person属性上加了@Valid注解，当验证Person对象里面约束失败时，对Car对象的验证也会失败。

这里需要注意的一点是，在级联验证时，null默认会被忽略掉。

级联验证也可以被用在Container element 约束上。具体例子如下

``` java
public class Car {

    private List<@NotNull @Valid Person> passengers = new ArrayList<Person>();

    private Map<@Valid Part, List<@Valid Manufacturer>> partManufacturers = new HashMap<>();

    //...
}

public class Part {

    @NotNull
    private String name;

    //...
}
public class Manufacturer {

    @NotNull
    private String name;

    //...
}
```

在方法参数上也可以使用级联验证，使用方式和上面列举的一样，只是在参数前面加上@Valid注解。
具体例子如下

``` java
public class Garage {

    public boolean checkCars(@NotNull List<@Valid Car> cars) {
        //...
        return false;
    }
}
```

## 分组校验

分组校验允许我们在同一个类里面，在不同的场景下有不同的校验规则。具体的用法看下面这个例子：

Person实体

``` java
public class Person {

    @NotNull
    private String name;

    public Person(String name) {
        this.name = name;
    }

    // getters and setters ...
}

```

上面的约束@NotNull并没有指定group参数，这表明此约束用在javax.validation.groups.Default这个组下面。

Driver实体，继承了Person，并限制了年龄最小是18，同时必须拥有驾照。定义如下

```java
public class Driver extends Person {

    @Min(
            value = 18,
            message = "You have to be 18 to drive a car",
            groups = DriverChecks.class
    )
    public int age;

    @AssertTrue(
            message = "You first have to pass the driving test",
            groups = DriverChecks.class
    )
    public boolean hasDrivingLicense;

    public Driver(String name) {
        super( name );
    }

    public void passedDrivingTest(boolean b) {
        hasDrivingLicense = b;
    }

    public int getAge() {
        return age;
    }

    public void setAge(int age) {
        this.age = age;
    }
}
```

这里的DriverCheck类只是起到一个标记的作用，区分这个约束用在DriverChek这个组。DriverClass定义如下：

```java
public interface DriverChecks {
}
```

最后定义Car实体，这个指定了部分约束用在Default这个组，一部分约束用在CarCheck这个组，具体定义如下：

``` java
public class Car {
    @NotNull
    private String manufacturer;

    @NotNull
    @Size(min = 2, max = 14)
    private String licensePlate;

    @Min(2)
    private int seatCount;

    @AssertTrue(
            message = "The car has to pass the vehicle inspection first",
            groups = CarChecks.class
    )
    private boolean passedVehicleInspection;

    @Valid
    private Driver driver;

    public Car(String manufacturer, String licencePlate, int seatCount) {
        this.manufacturer = manufacturer;
        this.licensePlate = licencePlate;
        this.seatCount = seatCount;
    }

    public boolean isPassedVehicleInspection() {
        return passedVehicleInspection;
    }

    public void setPassedVehicleInspection(boolean passedVehicleInspection) {
        this.passedVehicleInspection = passedVehicleInspection;
    }

    public Driver getDriver() {
        return driver;
    }

    public void setDriver(Driver driver) {
        this.driver = driver;
    }

    // getters and setters ...
}

public interface CarChecks {
}
```

这里对上面三个类不同约束的分组进行整理：

* Default : Person.name , Car.manufacturer,Car.licensePlate ，Car.seatCount
* DriverCheck: Driver.age,Driver.hasDrivingLicense
* CarCehck:  Car.passedVehicleInspection

下面演示如何使用分组校验：

``` java
// 校验默认分组，也就是Group
Car car = new Car( "Morris", "DD-AB-123", 2 );
Set<ConstraintViolation<Car>> constraintViolations = validator.validate( car );
assertEquals( 0, constraintViolations.size() );

// 校验CarCheck分组
constraintViolations = validator.validate( car, CarChecks.class );
assertEquals( 1, constraintViolations.size() );
assertEquals(
        "The car has to pass the vehicle inspection first",
        constraintViolations.iterator().next().getMessage()
);

// 设置让校验通过CarCheck分组
car.setPassedVehicleInspection( true );
assertEquals( 0, validator.validate( car, CarChecks.class ).size() );

// 校验DriverCheck分组
Driver john = new Driver( "John Doe" );
john.setAge( 18 );
car.setDriver( john );
constraintViolations = validator.validate( car, DriverChecks.class );
assertEquals( 1, constraintViolations.size() );
assertEquals(
        "You first have to pass the driving test",
        constraintViolations.iterator().next().getMessage()
);

// 设置让校验通过DriverCheck分组
john.passedDrivingTest( true );
assertEquals( 0, validator.validate( car, DriverChecks.class ).size() );

//校验所有的分组
assertEquals(
        0, validator.validate(
        car,
        Default.class,
        CarChecks.class,
        DriverChecks.class
).size()
);
```

在校验时没有指定group参数，则表示使用Default组内的约束来校验。

### Group inheritance

在上面的例子中，如果我们想要校验多个分组，必须把所有组类型传递到Validate()参数中。有时，一些组是包含另外一组的所约束，如果再按照上面那样一个个的指定，比较麻烦。这时就可以使用Group inheritance来简化。

下面的例子，我们定义了一个SuperCar类型，并定义RaceCarCheck组，RaceCarCheck继承了Default组，定义如下

``` java
public class SuperCar extends Car {

    @AssertTrue(
            message = "Race car must have a safety belt",
            groups = RaceCarChecks.class
    )
    private boolean safetyBelt;

    @NotNull
    private String manufacturer;

    @NotNull
    @Size(min = 2, max = 14)
    private String licensePlate;

    @Min(2)
    private int seatCount;

   public Car(String manufacturer, String licencePlate, int seatCount) {
        this.manufacturer = manufacturer;
        this.licensePlate = licencePlate;
        this.seatCount = seatCount;
    }

    // getters and setters ...

}
public interface RaceCarChecks extends Default {
}
```

校验方法定义如下

``` java
// 创建SuperCar，并校验默认分组，即Default
SuperCar superCar = new SuperCar( "Morris", "DD-AB-123", 1  );
assertEquals( "must be greater than or equal to 2", validator.validate( superCar ).iterator().next().getMessage() );

// 校验SuperCar，是否满足RaceCarChecks分组定义的约束，这里同时会校验默认约束
Set<ConstraintViolation<SuperCar>> constraintViolations = validator.validate( superCar, RaceCarChecks.class );

assertThat( constraintViolations ).extracting( "message" ).containsOnly(
        "Race car must have a safety belt",
        "must be greater than or equal to 2"
);
```

上面定义了俩个校验，第一个校验的是默认分组，第二校验RaceCarCheck分组，这里也会同时校验Default分组。

### 定义分组验证的顺序

有时，校验约束需要一个特定顺序，这个功能点是通过@GroupSequence这个注解来实现。

例子如下

``` java
@GroupSequence({ Default.class, CarChecks.class, DriverChecks.class })
public interface OrderedChecks {
}
```

校验的例子如下

```java
Car car = new Car( "Morris", "DD-AB-123", 2 );
car.setPassedVehicleInspection( true );

Driver john = new Driver( "John Doe" );
john.setAge( 18 );
john.passedDrivingTest( true );
car.setDriver( john );

assertEquals( 0, validator.validate( car, OrderedChecks.class ).size() );
```

校验就是讲这里定义分组校验顺序的注解传入到校验方法中即可。当执行校验的时候，会按照这个顺序来校验。这样做有一个好处是，Hibernate Validator遇到第一个违法约束市，就会直接抛出错误，加快校验。

### 重定义Default 分组

@GroupSequence出了定义校验分组的顺序，也可以重写Default分组包含的约束。使用方式是在校验的类上加上这个注解，并在其中包含Default需要包含哪些分组。
例子如下

```java
@GroupSequence({ RentalChecks.class, CarChecks.class, RentalCar.class })
public class RentalCar extends Car {
    @AssertFalse(message = "The car is currently rented out", groups = RentalChecks.class)
    private boolean rented;

    public RentalCar(String manufacturer, String licencePlate, int seatCount) {
        super( manufacturer, licencePlate, seatCount );
    }

    public boolean isRented() {
        return rented;
    }

    public void setRented(boolean rented) {
        this.rented = rented;
    }
}
public interface RentalChecks {
}
```

上面的例子定义，校验RentalChecks, CarChecks 和RentalCar这三个分组，通过校验Default就可以达到。

校验的例子如下

``` java
RentalCar rentalCar = new RentalCar( "Morris", "DD-AB-123", 2 );
rentalCar.setPassedVehicleInspection( true );
rentalCar.setRented( true );

Set<ConstraintViolation<RentalCar>> constraintViolations = validator.validate( rentalCar );

assertEquals( 1, constraintViolations.size() );
assertEquals(
        "Wrong message",
        "The car is currently rented out",
        constraintViolations.iterator().next().getMessage()
);

rentalCar.setRented( false );
constraintViolations = validator.validate( rentalCar );

assertEquals( 0, constraintViolations.size() );
```

这里有一点需要注意的是，覆盖Default分组包含的范围，只会在当前类中生效，不会传播到其它类上。

冲定义默认分组，出了使用上面的方式，还可以通过SPI的方式来实现。Hibernate Validator定义了一个DefaultGroupSequenceProvider接口，用于重写默认分组包含的内容，并通过@GroupSequenceProvider注解引入到相应的类上。
例子如下,定义一个新的DefaultGroupSequenceProvider

``` java
public class RentalCarGroupSequenceProvider
        implements DefaultGroupSequenceProvider<RentalCar> {

    @Override
    public List<Class<?>> getValidationGroups(RentalCar car) {
        List<Class<?>> defaultGroupSequence = new ArrayList<Class<?>>();
        defaultGroupSequence.add( RentalCar.class );

        if ( car != null && !car.isRented() ) {
            defaultGroupSequence.add( CarChecks.class );
        }

        return defaultGroupSequence;
    }
}
```

将这个Provider声明到相应类上，这样就会重写Default分组

``` java
@GroupSequenceProvider(RentalCarGroupSequenceProvider.class)
public class RentalCar extends Car {

    @AssertFalse(message = "The car is currently rented out", groups = RentalChecks.class)
    private boolean rented;

    public RentalCar(String manufacturer, String licencePlate, int seatCount) {
        super( manufacturer, licencePlate, seatCount );
    }

    public boolean isRented() {
        return rented;
    }

    public void setRented(boolean rented) {
        this.rented = rented;
    }
}
```

### Group conversion

如果校验某个分组和其它分组一起，出了可以使用@GroupSequence，也可以通过@ConvertGroup来实现，这个注解用于将某个分组转换成另外一个分组，说得有点抽象，看下面的例子。

``` java
public class Driver {

    @NotNull
    private String name;

    @Min(
            value = 18,
            message = "You have to be 18 to drive a car",
            groups = DriverChecks.class
    )
    public int age;

    @AssertTrue(
            message = "You first have to pass the driving test",
            groups = DriverChecks.class
    )
    public boolean hasDrivingLicense;

    public Driver(String name) {
        this.name = name;
    }

    public void passedDrivingTest(boolean b) {
        hasDrivingLicense = b;
    }

    public int getAge() {
        return age;
    }

    public void setAge(int age) {
        this.age = age;
    }

    // getters and setters ...
}
```

``` java
@GroupSequence({ CarChecks.class, Car.class })
public class Car {

    @NotNull
    private String manufacturer;

    @NotNull
    @Size(min = 2, max = 14)
    private String licensePlate;

    @Min(2)
    private int seatCount;

    @AssertTrue(
            message = "The car has to pass the vehicle inspection first",
            groups = CarChecks.class
    )
    private boolean passedVehicleInspection;

    @Valid
    @ConvertGroup(from = Default.class, to = DriverChecks.class)
    private Driver driver;

    public Car(String manufacturer, String licencePlate, int seatCount) {
        this.manufacturer = manufacturer;
        this.licensePlate = licencePlate;
        this.seatCount = seatCount;
    }

    public boolean isPassedVehicleInspection() {
        return passedVehicleInspection;
    }

    public void setPassedVehicleInspection(boolean passedVehicleInspection) {
        this.passedVehicleInspection = passedVehicleInspection;
    }

    public Driver getDriver() {
        return driver;
    }

    public void setDriver(Driver driver) {
        this.driver = driver;
    }

    // getters and setters ...
}
```

校验代码如下

```java
// create a car and validate. The Driver is still null and does not get validated
Car car = new Car( "VW", "USD-123", 4 );
car.setPassedVehicleInspection( true );
Set<ConstraintViolation<Car>> constraintViolations = validator.validate( car );
assertEquals( 0, constraintViolations.size() );

// create a driver who has not passed the driving test
Driver john = new Driver( "John Doe" );
john.setAge( 18 );

// now let's add a driver to the car
car.setDriver( john );
constraintViolations = validator.validate( car );
assertEquals( 1, constraintViolations.size() );
assertEquals(
        "The driver constraint should also be validated as part of the default group",
        constraintViolations.iterator().next().getMessage(),
        "You first have to pass the driving test"
);
```

从上面可以看到，校验程序只校验了默认分组，第一个和第二个校验的区别在于，Dirver是否有驾照。但是这里还是用的Default分组，由于使用@ConvertGroup将默认分组转换成DriverChecks分组，因此在校验的石油，DiverCheck就相当于默认分组，会被校验。

使用@ConvertGroup有以下三个要注意的点：

1. @ConvertGroup要和@Valid一起使用
2. @ConvertGroup中的from值不能有相同的值
3. from值不能引用一个group sequence

## 总结

上面已经将Hibernate Validator基本的使用进行了整理。主要就是掌握如何在Bean和方法上声明约束，以及在使用约束需要注意级联验证和约束继承俩个点。另外就是对约束进行校验，主要通过Validator和ExecutableValidator俩个接口中的方法对应Bean和方法上的约束进行校验。
