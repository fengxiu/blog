---
title: Mysql是如何执行查询
tags:
  - 索引
categories:
  - 数据库
  - mysql
  - 读书笔记
abbrlink: 63372
date: 2022-04-11 14:04:42
updated: 2022-04-11 14:04:42
---
本篇文章会按照以下思路来对mysql查询的原理进行讲解，首先讲解mysql是如何在单表上执行查询，在此基础上，讲解多表查询的原理，也就是join时，mysql是如何执行查询的，最后讲解mysql是如何计算查询的成本。

为了方便讲解定义一张表，具体定义如下

```sql
CREATE TABLE single_table ( 
    id INT NOT NULL AUTO_INCREMENT, 
    key1 VARCHAR(100) , 
    key2 INT, 
    key3 VARCHAR(100) , 
    key-part1 VARCHAR (100) , 
    key-part2 VARCHAR (100) , 
    key-part3 VARCHAR(100) , 
    common_field VARCHAR(100) , 
    PRlMARY KEY (id) , 
    KEY idx_key1 (key1) , 
    UNlQUE uk_key2 (key2)，
    KEY idx_key3 (key3) , 
    KEY idx_key-part(key-part1, key-part2, key-part3) 
) Engine=InnoDB charset=utf8;
```

## 单表访问原理

在Mysql数据库中，我们平时所写的那些查询语句本质上是一种声明式的语法。只是告诉MySQL要获取的数据符合哪些规则，至于MySQL背地里是如何把查询结果搞出来的则是MySQL自己的事儿。设计MySQL的大叔把MySQ执行查询语句的方式称为访问方法或者访问类型。.同一个查询语句可以使用多种不同的访问方法来执行，虽然最后的查询结果都是一样的，但是不同的执行方式花费的时间成本可能差距甚大。下面来看下具体的范文方法，如果之前使用过explain命令的话，应该比较熟悉下面的方法。

### const

通过主键或者唯一二级索引列来定位某条记录的访问方法定义为const (意思是常数级别的，代价是可以忽略不计的) 。如果唯一索引由多列构成，则需要每一列都与常数值进行比较时才能使用const方法进行查询。如果唯一索引可以为NULL，由于NULL值可以有多条，这样的查询语句不算做const方法访问。

比如下面这俩条语句都是使用const方法来进行查询

```sql
SELECT * from single_table WHERE id =  1438;
select * from single_table where key2 = "test";
```

具体的查找过程如下：

1. 通过索引查找到对应的id值，如果查找的是主键，则不用执行第二步。
2. 在聚簇索引上找到对应id值的完整用户记录。

### ref

ref是搜索条件为二级索引列，并且与常数进行等值比较，形成的扫描区间为单点扫描区间采用二级索引来执行查询的访问方法。

比如下面这条语句

```sql
select * from single_table where key1="12"
```

具体的查找过程如下：

1. 通过索引查找对应的id值
2. 在聚簇索引上找到对应id值的完整用户记录

有以下俩点需要说明

1. 由于普通二级索引以及唯一索引都不限制NULL值的数量，所以对于`KEY IS NULL`这种查找语句，最好的情况是使用ref，而不会使用const
2. 对于索引列中包含多个列的二级索引来说，只要最左边连续的列是与常数进行等值进行比较，则就是ref查询

```sql
-- 下面三个是ref查询
SELECT  * from single_table WBERE key-part1 = 'god like'; 
SELECT * from single_table WHERE key-part1 = 'good like ' AND keY-part2 = ' legendary'; 
SELECT * FROM single_table WHERE key-part1 =  'good like' and key-part2 = ' legendary' AND 
key-part3 = 'penta kill' ;

-- 这个查询不属于ref查询
SELECT *  FROM single_table WHERE key-part1 = ' god like' AND key-part2 > 'legendary';
```

### ref_or_null

在ref的基础上，还要查找出所有的NULL值记录，这种叫做ref_or_null。具体的查找过程和上面的ref类似

例子如下

```sql
SELECT * from single_table WHERE key1 = ' abc' OR key1 is  NULL;
```

### range

