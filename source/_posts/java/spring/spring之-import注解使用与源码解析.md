---
layout: blog
title: spring之@import注解使用与源码解析
date: 2022-03-10 14:39:08
tags:
    - spring
    - java
categories: 
    - spring 
    - java
---

本篇文章记录对@Import注解学习的整个过程。首先文章会介绍@Import注解的使用，接着分析下spring是如何处理@Import注解，最后通过@EnableAsync来举例说明该类型注解实现的原理。

## 基本用法

大体上有三种用法

1. 引入其它Configuration
2. 初始化其它的bean
3. 个性化加载bean

下面依次介绍这三种的用法，首先定义几个类，方便后面的讲解

``` java
interface ServiceInterface {
    void test();
}                      
class ServiceA implements ServiceInterface {

    @Override
    public void test() {
        System.out.println("ServiceA");
    }
}

class ServiceB implements ServiceInterface {

    @Override
    public void test() {
        System.out.println("ServiceB");
    }
}
```

### 引入configuration

创建了俩个Config类，其中ConfigA通过@Import引入ConfigB，

```java
@Import(ConfigB.class)
@Configuration
class ConfigA {
    @Bean
    @ConditionalOnMissingBean
    public ServiceInterface getServiceA() {
        return new ServiceA();
    }
}

@Configuration
class ConfigB {
    @Bean
    @ConditionalOnMissingBean
    public ServiceInterface getServiceB() {
        return new ServiceB();
    }
}
```

同时这里也使用了ConditionalOnMissingBean注解，主要用于判断哪个bean先生成。

通过ConfigA创建AnnotationConfigApplicationContext，获取ServiceInterface，看是哪种实现：

``` java
public static void main(String[] args) {
    ApplicationContext ctx = new AnnotationConfigApplicationContext(ConfigA.class);
    ServiceInterface bean = ctx.getBean(ServiceInterface.class);
    bean.test();
}
```

输出为：ServiceB.证明@Import的优先于本身的的类定义加载。
<!-- more -->
### 直接初始化其他类的Bean

可以直接指定实体类，生成对应的bean。

```java
@Import(ServiceB.class)
@Configuration
class ConfigA {
    @Bean
    @ConditionalOnMissingBean
    public ServiceInterface getServiceA() {
        return new ServiceA();
    }
}
```

运行main方法，输出为：ServiceB.证明@Import的优先于本身的的类定义加载.

### 个性化加载bean

可以通过实现指定的接口，个性化的加载一些Bean。主要有俩中方式，一种是实现ImportSelector或DeferredImportSelector接口，这俩个可以指定需要加载Bean的Class name，另外一种是实现ImportBeanDefinitionRegistrar接口，可以更加个性化的创建bean。

I**mportSelector方式**

例子如下：

```java
class ServiceImportSelector implements ImportSelector {
    @Override
    public String[] selectImports(AnnotationMetadata importingClassMetadata) {
        //可以结合AnnotationMetadata进行动态处理
        return new String[]{"com.test.ConfigB"};
    }
}

@Import(ServiceImportSelector.class)
@Configuration
class ConfigA {
    @Bean
    @ConditionalOnMissingBean
    public ServiceInterface getServiceA() {
        return new ServiceA();
    }
}
```

指定实现ImportSelector的类，通过AnnotationMetadata里面的属性，动态加载类。AnnotationMetadata是Import注解所在的类属性（如果所在类是注解类，则延伸至应用这个注解类的非注解类为止）。实现selectImports方法，返回要加载的@Configuation或者具体Bean类的全限定名的String数组。

再次运行main方法，输出：ServiceB.

证明@Import的优先于本身的的类定义加载。

还可以实现DeferredImportSelector接口,这样selectImports返回的类就都是最后加载的，而不是像@Import注解那样，先加载。

**ImportBeanDefinitionRegistrar方式**

与ImportSelector用法与用途类似，但是如果我们想重定义Bean，例如动态注入属性，改变Bean的类型和Scope等等，就需要通过指定实现ImportBeanDefinitionRegistrar的类实现。例如：

定义ServiceC

```java
package com.test;
class ServiceC implements ServiceInterface {

    private final String name;

    ServiceC(String name) {
        this.name = name;
    }

    @Override
    public void test() {
        System.out.println(name);
    }
}
```

定义ServiceImportBeanDefinitionRegistrar动态注册ServiceC，修改EnableService

