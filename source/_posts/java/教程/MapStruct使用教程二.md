---
categories:
  - java
  - 教程
title: MapStruct使用教程二
tags:
  - DDD
abbrlink: 8095452f
date: 2020-09-13 01:08:00
---
# MapStruct使用教程二

<!--  
1. 数据类型转换
2. 转换集合类型
3. 复用配置
 -->

 上一篇文章已经见过定义mapper和检索mapper等内容，这一节继续探索MapStruct的使用，主要有以下三个部分，数据类型转换，重复使用Mapping配置，高级技巧内容。

## 数据类型转换

 source和target对象在进行属性映射时，并不一定总是类型相同的，比如int类型映射成Long类型。或者不通的类型之间映射。下面将介绍MapStruct是如何处理数据类型转换的。
<!-- more -->
### 隐式转换

当前隐式自动转换的主要有以下几种情况：

* 所有的java原始类型和各自的wrapper类型，比如int和Integer
* 所有的java原始number类型和wrapper类型，比如int和long，byte和Integer。这里有一点需要注意的是，如果从大的数据类型转换成晓得，将会导致精度损失。Mapper和maperconfig注释有一个方法typeConversionPolicy来控制警告/错误。由于向后兼容的原因，默认值为ReportingPolicy.IGNORE。
* 所有的java原始类型，包括他们的wrapper类型和String，比如int和String。字符串格式可以由java.text.DecimalFormat指定。
* enum和String
* 在大数类型之间(java.math.BigInteger, java.math.BigDecimal)和Java原始类型（包括它们的包装器）以及字符串。格式字符串java.text.DecimalFormat可以指定。
* 在JAXBElement< T >和T之间，List< JAXBElement< T>>和List< T>
* java.util.Calendar/java.util.Date，JAXB的XMLGregorianCalendar
* 双方java.util.Date/XMLGregorianCalendar还有绳子。格式字符串java.text.SimpleDateFormat可以通过dateFormat选项指定。

还有很多条，具体的可以看[Implicit type references](https://mapstruct.org/documentation/stable/reference/html/#implicit-type-conversions)
