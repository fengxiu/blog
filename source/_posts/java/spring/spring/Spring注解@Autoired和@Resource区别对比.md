---
categories:
  - java
  - spring
  - spring
title: Spring注解@Autoired和@Resource区别对比
abbrlink: d1a2b8ab
---
# Spring注解@Autoired和@Resource区别对比

<!-- 
    1. 简单介绍
    2. @Autowired具体使用
    3. @Resouece具体使用
    4. 俩者对比
    5. 扩展介绍，@Primary @Qualifiers
 -->

最近在做项目的时候，由于自己的不细心，导致了一个小错误，在进行bean定义的时候，出现了俩个Bean名字相同但类型不通的Bean，而在进行依赖注入的时候，我选用了@Resource作为注入属性的注解，倒置了项目启动不成功，经过查阅资料，发现是自己对于@Resource注解的使用理解不到位导致的，因此这里有必要对依赖注入使用的注解进行整理分析。

本文主要对@Resource和@Autowired俩个注解的用法，以及俩者的对比进行整理。并子啊最后对和它们搭配使用的@Qualifiers和@Primary进行整理。
<!-- more -->
<!-- more -->
## @Autowired

@Autowired注解是按照类型（byType）装配依赖对象，默认情况下它要求依赖对象必须存在，如果允许null值，可以设置它的required属性为false。如果我们想使用按照名称（byName）来装配，可以结合@Qualifier注解一起使用。(通过类型匹配找到多个candidate,在没有@Qualifier、@Primary注解的情况下，会使用对象名作为最后的fallback匹配)。
主要的使用方式有以下几种

1. @Autowired可以在构造函数上进行使用，例子如下

    ``` java
    public class MovieRecommender {

        private final CustomerPreferenceDao customerPreferenceDao;

        @Autowired
        public MovieRecommender(CustomerPreferenceDao customerPreferenceDao) {
            this.customerPreferenceDao = customerPreferenceDao;
        }

        // ...
    }
    ```

    这里有一点需要注意的是，如果Bean只要一个构造函数，可以省略@Autowired注解，spring容器任然会自动注入需要的Bean。如果有多个构造函数，并且没有默认构造函数或者被@Primary修饰的构造函数，则需要明确指定@Autowired注解。

2. @Autowired可以在任意函数上使用，例子如下

    ``` java
        public class SimpleMovieLister {

            private MovieFinder movieFinder;

            @Autowired
            public void setMovieFinder(MovieFinder movieFinder) {
                this.movieFinder = movieFinder;
            }

             private MovieCatalog movieCatalog;

            private CustomerPreferenceDao customerPreferenceDao;

            @Autowired
            public void prepare(MovieCatalog movieCatalog,
                    CustomerPreferenceDao customerPreferenceDao) {
                this.movieCatalog = movieCatalog;
                this.customerPreferenceDao = customerPreferenceDao;
            }
        }
    ```

3. @Autowired也可以在field上使用，并且可以和constructor混合使用，例子如下

    ``` java
        public class MovieRecommender {

            private final CustomerPreferenceDao customerPreferenceDao;

            @Autowired
            private MovieCatalog movieCatalog;

            @Autowired
            public MovieRecommender(CustomerPreferenceDao customerPreferenceDao) {
                this.customerPreferenceDao = customerPreferenceDao;
            }

            // ...
        }
    ```

4. @Autowired可以用在数组类型或者Collection类型上，设置Map类型也可以，但是Map的key必须是String类型

    ``` java
        public class MovieRecommender {

            @Autowired
            private MovieCatalog[] movieCatalogs;

            @Autowired
            private Set<MovieCatalog> movieCatalogs;

            @Autowired
            private Map<String, MovieCatalog> movieCatalogs;
        }
    ```

    当@Autowired使用在这里时，会将容器中所有匹配的类型全部注入到对应的数组，集合或者Map中。默认的排列顺序是这些Bean创建的顺序。如果想这些数组或者list中的Bean按照某个特定的顺序，需要在Bean定义的地点加上@Order或者@Priority注解，由于@Priority注解不能再方法上使用，但是等价于@Order加上@Primary俩个注解组合在方法上使使用。

    <!--  spring 容器加载构造函数的算法  https://docs.spring.io/spring/docs/5.2.8.RELEASE/spring-framework-reference/core.html#beans-autowired-annotation-constructor-resolution-->

    这里有一点需要注意的是，@Autowired, @Inject, @Value, and @Resource这几个类型的注解不能在BeanPostProcessor or BeanFactoryPostProcessor类型中使用，如果想在这些类型中使用，必须明确的用@Bean注解在类中的方法去注入。

## @Resource

这个并不是Spring自身的注解，是JSR-250中规定的注解，Spring支持了这个规范。

@Resource默认按照ByName自动注入，由J2EE提供，需要导入包javax.annotation.Resource。@Resource有两个重要的属性：name和type，而Spring将@Resource注解的name属性解析为bean的名字，而type属性则解析为bean的类型。所以，如果使用name属性，则使用byName的自动注入策略，而使用type属性时则使用byType自动注入策略。如果既不制定name也不制定type属性，这时将通过反射机制使用byName自动注入策略。

``` java
public class SimpleMovieLister {

    private MovieFinder movieFinder;

    @Resource(name="myMovieFinder") 
    public void setMovieFinder(MovieFinder movieFinder) {
        this.movieFinder = movieFinder;
    }
}
```

如果@Resource找不到指定的name属性对应的Bean，则会通过类型选择一个匹配的类型来进行自动注入

## @Resource 和@AutoWired 对比

@Resource装配顺序：

1. 如果同时指定了name和type，则从Spring上下文中找到唯一匹配的bean进行装配，找不到则抛出异常。

2. 如果指定了name，则从上下文中查找名称（id）匹配的bean进行装配，找不到则抛出异常。

3. 如果指定了type，则从上下文中找到类似匹配的唯一bean进行装配，找不到或是找到多个，都会抛出异常。

4. 如果既没有指定name，又没有指定type，则自动按照byName方式进行装配；如果没有匹配，则回退为一个匹配类型进行匹配，如果匹配则自动装配。

而@Autowired是按照byType自动注入，缺少了@Resource中按照Bean Id来匹配。

## @Primary

如果我们在容器中定义了多个相同类型的Bean，如果这时没有任何机制的话，Spring容器是不知道选择哪一个Bean注入到对应位置，因此会产生歧异。这时就可以通过@Primary来告诉容器，当注入对应类型的Bean时，选择@Primary注解的Bean。例子如下：

``` java
@Configuration
public class MovieConfiguration {

    @Bean
    @Primary
    public MovieCatalog firstMovieCatalog() { ... }

    @Bean
    public MovieCatalog secondMovieCatalog() { ... }

    // ...
}
```

在下面的MovieRecommender类中，会自动注入fistMovieCatalog方法创建的Bean

``` java
public class MovieRecommender {

    @Autowired
    private MovieCatalog movieCatalog;

    // ...
}
```

## @Qualifer

这个是通过Bean name来控制当多个候选Bean注入容器时，哪一个Bean应该注入。比如下面这个例子

``` java
public class MovieRecommender {

    @Autowired
    @Qualifier("main")
    private MovieCatalog movieCatalog;

    // ...
}
```

这个将会注入一个Bean name或者Id等于main的Bean，或者也可以在Bean定义的时候加上Qualifier，并设置value=main，这时默认会注入这个Bean。