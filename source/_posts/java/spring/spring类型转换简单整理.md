---
categories:
  - java
  - spring
author: zhangke
title: Spring类型转换整理
abbrlink: 22104
date: 2021-11-11 06:46:00
---
# Spring类型转换整理

<!-- 

https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#core-convert-ConversionService-API

https://blog.csdn.net/f641385712/article/details/90702928

https://juejin.im/post/6844903940484513806

1. BeanWrapperImpl 大致原理 https://juejin.im/post/6844904047070167054#heading-4
2. convert 包的基本使用
3. fromat的基本使用
 -->
 平常在使用Spring过程中，经常会用到类型转换，但一直没时间对这一块进行系统的整理。因此接下来会用几篇文章对这一块进行系统的整理。

大概的想法是下面俩篇：

1. Spring类型转换整理
2. BeanWrapper使用以及原理
3. DataBinder使用以及原理

这篇文章用于记录自己在学习Spring类型转换相关的内容，主要有以下三块。

 1. PropertyEditor：用于String到Object的类型转换
 2. Conver      ：用于Object到Object之间的转换
 3. Format      ：主要用于格式化，将对象转换成指定格式的字符串，比如Date和string之间的转换
<!-- more -->
## PropertyEditor

这个是Spring最早支持的不同类型对象之间的转换，兼容JavaBean规范。这里的不同类型指的是String到不同Object之间的转换。

### PropertyEditor SPI

通过java.beans.PropertyEditor包名可以看出，其本身并非Spring中定义的接口，它其实是Java Bean规范中所定义的一个接口，其设计初衷在于是用于完成GUI中的输入与对象属性之间的转换操作；Spring只是借用了PropertyEditor这个接口的定义与功能，来完成字符串与对象属性之间的转换。在Spring 3.0之前，在Spring整个体系中，所有完成字符串与其他数据类型转换操作都是由ProperyEditor接口来完成的。

Spring通过PropertyEditor作为其数据类型转换的基础架构，同时自己还定义了许多默认的ProrpertyEditor的实现,这些实现类都位于spring-beans这个模块中的propertyeditors包中。

这些内置的PropertyEditor会有部分在默认情况下就已经被加了到IOC容器中，而有些PropertyEditor在默认情况下并没有自动加入，需要用户手动进行配置，后面我们通过源码可以看到Spring默认所注册了哪些PropertyEditor。

### PropertyEditorSupport

由于PropertyEditor是一个类型转换的接口，其里面定义了很多与我们实际使用上无关的方法。如果我们想要使用PropertyEditor的话，我们通常只需要继承java.beans.PropertyEditorSupport这个类，并且重写其setAsText(String source)方法即可，通过它将输入的字符串转换成我们期望的数据类型。

Spring所提供的内置的PropertyEditor也都是继承PropertyEditorSupport来完成类型转换的。

下面展示下基本使用,这个例子展示了如何将String转换成Point类型

定义的辅助类如下

```java
import lombok.Data;
@Data
@Component
public class Circle {
    @Value("1;2")
    private Point point;
}

@Data
public class Point {
    int x, y;

}
```

上面给出两个非常简单的类，我们希望完成的是将输入字符串”1;2“,自动进行分割，然后转换成point的x和y属性。

下面我们自己定义PropertyEditor来完成数据的转换:

```java
/**
 * 自定义PropertyEditor,完成String到Point的转换
 */
public class PointEditor extends PropertyEditorSupport {
    @Override
    public void setAsText(String text) throws IllegalArgumentException {
        String[] splits = text.split(";");
        Point point = new Point();
        point.setX(Integer.parseInt(splits[0]));
        point.setY(Integer.parseInt(splits[1]));
        /*
         *需要将装换后的结果设置到Editor的value属性中，因为外部会通过getValue获取到转换的结果。
         */
        setValue(point);
    }
}
```

在完成ProperyEditor编写完成后，我们只需将其注册到IOC容器中就可以自动完成String到Point之间的转换，这里使用编程的方式来注册