range是使用索引执行查询时，对应的扫描区间为若干个单点扫描区间或者范围扫描区间的访问方法，仅含一个单点扫描间的方法不能
称为 range 访问方法，扫描区间为(-∞，+∞)的访问方法也不能称为range访问方法。

比如下面的例子

```sql
SELECT * FROM single_table WHERE key2 IN (1438 , 6328) OR (key2 >38 AND key2 <79);
```

### index

符合下面俩个条件的查询语句称之为index

1. 查询的列表全部包含在某一个联合索引中。
2. 搜索条件也包含在联合索引中

比如下面这个例子

```sql
SELECT key-part1,key-part2,keY-Part3 from single_table WHERE key-part2 = 'abc';
```

这样的原因是因为联合索引的记录要比聚簇索引的记录小，同时不用回表进行查询，整体的查询成本要比扫描聚簇索引小。

在Innodb存储引擎中，如果添加了`order by 主键`,也会被认为是index

### all

直接扫描全部记录的方式。

### 索引合并

mysql一般情况下只会为单个索引生成扫描区间，不过在特殊情况下，也可能会为多个索引生成扫描区间，这种使用多个索引来完成一次查询的方法叫做索引合并。目前有三种，分别是Intersection索引合并，Union索引合并和Sort-Union索引合并。

#### Intersection索引合并

查询多个索引的交集，及and操作，并且所有索引中的主键值都是按照主键值的顺序进行排列，则会进行Intersection索引合并查询，具体的查询过程如下

1. 先使用各个索引查询符合要求的主键id
2. 对查询的出来的主键取交集
3. 根据最后的id结果执行回表操作。

例子如下

```sql
-- 使用索引合并
SELECT *  FROM single_table from  key1='a' AND key3 = 'b';

-- 由于key1,筛选出来的主键id不是按照主键id进行排序，不能使用索引合并
SELECT * FROM single_table WHERE key1 > ' a ' AND key3 = 'b'
```

#### Union索引合并

查询多个索引的并集，及or操作，并且所有索引中的主键值都是按照主键值的顺序进行排列，则会进行Union索引合并 查询，具体的查询过程如下

1. 先使用各个索引查询符合要求的主键id
2. 对查询的出来的主键取并集
3. 根据最后的id结果执行回表操作。

#### Sort-Union索引合并

这是对上面的Union索引合并条件进一步放宽，不要求主键值按照顺序进行排列。会在使用索引进行查找的过程中，对主键id进行排列，具体的过程如下

1. 先使用各个索引查询符合要求的主键id并按顺序排列
2. 对查询的出来的主键取并集
3. 根据最后的id结果执行回表操作。

## 多表访问原理

对于Mysql支持的连接这里就不在进行介绍，直接介绍连接的查询过程，大体上分为以下俩步

1. 首先确定第一个需要查询的表，这个表称为驱动表。确定的依据是查询代价最小的表作为驱动表，下面会介绍如何评估查询的代价。对于外连接则是已经确定的，如果是内连接，则才需要进行选取。
2. 上一步每获取一条记录，都会到第二张表中查找匹配的记录。被匹配的表称其为被驱动表。

![](https://raw.githubusercontent.com/fengxiu/img/master/20220408150150.png)

如果有3个表进行连接，那么步骤2中得到的结果集就像是新的驱动表，然后第3个表就成为了被驱动表，然后重复上面的过程。

上面所介绍的都是查询到一条记录就会到连接的表中进行查找，如果按照这种方式进行查询，会导致大量的随机IO。因此Mysql采取了下面这种策略。提出了一个连接缓冲区(Join buffer)的概念,Join Buffer就是在执行连接查询前申请的一块固定大小的内存。先把若干条驱动表结果集中的记录装在这个Join Buffer 中，然后开始扫描被驱动表，每条被驱动表的记录一次性地与Join Buffer中的多条驱动表记录进行匹配.由于匹配的过程都是在内存中完成的，所以这样可以显著减少被驱动表的IO代价。查询过程如下图
![](https://raw.githubusercontent.com/fengxiu/img/master/20220411202223.png)

## 基于成本的优化

## 参考

1. Mysql是怎样运行的
