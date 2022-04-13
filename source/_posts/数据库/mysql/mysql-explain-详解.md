---
title: mysql explain 详解
categories:
  - 数据库
  - mysql
tags:
  - mysql
abbrlink: dd6beb0a
date: 2019-03-26 19:57:28
---
在看《高性能mysql》这本书的时候，经常看到explain这个命令。所以希望总结一下这个命令的一些知识点。此外，我们为了能够在数据库运行过程中去优化，就会开启慢查询日志，而慢查询日志记录一些执行时间比较久的SQL语句，但是找出这些SQL语句并不意味着完事了。我们需要分析为什么这条sql执行的慢，也就是找出具体的原因。这时我们常常用到explain这个命令来查看一个这些SQL语句的执行计划，查看该SQL语句有没有使用上了索引，有没有做全表扫描，这都可以通过explain命令来查看。所以我们深入了解MySQL的基于开销的优化器，还可以获得很多可能被优化器考虑到的访问策略的细节，以及当运行SQL语句时哪种策略预计会被优化器采用。（QEP：sql生成一个执行计划query Execution plan）

首先我们看看这个命令输出的具体格式，然后分别的解释其中每列代表的意思,如果执行这条sql语句`explain  select * from film`,输出的内容如下：

| id  | select_type | table | type | possible_keys | key  | key_len | ref  | rows | filtered | Extras |
| --- | ----------- | ----- | ---- | ------------- | ---- | ------- | ---- | ---- | -------- | ------ |
| 1   | SIMPLE      | film  | ALL  | NULL          | NULL | NULL    | NULL | 1000 | 100      | NULL   |

以上就是explain命令打印出来的信息，先对这些字段进行一个简介，有个整体的感知，然后在分别详细介绍每一个字段

| 列名          | 描述                                                             |
| ------------- | ---------------------------------------------------------------- |
| id            | 在一个大的查询语句中，每个SELECT关键字都对应一个唯一的id         |
| select_type   | SELECT关键字对应的查询的类型                                     |
| table         | 表名                                                             |
| partitions    | 匹配的分区信息                                                   |
| type          | 针对单表的访问方法                                               |
| possible_keys | 可能使用到的索引                                                 |
| key           | 实际使用的索引                                                   |
| key_len       | 实时使用的索引长度                                               |
| ref           | 当使用索引列等值查询时，与索引列进行等值匹配的对象信息           |
| rows          | 预估的需要读取的记录条数                                         |
| filtered      | 针对预估的需要读取的记录，经过搜索条件过滤后剩余记录条数的百分比 |
| extra         | 一些额外信息                                                     |

<!-- more -->
## id

是SQL执行的顺序的标识,SQL从大到小的执行

 1. id相同时，执行顺序由上至下
 2. 如果是子查询，id的序号会递增，id值越大优先级越高，越先被执行
 3. id如果相同，可以认为是一组，从上往下顺序执行；在所有组中，id值越大，优先级越高，越先执行

另外也有可能id值为NULL，这种情况表示的是对多个结果进行UNION并去重产生的结果。

## select_type

表示了查询的类型，具体的值如下表所示