```java
@Configuration
@ComponentScan(basePackages = {"club.fengxiu.vailidation.editor"})
public class AppConfig {

//    通过CustomEditorConfigurer这个BeanFactoryProcessor
//    来完成自定义的ProperyEditor到IOC容器的添加功能
    @Bean
    public CustomEditorConfigurer customEditorConfigurer() {
        CustomEditorConfigurer customEditorConfigurer = new CustomEditorConfigurer();
        PropertyEditorRegistrar propertyEditorRegistrar = new PropertyEditorRegistrar() {
            @Override
            public void registerCustomEditors(PropertyEditorRegistry registry) {
                registry.registerCustomEditor(String.class, new PointEditor());
            }
        };
        customEditorConfigurer.setPropertyEditorRegistrars(new PropertyEditorRegistrar[]{propertyEditorRegistrar});
        return customEditorConfigurer;
    }
}
```

当上面的注册完成后，就可以使用这个PropertyEditor，使用demo

```java
@Test
public void testAppConfig() {
    ApplicationContext context = new AnnotationConfigApplicationContext(AppConfig.class);
    Circle circle = context.getBean(Circle.class);
    System.out.println(circle);
}
```

上面的是用来自定义String到Object的类型转换，但是这么多的PropertyEditor是由谁来管理呢，下面将介绍Spring是如何来管理这么多自定义的PropertyEditor

### PropertyEditorRegistry

org.springframework.beans.PropertyEditorRegistry接口提供了对PropertyEditor注册以及查找功能，因此其主要提供是提供了对PropertyEditor的管理功能，首先来看看这个接口的描述:

```java
package org.springframework.beans;

import java.beans.PropertyEditor;

public interface PropertyEditorRegistry {

	void registerCustomEditor(Class<?> requiredType, PropertyEditor propertyEditor);

	void registerCustomEditor(Class<?> requiredType, String propertyPath, PropertyEditor propertyEditor);

	PropertyEditor findCustomEditor(Class<?> requiredType, String propertyPath);

}
```

从上面可以接口的定义，PropertyEditorRegistry这个接口的作用，下面我们来看看其具体的几个实现类。

### PropertyEditorRegistrySupport

由于PropertyEditorRegistry只是定义对PropertyEditor注册和查找的方法，其具体的核心实现类是org.springframework.beans.PropertyEditorRegistrySupport，真正对PropertyEditor管理的操作全部在该类中实现，下面来看看PropertyEditorRegistrySupport的源码，由于PropertyEditorRegistrySupport源码篇幅比较多，这里就采用截图来说明其实现：

