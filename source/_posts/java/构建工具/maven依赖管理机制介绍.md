---
categories:
  - java
  - 构建工具
title: maven依赖机制简介
abbrlink: d2073860
---
# maven依赖机制简介

本文主要是对maven官方文档[Introduction to the Dependency Mechanism](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html#introduction-to-the-dependency-mechanism)翻译与整理。其中加上了自己的一些理解。

依赖关系管理是Maven的一个核心特性。管理单个项目的依赖关系很容易。管理由数百个模块组成的多模块项目和应用程序的依赖关系是可能的。Maven在定义、创建和维护具有良好定义的ClassPath路径和Library版本的可复制构建方面有很大帮助。
<!-- more -->
## 依赖传递

Maven通过自动包含可传递的依赖项，避免了发现和指定依赖项所需的库的需要。举个例子，A依赖B，B依赖C，如果没有传递依赖特性，我们还需要在A的依赖项中加上C依赖。

这个特性是通过从指定的远程存储库中读取依赖项的项目文件来实现，也就是通过读取依赖项自身的pom文件来发现所需的依赖。通常，这些项目的所有依赖项都将在项目中使用，项目从其父项或从其依赖项继承的任何依赖项，等等。

同时并没有对依赖关系的层次大小进行限制，因此这很可能引发一个问题：循环依赖。

使用可传递的依赖项，包含的库数量可以快速增长到相当大。因此，还有一些附加功能可以限制包含哪些依赖项：

### 依赖调解（Dependency mediation）

依赖调解决定了当有多个依赖项版本冲突时，选择哪个版本来作为项目中的依赖项。

Maven选择“最近的定义（nearest definition）”。也就是说，它使用依赖关系树中与项目最接近的依赖项的版本。您可以通过在项目的POM中显式声明来保证版本。请注意，如果两个依赖关系版本在依赖树中处于同一深度，则第一个声明将获胜。(这个有待考证)

举个例子来说明nearest definition：

``` text
  A
  ├── B
  │   └── C
  │       └── D 2.0
  └── E
      └── D 1.0
```

上面项目A中，依赖B和E，然后B和E都依赖D，但是由于B->C->D的路径要比E->D的路径长，因此最终项目会选择D 1.0来作为项目的依赖。

如果你希望指定D 2.0来作为项目中的依赖，可以直接在项目中指定：

``` text
  A
  ├── B
  │    └── C
  │         └── D 2.0
  ├── E
  │   └── D 1.0
  │
  └── D 2.0  
```

### 依赖管理（Dependency management）

这允许项目作者直接指定在可传递的依赖项或未指定版本的依赖项中遇到的artifact的版本。在上一节的示例中，一个依赖项被直接添加到A中，即使A没有直接使用它。相反，A可以将D作为依赖项包含在其dependencyManagement节中，并直接控制在引用D时使用哪个版本的D。

### 依赖作用域（Dependency scope）

这允许您只包含适合当前构建阶段的依赖项。下面将对此进行更详细的描述。

### 排除依赖（Excluded dependencies）

任何传递性的依赖都可以通过使用< exclusion>节点来排除。举个例子，A依赖于B并且B依赖于C，那么A可以标记C为排除在外的。

### 可选依赖（Optional dependencies）

任何传递性的依赖都可以通过使用< optional>节点来标记为可选的。举个例子，A依赖于B并且B依赖于C，现在B标记C为可选的，那么A可以不使用C。将可选依赖项看作“默认排除”。

虽然可传递依赖项可以隐式包含所需的依赖项，但显式地指定源代码直接使用的依赖关系是一个很好的实践。这个最佳实践证明了它的价值，特别是当项目的依赖项更改了它们自身的依赖项时。

例如，假设您的项目A指定了对另一个项目B的依赖关系，而项目B指定了对项目C的依赖关系。如果您直接使用项目C中的组件，而您没有在项目A中指定依赖项目C，则当项目B突然更新/删除其对项目C的依赖时，可能会导致项目A的compile失败。

直接指定依赖关系的另一个原因是它为您的项目提供了更好的文档：您可以通过阅读项目中的POM文件或通过执行mvn dependency:tree来了解更多的依赖信息。

Maven还提供了[dependency:analyze](https://maven.apache.org/plugins/maven-dependency-plugin/analyze-mojo.html)分析插件分析依赖关系的目标：它有助于使这个最佳实践更容易实现。

## 依赖作用域(dependency scope)

依赖作用域用于限制依赖项的传递性，并确定依赖项何时包含在类路径中。共有6个范围：

* compile：这是默认作用域，如果未指定任何范围，则使用该范围。编译依赖项在项目的所有类路径中都可用。此外，这些依赖关系会传播到依赖的项目。
* provided：这很像compile，但表明您希望JDK或容器在运行时提供依赖关系。例如，在构建web应用程序时，您需要将对Servlet API和相关JAVA EE APi的依赖设置为提供的范围，因为web容器提供了这些类。具有此作用域的依赖项会添加到用于编译和测试的类路径，但不会添加到运行时类路径。它不是传递的。
* runtime：此作用域表示编译不需要依赖项，但执行时需要依赖项。Maven在运行时和测试类路径中包含一个与此范围相关的依赖项，但编译时不包该依赖项。
* test：此作用域表示应用程序的正常使用不需要依赖项，并且仅在测试编译和执行阶段可用。此范围不可传递。通常这个范围用于测试库，比如JUnit和Mockito。如果这些库在单元测试（src/test/java）中使用，而不是在模型代码（src/main/java）中使用，那么它也用于非测试库，如apache commons IO。
* system：这个作用域与provided类似，只是您必须提供显式包含它的JAR。依赖总是可用的，不会在存储库中查找。
* import：只有< dependencyManagement>节点中pom类型的依赖项才支持此作用域。它指示依赖项将被指定POM的< dependencyManagement>节点中的有效依赖项列表替换。由于它们被替换，具有导入范围的依赖项实际上并不参与限制依赖项的可传递性。

## 依赖管理（dependency management）

依赖关系管理部分是一种集中依赖关系信息的机制。当您有一组从公共父级继承的项目时，可以将有关依赖关系的所有信息放在公共POM中，并在子POM中对依赖简单的引用。通过一些例子可以很好地说明这一机制。

project A

``` xml
<project>
  ...
  <dependencies>
    <dependency>
      <groupId>group-a</groupId>
      <artifactId>artifact-a</artifactId>
      <version>1.0</version>
      <exclusions>
        <exclusion>
          <groupId>group-c</groupId>
          <artifactId>excluded-artifact</artifactId>
        </exclusion>
      </exclusions>
    </dependency>
    <dependency>
      <groupId>group-a</groupId>
      <artifactId>artifact-b</artifactId>
      <version>1.0</version>
      <type>bar</type>
      <scope>runtime</scope>
    </dependency>
  </dependencies>
</project>
```

Project B

``` xml
<project>
  ...
  <dependencies>
    <dependency>
      <groupId>group-c</groupId>
      <artifactId>artifact-b</artifactId>
      <version>1.0</version>
      <type>war</type>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>group-a</groupId>
      <artifactId>artifact-b</artifactId>
      <version>1.0</version>
      <type>bar</type>
      <scope>runtime</scope>
    </dependency>
  </dependencies>
</project>
```

这两个示例pom共享一个公共依赖项，每个pom都有一个相同的依赖项。可以将此信息放入父POM中，如下所示：

``` xml
<project>
  ...
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>group-a</groupId>
        <artifactId>artifact-a</artifactId>
        <version>1.0</version>
 
        <exclusions>
          <exclusion>
            <groupId>group-c</groupId>
            <artifactId>excluded-artifact</artifactId>
          </exclusion>
        </exclusions>
 
      </dependency>
 
      <dependency>
        <groupId>group-c</groupId>
        <artifactId>artifact-b</artifactId>
        <version>1.0</version>
        <type>war</type>
        <scope>runtime</scope>
      </dependency>
 
      <dependency>
        <groupId>group-a</groupId>
        <artifactId>artifact-b</artifactId>
        <version>1.0</version>
        <type>bar</type>
        <scope>runtime</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>
</project>
```

然后两个子pom变得简单得多：

``` xml
<project>
  ...
  <dependencies>
    <dependency>
      <groupId>group-a</groupId>
      <artifactId>artifact-a</artifactId>
    </dependency>
 
    <dependency>
      <groupId>group-a</groupId>
      <artifactId>artifact-b</artifactId>
      <!-- This is not a jar dependency, so we must specify type. -->
      <type>bar</type>
    </dependency>
  </dependencies>
</project>
```

``` xml
<project>
  ...
  <dependencies>
    <dependency>
      <groupId>group-c</groupId>
      <artifactId>artifact-b</artifactId>
      <!-- This is not a jar dependency, so we must specify type. -->
      <type>war</type>
    </dependency>
 
    <dependency>
      <groupId>group-a</groupId>
      <artifactId>artifact-b</artifactId>
      <!-- This is not a jar dependency, so we must specify type. -->
      <type>bar</type>
    </dependency>
  </dependencies>
</project>
```

在上面，有两个依赖引用，我们必须指定< type/>元素。这是因为根据dependencyManagement节匹配依赖引用的最小信息集实际上是{groupId，artifactId，type，classifier}。在许多情况下，这些依赖项将引用没有classifier的jar构件。这使得我们可以将identity设置为{groupId，artifactId}，因为type字段的默认值是jar，而默认的classifier是null。

依赖关系管理部分的第二个非常重要的用途是控制可传递依赖项中使用的classifier的版本。以以下项目为例：

project A

``` xml
<project>
 <modelVersion>4.0.0</modelVersion>
 <groupId>maven</groupId>
 <artifactId>A</artifactId>
 <packaging>pom</packaging>
 <name>A</name>
 <version>1.0</version>
 <dependencyManagement>
   <dependencies>
     <dependency>
       <groupId>test</groupId>
       <artifactId>a</artifactId>
       <version>1.2</version>
     </dependency>
     <dependency>
       <groupId>test</groupId>
       <artifactId>b</artifactId>
       <version>1.0</version>
       <scope>compile</scope>
     </dependency>
     <dependency>
       <groupId>test</groupId>
       <artifactId>c</artifactId>
       <version>1.0</version>
       <scope>compile</scope>
     </dependency>
     <dependency>
       <groupId>test</groupId>
       <artifactId>d</artifactId>
       <version>1.2</version>
     </dependency>
   </dependencies>
 </dependencyManagement>
</project>
```

project B

``` xml
<project>
  <parent>
    <artifactId>A</artifactId>
    <groupId>maven</groupId>
    <version>1.0</version>
  </parent>
  <modelVersion>4.0.0</modelVersion>
  <groupId>maven</groupId>
  <artifactId>B</artifactId>
  <packaging>pom</packaging>
  <name>B</name>
  <version>1.0</version>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>test</groupId>
        <artifactId>d</artifactId>
        <version>1.0</version>
      </dependency>
    </dependencies>
  </dependencyManagement>
 
  <dependencies>
    <dependency>
      <groupId>test</groupId>
      <artifactId>a</artifactId>
      <version>1.0</version>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>test</groupId>
      <artifactId>c</artifactId>
      <scope>runtime</scope>
    </dependency>
  </dependencies>
</project>
```

当maven在project b上运行时，无论pom中指定的版本是什么，都将使用构件a、b、c和d的版本1.0。

* a和c都声明为项目的依赖项，因此使用版本1.0是由于依赖关系调解。两者都有运行时范围，因为它是直接指定的。
* b是在b的父级的依赖关系管理部分中定义的，由于依赖关系管理优先于可传递依赖项的依赖中介，因此如果在a或c的pom中引用了1.0版，则将选择它。b也将具有编译范围。
* 最后，由于d是在B的依赖项管理部分指定的，如果d是a或c的依赖项（或可传递的依赖项），则将选择1.0版—这同样是因为依赖关系管理优先于依赖项中介，而且还因为当前pom的声明优先于其父级的声明。

## import 管理

上一节中的示例描述了如何通过继承指定托管依赖项。但是，在较大的项目中，这可能是不可能完成的，因为项目只能从单个父级继承。为了适应这种情况，项目可以从其他项目导入托管依赖项。这是通过将pom artifact声明为具有“import”作用域的依赖项来实现的。

project B

``` xml
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>maven</groupId>
  <artifactId>B</artifactId>
  <packaging>pom</packaging>
  <name>B</name>
  <version>1.0</version>
 
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>maven</groupId>
        <artifactId>A</artifactId>
        <version>1.0</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
      <dependency>
        <groupId>test</groupId>
        <artifactId>d</artifactId>
        <version>1.0</version>
      </dependency>
    </dependencies>
  </dependencyManagement>
 
  <dependencies>
    <dependency>
      <groupId>test</groupId>
      <artifactId>a</artifactId>
      <version>1.0</version>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>test</groupId>
      <artifactId>c</artifactId>
      <scope>runtime</scope>
    </dependency>
  </dependencies>
</project>
```

假设A是上例中定义的pom，那么最终结果将是相同的。除了d之外，A的所有托管依赖项都将合并到B中，因为它是在pom中定义的。

project X

``` xml
<project>
 <modelVersion>4.0.0</modelVersion>
 <groupId>maven</groupId>
 <artifactId>Y</artifactId>
 <packaging>pom</packaging>
 <name>Y</name>
 <version>1.0</version>

 <dependencyManagement>
   <dependencies>
     <dependency>
       <groupId>test</groupId>
       <artifactId>a</artifactId>
       <version>1.2</version>
     </dependency>
     <dependency>
       <groupId>test</groupId>
       <artifactId>c</artifactId>
       <version>1.0</version>
       <scope>compile</scope>
     </dependency>
   </dependencies>
 </dependencyManagement>
</project>
```

project Z

``` xml
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>maven</groupId>
  <artifactId>Z</artifactId>
  <packaging>pom</packaging>
  <name>Z</name>
  <version>1.0</version>
 
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>maven</groupId>
        <artifactId>X</artifactId>
        <version>1.0</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
      <dependency>
        <groupId>maven</groupId>
        <artifactId>Y</artifactId>
        <version>1.0</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>
</project>
```

在上面的示例中，Z从X和Y导入托管依赖项。但是，X和Y都包含依赖项a。在这里，将使用a的版本1.1，因为首先声明X，而Z的dependencyManagement中没有声明a。

这个处理过程是递归的。例如，如果X导入另一个pom Q，当Z被处理时，Q的所有托管依赖项都是在X中定义的。

在多项目构建定义相关依赖的artifact库时，import通常是最有效的。一个项目使用这些库中的一个或多个artifact是相当常见的。然而，有时项目中使用artifact版本与依赖中分布的版本保持同步是很困难的。下面的模式说明了如何创建“bill of materials”（BOM）供其他项目使用。

根项目（The project of root）是bom pom。它定义了将在库中创建的所有artifact的版本。其他希望使用该库的项目应该将这个pom导入其pom的dependencyManagement部分。

``` xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.test</groupId>
  <artifactId>bom</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>
  <properties>
    <project1Version>1.0.0</project1Version>
    <project2Version>1.0.0</project2Version>
  </properties>
 
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>com.test</groupId>
        <artifactId>project1</artifactId>
        <version>${project1Version}</version>
      </dependency>
      <dependency>
        <groupId>com.test</groupId>
        <artifactId>project2</artifactId>
        <version>${project2Version}</version>
      </dependency>
    </dependencies>
  </dependencyManagement>
 
  <modules>
    <module>parent</module>
  </modules>
</project>
``` 

父子项目将BOM pom作为其父项目。这是一个普通的多项目pom。

``` xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.test</groupId>
    <version>1.0.0</version>
    <artifactId>bom</artifactId>
  </parent>
 
  <groupId>com.test</groupId>
  <artifactId>parent</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>
 
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>log4j</groupId>
        <artifactId>log4j</artifactId>
        <version>1.2.12</version>
      </dependency>
      <dependency>
        <groupId>commons-logging</groupId>
        <artifactId>commons-logging</artifactId>
        <version>1.1.1</version>
      </dependency>
    </dependencies>
  </dependencyManagement>
  <modules>
    <module>project1</module>
    <module>project2</module>
  </modules>
</project>

```

接下来是实际项目的pom

``` xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.test</groupId>
    <version>1.0.0</version>
    <artifactId>parent</artifactId>
  </parent>
  <groupId>com.test</groupId>
  <artifactId>project1</artifactId>
  <version>${project1Version}</version>
  <packaging>jar</packaging>
 
  <dependencies>
    <dependency>
      <groupId>log4j</groupId>
      <artifactId>log4j</artifactId>
    </dependency>
  </dependencies>
</project>
```

``` xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.test</groupId>
    <version>1.0.0</version>
    <artifactId>parent</artifactId>
  </parent>
  <groupId>com.test</groupId>
  <artifactId>project2</artifactId>
  <version>${project2Version}</version>
  <packaging>jar</packaging>
 
  <dependencies>
    <dependency>
      <groupId>commons-logging</groupId>
      <artifactId>commons-logging</artifactId>
    </dependency>
  </dependencies>
</project>

```

下面的项目展示了如何在另一个项目中使用库，而不必指定依赖项目的版本。

``` xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.test</groupId>
  <artifactId>use</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
 
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>com.test</groupId>
        <artifactId>bom</artifactId>
        <version>1.0.0</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>com.test</groupId>
      <artifactId>project1</artifactId>
    </dependency>
    <dependency>
      <groupId>com.test</groupId>
      <artifactId>project2</artifactId>
    </dependency>
  </dependencies>
</project>
``` 

最后，在创建导入依赖项的项目时，请注意以下事项：

* 不要尝试导入在当前pom的子模块中定义的pom。尝试这样做将导致构建失败，因为它无法定位pom。
* 不要将导入pom的pom声明为目标pom的父级（或祖父母等）。无法解决循环性，将引发异常。
* 当引用其pom具有可传递依赖关系的构件时，项目需要将这些构件的版本指定为托管依赖项。不这样做将导致构建失败，因为artifact可能没有指定版本。（这在任何情况下都应该被视为最佳实践，因为它可以防止artifact的版本从一个版本更改到下一个版本）。

## system 依赖管理

重要提示：此选项已弃用。

与范围系统的依赖关系始终可用，并且不会在存储库中查找。它们通常用于告诉Maven JDK或VM提供的依赖关系。因此，系统依赖项对于解决对artifact的依赖性特别有用，这些工件现在由JDK提供，但以前可以单独下载。典型的例子是JDBC标准扩展或Java身份验证和授权服务（JAAS）。

``` xml
<project>
  ...
  <dependencies>
    <dependency>
      <groupId>javax.sql</groupId>
      <artifactId>jdbc-stdext</artifactId>
      <version>2.0</version>
      <scope>system</scope>
      <systemPath>${java.home}/lib/rt.jar</systemPath>
    </dependency>
  </dependencies>
  ...
</project>
```