```java
package com.test;

@Retention(RetentionPolicy.RUNTIME)
@Documented
@Target(ElementType.TYPE)
@Import(ServiceImportBeanDefinitionRegistrar.class)
@interface EnableService {
    String name();
}

class ServiceImportBeanDefinitionRegistrar implements ImportBeanDefinitionRegistrar {
    @Override
    public void registerBeanDefinitions(AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {
        Map<String, Object> map = importingClassMetadata.getAnnotationAttributes(EnableService.class.getName(), true);
        String name = (String) map.get("name");
        BeanDefinitionBuilder beanDefinitionBuilder = BeanDefinitionBuilder.rootBeanDefinition(ServiceC.class)
                //增加构造参数
                .addConstructorArgValue(name);
        //注册Bean
        registry.registerBeanDefinition("serviceC", beanDefinitionBuilder.getBeanDefinition());
    }
}
```

并且根据后面的源代码解析可以知道，ImportBeanDefinitionRegistrar在 @Bean 注解之后加载，所以要修改ConfigA去掉其中被@ConditionalOnMissingBean注解的Bean，否则一定会生成ConfigA的ServiceInterface

```java
package com.test;
@EnableService(name = "TestServiceC")
@Configuration
class ConfigA {
}
```

之后运行main，输出：TestServiceC

## 源码解析

解析@Import注解是通过加载解析@Configuration注解的过程中来实现。这点其实不难理解，毕竟他们俩经常绑在一起使用。

在spring中，是通过`ConfigurationClassPostProcessor` 来实现configuration注解的解析。这个类实现`BeanDefinitionRegistryPostProcessor` 接口，它是`BeanFactoryPostProcessor` 的扩展。利用BeanDefinitionRegistryPostProcessor给容器中再额外添加一些组件，在标准初始化之后修改applicationContext的内部*`BeanDefinitionRegistry` 。因此我们从*`BeanDefinitionRegistryPostProcessor` 接口定义的方法开始，来分析是如何解析Configuration。

**postProcessBeanDefinitionRegistry**

```java
@Override
public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
    int registryId = System.identityHashCode(registry);
    if (this.registriesPostProcessed.contains(registryId)) {
        throw new IllegalStateException(
                "postProcessBeanDefinitionRegistry already called on this post-processor against " + registry);
    }
    if (this.factoriesPostProcessed.contains(registryId)) {
        throw new IllegalStateException(
                "postProcessBeanFactory already called on this post-processor against " + registry);
    }
    this.registriesPostProcessed.add(registryId);
    // 处理的核心方法
    processConfigBeanDefinitions(registry);
}
```

**processConfigBeanDefinitions**