![select_type](https://raw.githubusercontent.com/fengxiu/img/master/20220413103943.png)

- **SIMPLE**：表示此查询不包含 UNION 查询或子查询,也就是简单的select语句。
- **PRIMARY** 对于包含UNION、UNION ALL或者子查询的大查询来说，它是由几个小查询组成，其中最左边那个查询的select_type值及时PRIMARY。
- **UNION**：对于包含UNION或者UNION ALL的大查询来说，它是由几个小查询组成的，其中除了最左边的那个小查询以外，其余的小查询都是UNION
- **DEPENDENT SUBQUERY** ：如果包含子查询的查询语句不能转为对应的半连接形式，并且该子查询被查询优化器转换为相关子查询的形式。同时这种子查询可能会被执行多次。
- **UNION RESULT** Mysql选择使用临时表来完成UNION查询的去重工作，针对该临时表的查询的select_type就是UNION RESULT。
- **SUBQUERY** 如果包含子查询的查询语句不能转换为对应的半连接形式，并且改子查询是不相关子查询，而且查询优化器决定采用将改子查询物化的方案来执行改子查询时，该查询对应的类型就是SUBQUERY。这种查询只会被执行一次。
- **DEPENDENT UNION**: 在包含UNION或者UNION ALL的大查询中，如果各个小查询都依赖与外层查询，则处理最左边的那个小查询之外，其余小查询都是DEPENDENT UNION。
- **DERIVED** ：在包含派生表的查询中，如果以物化派生表的方式执行查询，则派生表对应的子查询的select_type就是DERIVED
- **MATERlALIZED**: 当查询优化器在执行包含子查询的语句时，选择将子查询物化之后与外层查询进行连接查询，该子查询对应的select_type属性就是MATERlALIZED。
- **UNCACHEABLE SUBQUERY**：一个子查询的结果不能被缓存，必须重新评估外链接的第一行。
- **UNCACHEABLE SUBQUERY**: 不常用

## table

显示当前查询的是哪张表，有时不是真实的表名字，会出现以下格式的值

* `<unionM,N>`:数据的来源是id为M和N的并集
* `<derivedN>`: 该行指的是id值为N的行的派生表结果。派生表可能来自例如 FROM 子句中的子查询
* `<subqueryN>`: 表示id为N的子查询物化后的结果表。

## partitions

表示当前查询使用到的分区是哪一个，如果是null则表示当前表不是分区表。

## type

表示Mysql执行这条语句是使用的访问方法，这边[Mysql是如何执行查询](https://fengxiu.tech/archives/63372.html)文章介绍mysql当前执行查询的类型，但是在这篇文章中，只介绍了单表的访问方法，还有一些其它的访问方法。下面对常使用的访问方法进行介绍。

- **system**: 当表中只有一条记录并且该表使用的存储引擎的统计数据是精确的，比如MyISAM，MEMORY，name对该表的访问方法就是system。
- **const**：表示根据主键或者唯一二级索引列与常数进行等值匹配
--**eq_ref**：执行链接查询时，如果被驱动表是通过主键或者不允许存储NULL值的唯一二级索引列等值匹配的方式进行访问，则对该被驱动表的访问方法就是eq_ref。
--**ref** 通过普通的二级索引列与常量进行等值匹配的方式来查询某个表时，对该表的访问方法就可能是ref
-- **fulltext** : 使用全文索引
-- **ref_or_null**：表示对普通索引进行等值匹配且该索引列的值也可以是NULL值，就是在ref的等值匹配基础上加上列是否为NULL的判断。
-- **index_merge**：索引合并，可以参考前面说的文章。
-- **unique_subquery**：类似于俩表连接中的被驱动表的eq_ref访问方法，只不过它针对的是一些包含IN子查询的查询语句，如果改查询优化器决定将IN子查询转换为EXISTS子查询，而且改子查询在转换之后可以使用主键或者不允许存储NULL值的唯一二级索引进行等值匹配，那么就成改子查询使用的方法是unique_subquery。
-- **index_subquery**：与上面类似，区别是在访问子查询中的表时使用的是普通索引。
-- **range** 使用索引获取某些单点扫描区间的记录
-- **index** 可以使用索引覆盖，但需要扫描全部的索引记录
 * **ALL**：全表扫描，MySQL将遍历全表以找到匹配的行

## possible_keys和key

possible_keys表示mysql在查询时，能够使用到的索引。 即使有些索引在 `possible_keys` 中出现, 但是并不表示此索引会真正地被MySQL使用到. MySQL 在查询时具体使用了哪些索引, 由 `key` 字段决定。

如果该列是NULL，则没有相关的索引。在这种情况下，可以通过检查WHERE子句看是否它引用某些列或适合索引的列来提高你的查询性能。如果是这样，创造一个适当的索引并且再次用EXPLAIN检查查询

key表示实际使用的索引。

## key_len

表示实际使用索引的长度，计算逻辑如下：

1. 该字段的最大长度，如果是某些变长字符串，则计算改列最大使用的长度。
2. 如果可以存储NULL值，长度加1
3. 如果该列是变长类型的列，长度加2

## ref

当访问方法是 const、er_ref、ref、 ref_or_null、 unique_subquery、index_subquery中的一个时， ref列展示的就是与索引列进行等值匹配的东西是啥。

## rows

在查询优化器决定使用全表扫描的方式对某个表执行查询时，执行计划的rows列就代表该表的估计行数。

## filtered

这个值表示预估最终获取符合条件行数的比例。比如rows是1000，这个值是10，则表示大概查询到符合条件的行数有1000*10% = 100。

## Extra

这个字段是用来说明一些额外信息，可以通过这个额外信息来更准确地理解Mysql到底如何执行给定的查询语句。这里介绍比较常用的，如果要知道其它的，可以参考mysql官方文档。

**No table used**：当查询语句中没有FROM子句时将会提示该额外信息。
**Impossible where**：当查询语句的where子句永远为FLASE时会提示该额外信息。
**No matching min/max row**：当查询列表处有MIN或者MAX聚集函数，但是并没有记录符合WHERE子句中的搜索条件时提示的信息

**Using index**：覆盖索引查询，表示查询在索引树中就可以查找所需数据，不用执行回表操作。

**Using index condition**：有些搜搜条件中虽然出现了索引列，但却不能充当边界条件来形成扫描区间，也就不能用力啊减少需要扫描的记录数量的提示信息。

**Using where**:列数据是从仅仅使用了索引中的信息而没有读取实际的行动的表返回的，这发生在对表的全部的请求列都是同一个索引的部分的时候，表示mysql服务器将在存储引擎检索行后再进行过滤。表示存储引擎返回的记录并不是所有的都满足查询条件，需要在server层进行过滤。查询条件中分为限制条件和检查条件，5.6之前，存储引擎只能根据限制条件扫描数据并返回，然后server层根据检查条件进行过滤再返回真正符合查询的数据。5.6.x之后支持ICP特性，可以把检查条件也下推到存储引擎层，不符合检查条件和限制条件的数据，直接不读取，这样就大大减少了存储引擎扫描的记录数量。extra列显示using index condition。

 **Using join buffer**：改值强调了在获取连接条件时没有使用索引，并且需要连接缓冲区来存储中间结果。如果出现了这个值，那应该注意，根据查询的具体情况可能需要添加索引来改进能。

**Select tables optimized away**：这个值意味着仅通过使用索引，优化器可能仅从聚合函数结果中返回一行

下面中using filesort和using temporary，这两项非常消耗性能，需要尽量优化掉。

 **Using temporary**：表示MySQL需要使用临时表来存储结果集，常见于排序和分组查询

**Using filesort**：MySQL中无法利用索引完成的排序操作称为“文件排序”,也就是mysql需要通过额外的排序操作，最好优化掉，因为这个操作一方面会使CPU资源消耗过大，另一方面可以内存不足，会使得排序的操作存储到磁盘文件上，增加了磁盘IO次数。

## 参考

1. [MySQL Explain详解](http://www.cnblogs.com/xuanzhi201111/p/4175635.html)
2. [MySQL 性能优化神器 Explain 使用分析](https://segmentfault.com/a/1190000008131735)
3. [Mysql优化之explain详解，基于5.7来解释](<https://www.jianshu.com/p/73f2c8448722>)
4. mysql是怎样运行的
5. [EXPLAIN Output Format](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html#explain_table)