![20200903104250](https://raw.githubusercontent.com/fengxiu/img/master/20200903104250.png)

通过上面的标注我们看到PropertyEditorSupport底层对于不同种类的PropertyEditor使用不同的Map来进行存储，下面我们看下它是如何进行注册的。

![20200903104722](https://raw.githubusercontent.com/fengxiu/img/master/20200903104722.png)

其注册的实现机制也并没有出人意料的地方，就是判断存储Classs与PropertyEditor之间映射关系的Map是否已经存在，如果不存在则先创建一个LinkedHashMap，如果有就直接进行存储映射关系。
前面我们提到过在IOC容器中默认就会内置一些PropertyEditor,通过createDefaultEditors()我们可以清楚地看到其默认所添加的PropertyEditor。

![20200903104806](https://raw.githubusercontent.com/fengxiu/img/master/20200903104806.png)

### PropertyEditorRegistrar

PropertyEditorRegistrar接口的定义如下：

```java
public interface PropertyEditorRegistrar {

	void registerCustomEditors(PropertyEditorRegistry registry);
}
```

从接口的描述上我们可以看到，PropertyEditorRegistrar的作用是将用户自定义的PropertyEditor注册到PropertyEditorRegistry中。通过其registerCustomEditors方法中的参数我们可以看到，其所接受的正是一个PropertyEditorRegistry，通过方法的参数将用户自定义的ProepertyEditor加入到PropertyEditorRegistry被其进行管理。
PropertyEditorRegistrar对于如果我们希望将一组相同的PropertyEditor应用在多个地方时是非常有用的 ( 比如希望将相同的一组PropertyEditor既应用在IOC容器中，同时又应用在Spring MVC的DataBinder中)，此时就可以先定义一个PropertyEditorRegistrar的实现类，来完成通用的ProepertyEditor注册操作，然后将PropertyEditorRegistrar作为一个ProeprtyEditor的集合设置到不同的地方，此时就可以做到代码复用。

相同的PropertyEditor需要在多处进行注册的原因是因为我们在IOC容器中通过CustomEditorConfigurer添加了自定义的PropertyEditor后，其并不会对SpringMVC中所使用的DataBinder而生效，因此需要再次进行注册，我们通过分析CustomEditorConfigurer可以在其注释说明中清楚地看到这点说明。

上面那个注册自定义的PointEditor，就是用自定义的PropertyEditorRegistrar来注册的。这里就不在做具体的补充。

### PropertyEditor的缺点分析

1.只能完成字符串到Java类型的转换，并不能完成任意类型之间的转换。
2.由于PropertyEditor是非线程安全，因此对于每一次的类型转换，都需要创建一个新的PropertyEdtitor，如果希望达到共享，那么底层会使用synchronized来对其进行并发地控制。

![20200903113527](https://raw.githubusercontent.com/fengxiu/img/master/20200903113527.png)

## convert

core.convert是在Spring3之后，引进的一个新的通用类型转换系统，主要用来替代前面说到的PropertyEditor。PropertyEditor主要用在String到Object类型的准换，但是在实际开发中还有需要Object到Obejct的类型转换。下面主要介绍Convert的基本使用。

### Converter SPI

这个接口的定义比较简单，在Spring中如果需要自定义类型转换，推介使用这个。

接口定义如下

``` java
package org.springframework.core.convert.converter;

public interface Converter<S, T> {

    T convert(S source);
}
```

下面是一个简单的String转换成Integer的例子

``` java
package org.springframework.core.convert.support;

final class StringToInteger implements Converter<String, Integer> {

    public Integer convert(String source) {
        return Integer.valueOf(source);
    }
}
```

从上面可以看出，如果使用这个自定一类型转换实现起来比较简单。在Spring中已经提供了一些基本类型之间的转换，主要在org.springframework.core.convert.support包下。

![convert](https://raw.githubusercontent.com/fengxiu/img/master/20200825111842.png)

### ConverterFactory

这个相对于上面来说比较复杂，主要用来转换一个类型到另一个继承体系类型。举个例子，如果需要String转成Enum以及他的子类，这时可以使用ConverFactory这个接口来定义类型转换。

接口定义如下

```java
package org.springframework.core.convert.converter;

public interface ConverterFactory<S, R> {

    <T extends R> Converter<S, T> getConverter(Class<T> targetType);
}
```

String转换成Enum的例子如下

``` java

public class StringToEnumConverterFactory implements ConverterFactory<String, Enum> {

    public <T extends Enum> Converter<String, T> getConverter(Class<T> targetType) {
        return new StringToEnumConverter(targetType);
    }

    private final class StringToEnumConverter<T extends Enum> implements Converter<String, T> {

        private Class<T> enumType;

        public StringToEnumConverter(Class<T> enumType) {
            this.enumType = enumType;
        }

        public T convert(String source) {
            return (T) Enum.valueOf(this.enumType, source.trim());
        }
    }
}
```

### GenericConverter

这个比之前的类型转换接口更加强大，可以在多种类型到多种类型之间转换。通常情况下会做一个标记，比如注解，或者在属性值上设置一个标记，用来判断转换成哪种类型。

接口定义如下

``` java
package org.springframework.core.convert.converter;
public interface GenericConverter {

    public Set<ConvertiblePair> getConvertibleTypes();

    Object convert(Object source, TypeDescriptor sourceType, TypeDescriptor targetType);
}
```

其中getConvertibleTypes用来表示当前类支持的source到target的转换类型组，convert(Object, TypeDescriptor, TypeDescriptor)，用来执行转换逻辑，其中TypeDescriptor用来帮助访问target和source对象的属性，并设置属性值。

下面是一个实现GenericConverter的例子，数组转成列表，ArrayToCollectionConverter

``` java
public class ArrayToCollectionConverter implements GenericConverter {


    @Override
    public Set<ConvertiblePair> getConvertibleTypes() {
        // 表示当前转换器支持数组到列表的转换
        return Collections.singleton(new ConvertiblePair(Object[].class, Collection.class));
    }


    @Override
    public Object convert(Object source, TypeDescriptor sourceType, TypeDescriptor targetType) {
        if (source == null) {
            return null;
        }

        int length = Array.getLength(source);
        TypeDescriptor elementDesc = targetType.getElementTypeDescriptor();
        // 创建一个Collection对象
        Collection<Object> target = CollectionFactory.createCollection(targetType.getType(),
                (elementDesc != null ? elementDesc.getType() : null), length);

        if (elementDesc == null) {
            for (int i = 0; i < length; i++) {
                Object sourceElement = Array.get(source, i);
                target.add(sourceElement);
            }
        }
        return target;
    }
}

```

### ConditionalGenericConverter

这个接口用来提供当满足某些条件时，才能够使用Convert。比如，当指定的注解出现，才能执行converter逻辑。此时就需要增加转换前的验证逻辑，即ConditionalConverter接口表示的意义。为了方便使用ConditionalGenericConverter，实现了GenericConverter 和ConditionalConverter俩个接口。

``` java
public interface ConditionalConverter {

    boolean matches(TypeDescriptor sourceType, TypeDescriptor targetType);
}

public interface ConditionalGenericConverter extends GenericConverter, ConditionalConverter {
}
```

这里看一个Spring中的实现例子，用来在一个实体的唯一标识符和实体引用之间转换，代码如下,下面的整体思路是，首先判断是否有对应的finder方法以及是否有对应的Conver，如果都有则执行转换。

``` java
final class IdToEntityConverter implements ConditionalGenericConverter {

	private final ConversionService conversionService;


	public IdToEntityConverter(ConversionService conversionService) {
		this.conversionService = conversionService;
	}


	@Override
	public Set<ConvertiblePair> getConvertibleTypes() {
		return Collections.singleton(new ConvertiblePair(Object.class, Object.class));
	}

	@Override
	public boolean matches(TypeDescriptor sourceType, TypeDescriptor targetType) {
		Method finder = getFinder(targetType.getType());
		return (finder != null &&
				this.conversionService.canConvert(sourceType, TypeDescriptor.valueOf(finder.getParameterTypes()[0])));
	}

	@Override
	public Object convert(Object source, TypeDescriptor sourceType, TypeDescriptor targetType) {
		if (source == null) {
			return null;
		}
		Method finder = getFinder(targetType.getType());
		Object id = this.conversionService.convert(
				source, sourceType, TypeDescriptor.valueOf(finder.getParameterTypes()[0]));
		return ReflectionUtils.invokeMethod(finder, source, id);
	}


	private Method getFinder(Class<?> entityClass) {
		String finderMethod = "find" + getEntityName(entityClass);
		Method[] methods;
		boolean localOnlyFiltered;
		try {
			methods = entityClass.getDeclaredMethods();
			localOnlyFiltered = true;
		}
		catch (SecurityException ex) {
			// Not allowed to access non-public methods...
			// Fallback: check locally declared public methods only.
			methods = entityClass.getMethods();
			localOnlyFiltered = false;
		}
		for (Method method : methods) {
			if (Modifier.isStatic(method.getModifiers()) && method.getName().equals(finderMethod) &&
					method.getParameterTypes().length == 1 && method.getReturnType().equals(entityClass) &&
					(localOnlyFiltered || method.getDeclaringClass().equals(entityClass))) {
				return method;
			}
		}
		return null;
	}

	private String getEntityName(Class<?> entityClass) {
		String shortName = ClassUtils.getShortName(entityClass);
		int lastDot = shortName.lastIndexOf('.');
		if (lastDot != -1) {
			return shortName.substring(lastDot + 1);
		}
		else {
			return shortName;
		}
	}

}
```

### ConversionService

ConversionService定义了一个统一的API，用于在运行时执行类型转换逻辑。转换器通常运行在以下外观接口。

``` java
package org.springframework.core.convert;

public interface ConversionService {

    boolean canConvert(Class<?> sourceType, Class<?> targetType);

    <T> T convert(Object source, Class<T> targetType);

    boolean canConvert(TypeDescriptor sourceType, TypeDescriptor targetType);

    Object convert(Object source, TypeDescriptor sourceType, TypeDescriptor targetType);

}
```

通常，ConversionService也会实现ConverterRegistry，用来提供注册自定义converters，然后ConversionServic在执行转换的时候，会委托对应的converters来执行转换。

### 配置ConversionService

ConversionService是无状态的，可以在多线程中使用，通常在应用启动的时候，会配置一个ConversionService。当应用中没有ConversionService，则会使用默认的PropertyEditor。

通过编程的方式可以按照下面这种方式来配置ConversionService，代码如下

``` java
@Configuration
public class AppConfig {
    @Bean
    public ConversionServiceFactoryBean  ConversionService(){
        return new ConversionServiceFactoryBean();
    }
}
```

如果需要注入一些自定义的Convert，则可以使用setConverters方法来注入。

在代码中使用ConversionService，可以通过自动注入的方式。代码如下

``` java
@Service
public class MyService {
  
  @Autowired
    ConversionService conversionService


    public void doIt() {
        this.conversionService.convert(...)
    }
}
```

在系统中，默认创建DefaultConversionService，这里面包含了需要spring自定义的Convert，方便使用。如果需要添加一些自定义的Convert来代替默认的，则可以通过addDefaultConverters方法来添加。

下面展示一个复杂的Collection之间的转换，List< Integer> 转成List< String>

``` java
DefaultConversionService cs = new DefaultConversionService();

List<Integer> input = ...
cs.convert(input,
    TypeDescriptor.forObject(input), // List<Integer> type descriptor
    TypeDescriptor.collection(List.class, TypeDescriptor.valueOf(String.class)));
```

## Feild Formatting

前面介绍的Convert，是用于通用类型的转换，在一些应用中，可能需要对返回给客户端的值进行格式化。这时就需要Formatter，这个是一种特殊的类型转换，主要是用来进行格式化使用。

比如java.util.Date 格式化成  Long，在SpringMVC中就是通过Formatter来做的。

### Formatter

接口定义如下

``` java
package org.springframework.format;

public interface Formatter<T> extends Printer<T>, Parser<T> {
}
```

Formatter继承了Printer和Parser接口，它们分别用来将String转换成Object和Object转换成String。

Printer用于Object格式化为String

``` java 
public interface Printer<T> {

    String print(T fieldValue, Locale locale);
}
```

Parser 用于将String转换为Object

``` java 
public interface Parser<T> {

    T parse(String clientValue, Locale locale) throws ParseException;
}
```

org.springframework.format下面提供了很多默认的Fromat，具体的类如下

![20200825180414](https://raw.githubusercontent.com/fengxiu/img/master/20200825180414.png)

下面是一个时间格式化的例子:

``` java 
public final class DateFormatter implements Formatter<Date> {

    private String pattern;

    public DateFormatter(String pattern) {
        this.pattern = pattern;
    }

    public String print(Date date, Locale locale) {
        if (date == null) {
            return "";
        }
        return getDateFormat(locale).format(date);
    }

    public Date parse(String formatted, Locale locale) throws ParseException {
        if (formatted.length() == 0) {
            return null;
        }
        return getDateFormat(locale).parse(formatted);
    }

    protected DateFormat getDateFormat(Locale locale) {
        DateFormat dateFormat = new SimpleDateFormat(this.pattern, locale);
        dateFormat.setLenient(false);
        return dateFormat;
    }
}

```

### 注解方式的Format

属性的格式化，可以通过配置属性类型或者注解，如果需要使用注解来标记Formatter，需要实现AnnotationFormatterFactory接口，定义如下

``` java
public interface AnnotationFormatterFactory<A extends Annotation> {

    Set<Class<?>> getFieldTypes();

    Printer<?> getPrinter(A annotation, Class<?> fieldType);

    Parser<?> getParser(A annotation, Class<?> fieldType);
}
```

其中泛型A是指这个Fromatter处理逻辑对应的注解，方法getFieldTypes用于返回这个注解可以在哪些类型上使用。getPrinter和getParser用来返回格式化和范格式化的对象。

下面是NumberFormatAnnotationFormatterFactory的例子

NumberFormat注解定义

``` java 
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.FIELD, ElementType.PARAMETER, ElementType.ANNOTATION_TYPE})
public @interface NumberFormat {

	Style style() default Style.DEFAULT;


	String pattern() default "";

	/**
	 * Common number format styles.
	 */
	enum Style {

		DEFAULT,

		NUMBER,

		PERCENT,

		CURRENCY
	}

}
```

注解对应的处理器如下

``` java
public final class NumberFormatAnnotationFormatterFactory
        implements AnnotationFormatterFactory<NumberFormat> {

    public Set<Class<?>> getFieldTypes() {
        return new HashSet<Class<?>>(asList(new Class<?>[] {
            Short.class, Integer.class, Long.class, Float.class,
            Double.class, BigDecimal.class, BigInteger.class }));
    }

    public Printer<Number> getPrinter(NumberFormat annotation, Class<?> fieldType) {
        return configureFormatterFrom(annotation, fieldType);
    }

    public Parser<Number> getParser(NumberFormat annotation, Class<?> fieldType) {
        return configureFormatterFrom(annotation, fieldType);
    }

    private Formatter<Number> configureFormatterFrom(NumberFormat annotation, Class<?> fieldType) {
        if (!annotation.pattern().isEmpty()) {
            return new NumberStyleFormatter(annotation.pattern());
        } else {
            Style style = annotation.style();
            if (style == Style.PERCENT) {
                return new PercentStyleFormatter();
            } else if (style == Style.CURRENCY) {
                return new CurrencyStyleFormatter();
            } else {
                return new NumberStyleFormatter();
            }
        }
    }
}
```

使用方式

``` java
public class MyModel {

    @NumberFormat(style=Style.CURRENCY)
    private BigDecimal decimal;
}
```

### FormatterRegistry

FormatterRegistry是用来注册formatters和converters。这个用来中心化管控所有使用的formatting。FormattingConversionService是一个实现了FormatterRegistry在大多数场景下使用。可以通过FormattingConversionServiceFactoryBean来注册FormattingConversionService，从而注册了FormatterRegistry。

FormatterRegistry 接口定义如下

``` java
public interface FormatterRegistry extends ConverterRegistry {

    void addFormatterForFieldType(Class<?> fieldType, Printer<?> printer, Parser<?> parser);

    void addFormatterForFieldType(Class<?> fieldType, Formatter<?> formatter);

    void addFormatterForFieldType(Formatter<?> formatter);

    void addFormatterForAnnotation(AnnotationFormatterFactory<?> factory);
}
```

### FormatterRegistrar

用来注册FormatterRegistry的接口，我们可以将属于某一个类别里面的多个converters 和formatters注册到FormatterRegistry,然后在将这个FormatterRegistry注册到FormatterRegistrar中。比如date类别的格式化，就可以组装成一个来使用。

接口逻辑如下

``` java
public interface FormatterRegistrar {
    void registerFormatters(FormatterRegistry registry);
}
```

### 配置一个全局Date和Time 格式

下面是使用编程的方式配置默认的时间格式，具体配置就是在ApplicationContex中修改默认的时间格式，代码如下：

```java
@Configuration
public class AppConfig {

    @Bean
    public FormattingConversionService conversionService() {
        DefaultFormattingConversionService conversionService = new DefaultFormattingConversionService();
        // Ensure @NumberFormat is still supported
        conversionService.addFormatterForFieldAnnotation(new NumberFormatAnnotationFormatterFactory());

        // Register JSR-310 date conversion with a specific global format
        DateTimeFormatterRegistrar dateTimeFormatterRegistrar = new DateTimeFormatterRegistrar();
        dateTimeFormatterRegistrar.setDateFormatter(DateTimeFormatter.ofPattern("yyyyMMdd"));
        dateTimeFormatterRegistrar.registerFormatters(conversionService);

        // Register date conversion with a specific global format
        DateFormatterRegistrar registrar = new DateFormatterRegistrar();
        registrar.setFormatter(new DateFormatter("yyyyMMdd"));
        registrar.registerFormatters(conversionService);


        return conversionService;

    }
}
```

具体使用方式

```java
@Component
public class DateFormat {

    @Autowired
    FormattingConversionService formattingConversionService;

    public void getDate(Date date) {
        String date1 = formattingConversionService.convert(date, String.class);
        System.out.println(date1);
    }
}
```

## 参考

1. [深入分析Spring中的类型转换与校验(1)](https://www.jianshu.com/p/e2baa8d87029)