```java
public void processConfigBeanDefinitions(BeanDefinitionRegistry registry) {
    // 存储所有Config类型的bean定义
    List<BeanDefinitionHolder> configCandidates = new ArrayList<>();
    // 存储在未处理Config之前的所有bean name
    String[] candidateNames = registry.getBeanDefinitionNames();

    // 获取所有的config类型的bean
    for (String beanName : candidateNames) {
        BeanDefinition beanDef = registry.getBeanDefinition(beanName);
        if (beanDef.getAttribute(ConfigurationClassUtils.CONFIGURATION_CLASS_ATTRIBUTE) != null) {
            if (logger.isDebugEnabled()) {
                logger.debug("Bean definition has already been processed as a configuration class: " + beanDef);
            }
        }
        else if (ConfigurationClassUtils.checkConfigurationClassCandidate(beanDef, this.metadataReaderFactory)) {
            configCandidates.add(new BeanDefinitionHolder(beanDef, beanName));
        }
    }

    // 空则直接返回
    if (configCandidates.isEmpty()) {
        return;
    }

    // 根据@Order来进行排序
    configCandidates.sort((bd1, bd2) -> {
        int i1 = ConfigurationClassUtils.getOrder(bd1.getBeanDefinition());
        int i2 = ConfigurationClassUtils.getOrder(bd2.getBeanDefinition());
        return Integer.compare(i1, i2);
    });

    // 获取beanName命名策略
    SingletonBeanRegistry sbr = null;
    if (registry instanceof SingletonBeanRegistry) {
        sbr = (SingletonBeanRegistry) registry;
        if (!this.localBeanNameGeneratorSet) {
            BeanNameGenerator generator = (BeanNameGenerator) sbr.getSingleton(
                    AnnotationConfigUtils.CONFIGURATION_BEAN_NAME_GENERATOR);
            if (generator != null) {
                this.componentScanBeanNameGenerator = generator;
                this.importBeanNameGenerator = generator;
            }
        }
    }

    if (this.environment == null) {
        this.environment = new StandardEnvironment();
    }

    // 创建解析@Configuration对象
    ConfigurationClassParser parser = new ConfigurationClassParser(
            this.metadataReaderFactory, this.problemReporter, this.environment,
            this.resourceLoader, this.componentScanBeanNameGenerator, registry);

    // 存储所有待解析的对象
    Set<BeanDefinitionHolder> candidates = new LinkedHashSet<>(configCandidates);
    // 存储已解析的对象
    Set<ConfigurationClass> alreadyParsed = new HashSet<>(configCandidates.size());
    do {
        StartupStep processConfig = this.applicationStartup.start("spring.context.config-classes.parse");
        // 执行解析
        parser.parse(candidates);
        parser.validate();

        Set<ConfigurationClass> configClasses = new LinkedHashSet<>(parser.getConfigurationClasses());
        configClasses.removeAll(alreadyParsed);

        // Read the model and create bean definitions based on its content
        if (this.reader == null) {
            this.reader = new ConfigurationClassBeanDefinitionReader(
                    registry, this.sourceExtractor, this.resourceLoader, this.environment,
                    this.importBeanNameGenerator, parser.getImportRegistry());
        }
        // 加载新的class，ImportBeanDefinitionRegistrar 是在这里进行处理
        this.reader.loadBeanDefinitions(configClasses);
        alreadyParsed.addAll(configClasses);
        processConfig.tag("classCount", () -> String.valueOf(configClasses.size())).end();

        candidates.clear();
        // 如果beanDefinition的数量发生了变化，重新筛选所有未解析的configuration类
        if (registry.getBeanDefinitionCount() > candidateNames.length) {
            String[] newCandidateNames = registry.getBeanDefinitionNames();
            Set<String> oldCandidateNames = new HashSet<>(Arrays.asList(candidateNames));
            Set<String> alreadyParsedClasses = new HashSet<>();
            for (ConfigurationClass configurationClass : alreadyParsed) {
                alreadyParsedClasses.add(configurationClass.getMetadata().getClassName());
            }
            for (String candidateName : newCandidateNames) {
                if (!oldCandidateNames.contains(candidateName)) {
                    BeanDefinition bd = registry.getBeanDefinition(candidateName);
                    if (ConfigurationClassUtils.checkConfigurationClassCandidate(bd, this.metadataReaderFactory) &&
                            !alreadyParsedClasses.contains(bd.getBeanClassName())) {
                        candidates.add(new BeanDefinitionHolder(bd, candidateName));
                    }
                }
            }
            candidateNames = newCandidateNames;
        }
    }
    while (!candidates.isEmpty());

    // Register the ImportRegistry as a bean in order to support ImportAware @Configuration classes
    if (sbr != null && !sbr.containsSingleton(IMPORT_REGISTRY_BEAN_NAME)) {
        sbr.registerSingleton(IMPORT_REGISTRY_BEAN_NAME, parser.getImportRegistry());
    }

    if (this.metadataReaderFactory instanceof CachingMetadataReaderFactory) {
        // Clear cache in externally provided MetadataReaderFactory; this is a no-op
        // for a shared cache since it'll be cleared by the ApplicationContext.
        ((CachingMetadataReaderFactory) this.metadataReaderFactory).clearCache();
    }
}
```

通过上面可以看出，核心的解析逻辑在ConfigurationClassParser.parser方法中

```java
public void parse(Set<BeanDefinitionHolder> configCandidates) {
    for (BeanDefinitionHolder holder : configCandidates) {
        BeanDefinition bd = holder.getBeanDefinition();
        try {
            if (bd instanceof AnnotatedBeanDefinition) {
                parse(((AnnotatedBeanDefinition) bd).getMetadata(), holder.getBeanName());
            }
            else if (bd instanceof AbstractBeanDefinition && ((AbstractBeanDefinition) bd).hasBeanClass()) {
                parse(((AbstractBeanDefinition) bd).getBeanClass(), holder.getBeanName());
            }
            else {
                parse(bd.getBeanClassName(), holder.getBeanName());
            }
        }
        catch (BeanDefinitionStoreException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanDefinitionStoreException(
                    "Failed to parse configuration class [" + bd.getBeanClassName() + "]", ex);
        }
    }
    // 解析DeferredImportSelector 类型的Import导入
    this.deferredImportSelectorHandler.process();
}
```

解析的逻辑最终都是调用processConfigurationClass方法，同时也可以看出，DeferredImportSelector引入的bean，会在Configuration处理之后进行加载。

