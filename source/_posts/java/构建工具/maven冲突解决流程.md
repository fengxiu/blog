---
categories:
  - java
  - 构建工具
title: maven冲突解决流程
abbrlink: afb2f833
---
# maven冲突解决流程

<!-- 
    mvn dependency 简介
    常见命令介绍
    错误处理
 -->

 当项目比较大且开发维护的时间比较长时，项目的Maven依赖管理也会变得越来越复杂，手动的去排除冲突或者错误已经变得很困难，同时由于开发人员的不规范行为，更一步加深maven的依赖冲突比较多。我也是最近在接手一个已经做了八年项目时才有很大的感悟，之前也没碰过这么久的项目，在自己对maven依赖冲突解决的过程中形成了以下的一些思考或者说技巧。
<!-- more -->
## mvn dependency简介

解决冲突肯定是要找一个好的工具，这里推介使用[Apache Maven Dependency Plugin](https://maven.apache.org/plugins/maven-dependency-plugin/index.html)，目前我也只发现了这个工具，如果你有好的工具可以@下我。

在解决冲突过程中，主要使用以下几个命令

* mvn dependency:analyze ：分析此项目的依赖项并确定哪些依赖项：used and declared; used and undeclared; unused and declared.
* mvn dependency:analyze-duplicate ：分析< dependencies/> 和< dependencyManagement/>中重复定义的部分
* mvn dependency:tree :显示项目依赖树
* mvn dependency:list 显示项目依赖列表

### 查看依赖树

通过上方的命令解析之后会构成依赖树，利用依赖树可以清楚看到依赖引入的传递路径

![tree](https://raw.githubusercontent.com/fengxiu/img/master/tree.png)

### 查看已解析的依赖

一层为顶层依赖，顶层依赖的依赖为二级依赖，以此类推

![list](https://raw.githubusercontent.com/fengxiu/img/master/list.png)

### 分析项目当前依赖

Used undeclared dependencies found

这个是指某些依赖的包在代码中有用到它的代码，但是它并不是直接的依赖（就是说没有在pom中直接声明），是通过引入传递下来的包

Unused declared dependencies found

这个是指我们在pom中声明了依赖，但是在实际代码中并没有用到这个包！也就是多余的包。 这个时候我们就可以把这个依赖从pom中剔除

## 冲突解决实战

首先使用 mvn dependency:analyze 命令，输出当前maven项目的分析日志，接下来就是排查问题。其实输出的分析日志中已将对问题有很清楚的概述，这里显示我遇到的一些问题。

### 依赖重复声明

这个主要是产生警告，不会对项目的构建，编译等产生影响。出现的警告日志如下

``` log
[WARNING] 'dependencies.dependency.(groupId:artifactId:type:classifier)' must be unique: one.util:streamex:jar -> version 0.7.0 vs (?) @ ${module_name} ${file_path}, line 819, column 21
```

上面日志已经说得很明白，其中module_name表示警告来源的module，file_path，pom文件对应的地址，可以去对应的文件搜索这个jar包，删除其中一个即可。

### 依赖配置项声明不完整

``` log
[WARNING] 'build.plugins.plugin.version' for org.apache.maven.plugins:maven-compiler-plugin is missing. @ line 1566, column 21
```

这个错误只要去对应的位置，查看定义的依赖项的声明是否完整，比如上面显示的错误是org.apache.maven.plugins:maven-compiler-plugin没有声明version版本号导致的警告。

上面的错误还有可能是因为，子module继承父module，但是父module定义的一些依赖管理项没有被dependencyManagement包裹住。

这里还有一点需要注意的是，在dependencyManagement中声明依赖，如果在dependencies中导入，默认type是jar，如果要导入其它type的j依赖，需要进行配置。

### transitive dependencies (if any) will not be available

这中错误出现的原因可能有很多，解决思路如下

首先重新执行产生这个错误的命令，但是需要加上 "-X"参数，也可以直接执行mvn -X dependency:analyze ，一般会详细的输出产生错误的原因，我遇到过这种情况，

``` log
[FATAL] Non-parseable POM ${user.home}/.m2/repository/org/jboss/arquillian/arquillian-bom/1.1.11.Final/arquillian-bom-1.1.11.Final.pom:”
```

这种情况直接删除对应的目录，重现下载这个包，一般能够解决。

### Used undeclared dependencies found 或者Unused declared dependencies found

这类主要是警告，一般是有的jar包声明了依赖但没有使用，有的是直接依赖了对应的jar包，但是没有声明。解决这个问题只需要去对应的pom文件中加上或者删除对应的jar包

``` log
[WARNING] Used undeclared dependencies found:
[WARNING]    commons-lang:commons-lang:jar:2.6:compile
[WARNING] Unused declared dependencies found:
[WARNING]    commons-logging:commons-logging:jar:99.0-does-not-exist:provided
[WARNING]    ch.qos.logback:logback-classic:jar:1.2.3:compile
[WARNING]    javax.servlet:javax.servlet-api:jar:3.1.0:provided
[WARNING]    log4j:log4j:jar:1.2.15:runtime
```

