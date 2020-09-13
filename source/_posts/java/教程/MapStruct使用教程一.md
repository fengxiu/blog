---
categories:
  - java
  - 教程
title: MapStruct使用教程一
abbrlink: bb156b86
---
# MapStruct使用教程一

<!-- 
    1. 是什么
    2. 相对于其它框架的优点
    3. 简单使用
       1. maven配置
       2. 简单demo
       3. 和lombok一起使用
       4. 定义mapper
       5. 获取mapper
 -->
在日常开发中，我们会定义多种不通的Javabean，比如DTO（Data Transfer Object：数据传输对象），DO（Data Object：数据库映射对象，与数据库一一映射），VO（View Object：显示层对象，通常是 Web 向模板渲染引擎层传输的对象）等等这些对象。在这些对象与对象之间转换通常是调对象的set和get方法进行复制，这种转换通常也是很无聊的操作，因此就需要有一个专门的工具来解决Javabean之间的转换问题，让我们从这种无聊的转换操作中解放出来。

MapStruct就是这样一个属性映射工具，用于解决上述对象之间转换问题。[MapStruct官网](https://mapstruct.org)。官网给出的MapStruct定义：MapStruct是一个Java注释处理器，用于生成类型安全的bean映射类。

我们要做的就是定义一个映射器接口，声明任何必需的映射方法。在编译的过程中，MapStruct会生成此接口的实现。该实现使用纯java方法调用的源对象和目标对象之间的映射。对比手写这些映射方法，MapStruct通过自动生成代码完成繁琐和手写容易出错的代码逻辑从而节省编码时间。遵循配置方法上的约定，MapStruct使用合理的默认值，但在配置或实现特殊行为时不加理会。

与动态映射框架相比，MapStruct具有以下优点：

1. 速度快：使用普通的方法代替反射
2. 编译时类型安全性 : 只能映射彼此的对象和属性，不会将商品实体意外映射到用户DTO等
3. 在build时期有明确的错误报告，主要有下面俩种
   1. 映射不完整，目标对象中有些属性没有被映射
   2. 映射不正确，找不到一个合适的映射方法或者类型转换方法
<!-- more -->
## 简单使用

### maven配置

通常在项目中，mapStruct和lombox会同时使用，具体的maven配置如下，如果只是用Mapstruct，只需将和Lombox有关的内容删除掉即可。

``` xml
    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
        <org.mapstruct.version>1.4.0.Beta3</org.mapstruct.version>
        <org.projectlombok.version>1.18.12</org.projectlombok.version>
    </properties>

    <dependencies>

        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
            <version>${org.mapstruct.version}</version>
        </dependency>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>${org.projectlombok.version}</version>
            <scope>provided</scope>
        </dependency>

        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
            <version>4.12</version>
        </dependency>
    </dependencies>

<!-- 配置lombok 和mapStruct注解处理器 -->
    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>3.8.1</version>
                    <configuration>
                        <source>1.8</source>
                        <target>1.8</target>
                        <annotationProcessorPaths>
                            <path>
                                <groupId>org.mapstruct</groupId>
                                <artifactId>mapstruct-processor</artifactId>
                                <version>${org.mapstruct.version}</version>
                            </path>
                            <path>
                                <groupId>org.projectlombok</groupId>
                                <artifactId>lombok</artifactId>
                                <version>${org.projectlombok.version}</version>
                            </path>
                        </annotationProcessorPaths>
                    </configuration>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
```

### 一个简单案例

定义Person实体

``` java
@Data
public class Person {
    private String name;
    private String lastName;
}
```

定义PersonDTO

```java
@Data
public class PersonDTO {
    private String firstName;
    private String lastName;
}
```

定义Person和PersonDTO之间的转换接口

``` java
@Mapper
public interface PersonMapper {

    PersonMapper INSTANCE = Mappers.getMapper(PersonMapper.class);

    @Mapping(source = "firstName",target = "name")
     Person personDTOToPerson(PersonDTO personDTO);
}
```

测试

```java
public class PersonMapperTest {

    @Test
    public void personDTOToPerson() {
        PersonMapper personMapper = PersonMapper.INSTANCE;
        PersonDTO personDTO = new PersonDTO();
        personDTO.setFirstName("zhang");
        personDTO.setLastName("ke");
        Person person = personMapper.personDTOToPerson(personDTO);
        Assert.assertEquals(person.getLastName(),personDTO.getLastName());
        Assert.assertEquals(person.getName(),personDTO.getFirstName());
    }
}
```

## 定义Mapper（Bean映射器）

在这一节，我们将学习如何定义一个Bean Mapper。

### 基本的映射

创建一个bean的转换器，只需要定义一个接口，并将需要的转换方法定义在接口中，然后使用org.mapstruct.Mapper注释对其进行注释。
比如上面的PersonMapper

``` java
@Mapper
public interface PersonMapper {

    PersonMapper INSTANCE = Mappers.getMapper(PersonMapper.class);

    @Mapping(source = "firstName",target = "name")
     Person personDTOToPerson(PersonDTO personDTO);
}
```

@Mapper注解作用是：在build-time时，MapStruct会自动生成一个实现PersonMapper接口的类。
接口中定义的方法，在自动生成时，默认会将source对象（比如PersonDTO）中所有可读的属性拷贝到target（比如Person）对象中相关的属性，转换规则主要有以下俩条：

1. 当target和source对象中属性名相同，则直接转换
2. 当target和source对象中属性名不同，名字的映射可以通过@Mapping注解来指定。比如上面firstName映射到name属性上。

其实上面PersonMapper通过MapStruct生成的类和我们自己写一个转换类是没有什么区别，上面PersonMapper自动生成的实现类如下：

```java
public class PersonMapperImpl implements PersonMapper {
    public PersonMapperImpl() {
    }

    public Person personDTOToPerson(PersonDTO personDTO) {
        if (personDTO == null) {
            return null;
        } else {
            Person person = new Person();
            person.setName(personDTO.getFirstName());
            person.setLastName(personDTO.getLastName());
            return person;
        }
    }
}
```

从上面可以看出，MapStruct的哲学是尽可能的生成看起来和手写的代码一样。因此，这也说明MapStruct映射对象属性使用的是getter/setter而不是反射。

正如上面例子这种显示的，在进行映射的时候，也会考虑通过@Mapping中指定的属性。如果指定的属性类型不同，MapStruct可能会通过隐式的类型转换，这个会在后面讲，或者通过调用/创建另外一个映射方法个，这个会在映射对象引用这一节说道。当一个bean的source和target属性是简单类型或者是Bean，才会创建一个新的映射方法，比如属性不能是Collection或者Map类型的属性。至于集合类型的映射将在后面讲。

MapStruct映射target和source的所有公共属性。这包括在父类型上声明的属性。

### 在Mapper中自定义方法

当俩种类型的映射不能通过MapStruct自动生成，我们需要自定义一些方法。自定义方法的方式主要有以下俩种。

1. 如果其他Mapper中已经有此方法，可以在@Mapper(uses=XXXMapper.class)来调用自定义的方法，这样可以方法重用。这个后面会说。<!-- TODO：加入超链接--->
2. java8或者更新的版本，可以直接在Mapper接口中添加default方法。当参数和返回值类型匹配，则生成的代码会自动调用这个方法。

例子如下

``` java
@Mapper
public interface CarMapper {

    @Mapping(...)
    ...
    CarDto carToCarDto(Car car);

    default PersonDto personToPersonDto(Person person) {
        //hand-written mapping logic
    }
}
```

在MapStruct自动生成代码，需要将Person转换成PersonDTO对象时，就会直接调用default方法。
也可以使用抽象类来定义，比如上面的例子使用抽象类定义如下

``` java
@Mapper
public abstract class CarMapper {

    @Mapping(...)
    ...
    public abstract CarDto carToCarDto(Car car);

    public PersonDto personToPersonDto(Person person) {
        //hand-written mapping logic
    }
}
```

### 多个source参数的映射方法

MapStruct也支持带有多个source参数的映射方法。这个在将多个bean合并成一个bean的时候非常有用。
例子如下：

``` java
@Mapper
public interface AddressMapper {

    @Mapping(source = "person.description", target = "description")
    @Mapping(source = "address.houseNo", target = "houseNumber")
    DeliveryAddressDto personAndAddressToDeliveryAddressDto(Person person, Address address);
}
```

上面显示的就是将俩个source参数映射成一个target对象。和单个参数一样，属性映射也是通过名称。

如果多个source参数中的属性具有相同的名称，必须通过@Mapping指定哪个source里面的属性映射到target属性中。如果存在多个相同的属性，并且没有指定，则会报错。

MapStruct也支持直接引用一个source参数映射到target对象中。例子如下

``` java
@Mapper
public interface AddressMapper {

    @Mapping(source = "person.description", target = "description")
    @Mapping(source = "hn", target = "houseNumber")
    DeliveryAddressDto personAndAddressToDeliveryAddressDto(Person person, Integer hn);
}
```

上面的例子将hn直接映射到target的houseNumber属性上。

### 更新Bean实例

有时我们并不一定创建一个新的Bean，可能需要更新某一个实例。这种类型的映射我们可以通过在参数上增加一个@MappingTarget注解。例子如下：

``` java
@Mapper
public interface CarMapper {

    void updateCarFromDto(CarDto carDto, @MappingTarget Car car);
}
```

这个例子会把CarDto中的属性值更新的Car对象实例上。上面的例子我们也可以将void改成Car类型返回值。

对于Collection或者Map类型，默认会将集合中所有的值清空，然后使用相关source集合中的值来填充，即CollectionMappingStrategy.ACCESSOR_ONLY策略。另外也提供了CollectionMappingStrategy.ADDER_PREFERRED 或者 CollectionMappingStrategy.TARGET_IMMUTABLE。这些策略可以在@Mapper(collectionMappingStrategy=CollectionMappingStrategy.TARGET_IMMUTABLE)来指定。

### 使用builders

MapStruct也支持通过builders擦行间immutable类型映射。当MapStruct执行映射检测到这里有一个类型匹配的builder。这时通过BuilderProvider SPI提供。如果这里存在一个特定的类型，该builder将会被用于映射。

默认实现的BuilderProvider遵循以下规则：

* 该类型具有返回生成器的无参数公共静态生成器创建方法。例如Person有一个公共静态方法，它返回PersonBuilder。
* builder类型有一个无参数的公共方法（build method），它返回在我们的示例PersonBuilder有一个返回Person的方法。
* 如果有多个build方法，MapStruct将寻找一个名为build的方法，如果存在这样的方法，那么将使用这个方法，否则会产生编译错误。
* 可以在@BeanMapping、@Mapper或@mapperfonfig中使用@Builder来定义特定的构建方法
* 如果有多个构建器创建方法满足上述条件，那么将从DefaultBuilderProvider SPI抛出一个多个BuilderCreationMethodException。如果超过一个builderCreationMethodException MapStruct将在编译中写入警告，并且不使用任何生成器。
  
如果找到这样的类型，那么MapStruct将使用该类型执行到的映射（即，它将在该类型中查找setter）。生成映射的mapbuilder将生成该映射的代码。

下面是一个例子

``` java
public class Person {

    private final String name;

    protected Person(Person.Builder builder) {
        this.name = builder.name;
    }

    public static Person.Builder builder() {
        return new Person.Builder();
    }

    public static class Builder {

        private String name;

        public Builder name(String name) {
            this.name = name;
            return this;
        }

        public Person create() {
            return new Person( this );
        }
    }
}
```

Person Mapper 定义如下：

``` java
public interface PersonMapper {

    Person map(PersonDto dto);
}
```

下面是自动生成的PersonMapperImpl类

``` java
public class PersonMapperImpl implements PersonMapper {

    public Person map(PersonDto dto) {
        if (dto == null) {
            return null;
        }

        Person.Builder builder = Person.builder();

        builder.name( dto.getName() );

        return builder.create();
    }
}
```

这一块具体的可以看说明文档，[using builder](https://mapstruct.org/documentation/stable/reference/html/#mapping-with-builders)

## 检索映射器

当我们不使用DI框架，Mapper实例可以通过org.mapstruct.factory.Mappers。只需要调用getMapper方法，传递接口类型的mapper就可以获得MapStruct自动生成的Mapper

向前面的例子，我们可以定义INSTANCE属性用于调用方法。例如

``` java
@Mapper(componentModel = "default")
public interface CarMapper {

    CarMapper INSTANCE = Mappers.getMapper( CarMapper.class );

    CarDto carToCarDto(Car car);
}
```

通过MapStruct自动生成的mapper是无状态的和线程安全的，可以同时被若干个线程访问。

检索映射器主要有以下几种，支持的值包括：

* default:通过Mapper#getMapper（class）来获取实例
* cdi：生成的映射器是一个应用程序范围的CDI bean，可以通过@Inject进行检索
* spring：生成的映射器是一个单例范围的spring bean，可以通过@Autowired进行检索
* jsr330：生成的映射器用{@code@Named}注释，可以通过@Inject检索，例如使用Spring

这些值可以通过@Mapper(componentModel="")来指定，也可以在maven的配置参数里面指定。

### 注入策略

当使用DI注入策略模式时，可以选择field和constructor俩种注入方式。这个可以被@Mapper或者@MapperConfig注解来指定。

使用constructor注入的例子如下：

``` java
@Mapper(componentModel = "cdi", uses = EngineMapper.class, injectionStrategy = InjectionStrategy.CONSTRUCTOR)
public interface CarMapper {
    CarDto carToCarDto(Car car);
}
```

生成的映射器将注入uses属性中定义的所有类。当使用InjectionStrategy#CONSTRUCTOR，构造函数将具有适当的注解，而字段则没有。当使用njectionStrategy#FIELD，注解字段位于field本身。目前，默认的注入策略是field注入。建议使用构造函数注入来简化测试。