```java
protected void processConfigurationClass(ConfigurationClass configClass, Predicate<String> filter) throws IOException {
    if (this.conditionEvaluator.shouldSkip(configClass.getMetadata(), ConfigurationPhase.PARSE_CONFIGURATION)) {
        return;
    }

    ConfigurationClass existingClass = this.configurationClasses.get(configClass);
    // 如果已经处理过并且是import或者内容类，则跳过不处理
    // 如果不是，则移除已处理的标记，重新处理
    if (existingClass != null) {
        if (configClass.isImported()) {
            if (existingClass.isImported()) {
                existingClass.mergeImportedBy(configClass);
            }
            return;
        }
        else {
            this.configurationClasses.remove(configClass);
            this.knownSuperclasses.values().removeIf(configClass::equals);
        }
    }

    // 处理Configuration以及父类
    SourceClass sourceClass = asSourceClass(configClass, filter);
    do {
        sourceClass = doProcessConfigurationClass(configClass, sourceClass, filter);
    }
    while (sourceClass != null);

    this.configurationClasses.put(configClass, configClass);
}
```

接着就到了真正处理import注解的地点
```java
protected final SourceClass doProcessConfigurationClass(
        ConfigurationClass configClass, SourceClass sourceClass, Predicate<String> filter)
        throws IOException {

    // 如果存在内部类，判断是否是Configuration类型，并进行解析
    if (configClass.getMetadata().isAnnotated(Component.class.getName())) {
        processMemberClasses(configClass, sourceClass, filter);
    }

    //处理@PropertySource注解
    for (AnnotationAttributes propertySource : AnnotationConfigUtils.attributesForRepeatable(
            sourceClass.getMetadata(), PropertySources.class,
            org.springframework.context.annotation.PropertySource.class)) {
        if (this.environment instanceof ConfigurableEnvironment) {
            processPropertySource(propertySource);
        }
        else {
            logger.info("Ignoring @PropertySource annotation on [" + sourceClass.getMetadata().getClassName() +
                    "]. Reason: Environment must implement ConfigurableEnvironment");
        }
    }

    // 处理@ComponentScan注解
    Set<AnnotationAttributes> componentScans = AnnotationConfigUtils.attributesForRepeatable(
            sourceClass.getMetadata(), ComponentScans.class, ComponentScan.class);
    if (!componentScans.isEmpty() &&
            !this.conditionEvaluator.shouldSkip(sourceClass.getMetadata(), ConfigurationPhase.REGISTER_BEAN)) {
        for (AnnotationAttributes componentScan : componentScans) {
            // 解析@ComponentScan并生成BeanDefinitions
            Set<BeanDefinitionHolder> scannedBeanDefinitions =
                    this.componentScanParser.parse(componentScan, sourceClass.getMetadata().getClassName());
            // 检查新解析的BeanDefinition是否有对应的Configuration，有则进行处理
            for (BeanDefinitionHolder holder : scannedBeanDefinitions) {
                BeanDefinition bdCand = holder.getBeanDefinition().getOriginatingBeanDefinition();
                if (bdCand == null) {
                    bdCand = holder.getBeanDefinition();
                }
                if (ConfigurationClassUtils.checkConfigurationClassCandidate(bdCand, this.metadataReaderFactory)) {
                    parse(bdCand.getBeanClassName(), holder.getBeanName());
                }
            }
        }
    }

    //处理@Import注解
    processImports(configClass, sourceClass, getImports(sourceClass), filter, true);

    // 处理@ImportResource注解
    AnnotationAttributes importResource =
            AnnotationConfigUtils.attributesFor(sourceClass.getMetadata(), ImportResource.class);
    if (importResource != null) {
        String[] resources = importResource.getStringArray("locations");
        Class<? extends BeanDefinitionReader> readerClass = importResource.getClass("reader");
        for (String resource : resources) {
            String resolvedResource = this.environment.resolveRequiredPlaceholders(resource);
            configClass.addImportedResource(resolvedResource, readerClass);
        }
    }

    // 处理@Bean方法
    Set<MethodMetadata> beanMethods = retrieveBeanMethodMetadata(sourceClass);
    for (MethodMetadata methodMetadata : beanMethods) {
        configClass.addBeanMethod(new BeanMethod(methodMetadata, configClass));
    }

    // 处理接口中default方法 
    processInterfaces(configClass, sourceClass);

    // 如果有父类，则递归进行处理
    if (sourceClass.getMetadata().hasSuperClass()) {
        String superclass = sourceClass.getMetadata().getSuperClassName();
        if (superclass != null && !superclass.startsWith("java") &&
                !this.knownSuperclasses.containsKey(superclass)) {
            this.knownSuperclasses.put(superclass, configClass);
            // Superclass found, return its annotation metadata and recurse
            return sourceClass.getSuperClass();
        }
    }

    //没有父类处理完成
    return null;
}
```

从上面可以看出，是先处理内部类，然后处理CompenScan注解，接着处理@Import注解，最后才处理内部的@Bean方法。这也解释了为什么在@Import中的Bean先生成。

**processImports**

```java
private void processImports(ConfigurationClass configClass, SourceClass currentSourceClass,
        Collection<SourceClass> importCandidates, Predicate<String> exclusionFilter,
        boolean checkForCircularImports) {

    if (importCandidates.isEmpty()) {
        return;
    }

    //判断是否有环
    if (checkForCircularImports && isChainedImportOnStack(configClass)) {
        this.problemReporter.error(new CircularImportProblem(configClass, this.importStack));
    }
    else {
        this.importStack.push(configClass);
        try {
            for (SourceClass candidate : importCandidates) {
                if (candidate.isAssignable(ImportSelector.class)) {
                    //如果是ImportSelector类型，则当做Import来处理
                    Class<?> candidateClass = candidate.loadClass();
                    ImportSelector selector = ParserStrategyUtils.instantiateClass(candidateClass, ImportSelector.class,
                            this.environment, this.resourceLoader, this.registry);
                    Predicate<String> selectorFilter = selector.getExclusionFilter();
                    if (selectorFilter != null) {
                        exclusionFilter = exclusionFilter.or(selectorFilter);
                    }
                    // 如果DeferredImportSelector，则暂存，放在后面处理
                    if (selector instanceof DeferredImportSelector) {
                        this.deferredImportSelectorHandler.handle(configClass, (DeferredImportSelector) selector);
                    }
                    else {
                        // 处理import
                        String[] importClassNames = selector.selectImports(currentSourceClass.getMetadata());
                        Collection<SourceClass> importSourceClasses = asSourceClasses(importClassNames, exclusionFilter);
                        processImports(configClass, currentSourceClass, importSourceClasses, exclusionFilter, false);
                    }
                }
                else if (candidate.isAssignable(ImportBeanDefinitionRegistrar.class)) {
                    //  ImportBeanDefinitionRegistrar类型，先存储，放在最后统一处理
                    Class<?> candidateClass = candidate.loadClass();
                    ImportBeanDefinitionRegistrar registrar =
                            ParserStrategyUtils.instantiateClass(candidateClass, ImportBeanDefinitionRegistrar.class,
                                    this.environment, this.resourceLoader, this.registry);
                    configClass.addImportBeanDefinitionRegistrar(registrar, currentSourceClass.getMetadata());
                }
                else {
                    // 不是 ImportSelector or ImportBeanDefinitionRegistrar当做@Configuration来处理
                    this.importStack.registerImport(
                            currentSourceClass.getMetadata(), candidate.getMetadata().getClassName());
                    processConfigurationClass(candidate.asConfigClass(configClass), exclusionFilter);
                }
            }
        }
        catch (BeanDefinitionStoreException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanDefinitionStoreException(
                    "Failed to process import candidates for configuration class [" +
                    configClass.getMetadata().getClassName() + "]", ex);
        }
        finally {
            this.importStack.pop();
        }
    }
}
```

<!-- 总结下整体的解析流程

1. 入口ConfigurationClassPostProcessor#postProcessBeanDefinitionRegistry
2. ConfigurationClassPostProcessor#processConfigBeanDefinitions获取所有的Configuration类，并解析
3.  -->

## EnableAsync解析

有了上面的解析，这个就比较好理解，@EnableAsync注解的定义如下
```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Import(AsyncConfigurationSelector.class)
public @interface EnableAsync {

}
```

通过@import引入AsyncConfigurationSelector，此类实现ImportSelector接口，注入开启Async需要的类。

## 参考

1. [Spring的BeanFactoryPostProcessor和BeanPostProcessor](https://blog.csdn.net/caihaijiang/article/details/35552859)
2. [Spring官网阅读系列（六）：容器的扩展点（BeanFactoryPostProcessor）](https://zhuanlan.zhihu.com/p/117538482)
3. [Spring全解系列 - @Import注解](https://zhuanlan.zhihu.com/p/147025312?spm=ata.21735953.0.0.17357524xFjF3V)
