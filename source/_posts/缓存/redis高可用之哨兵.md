---
title: redis高可用之哨兵
tags:
  - redis
categories:
  - 缓存
abbrlink: 20163
date: 2022-04-24 19:58:22
updated: 2022-04-24 19:58:22
---

Sentinel（哨岗、哨兵）是Redis的高可用性（high availability）解决方案：由一个或多个Sentinel实例（instance）组成的Sentinel系统（system）可以监视任意多个主服务器，以及这些主服务器属下的所有从服务器，并在被监视的主服务器进入下线状态时，自动将下线主服务器属下的某个从服务器升级为新的主服务器，然后由新的主服务器代替已下线的主服务器继续处理命令请求。


Redis的Sentinel系统可以用来管理多个Redis服务器，该系统可以执行以下四个任务：

监控：不断检查主服务器和从服务器是否正常运行。
通知：当被监控的某个redis服务器出现问题，Sentinel通过API脚本向管理员或者其他应用程序发出通知。
自动故障转移：当主节点不能正常工作时，Sentinel会开始一次自动的故障转移操作，它会将与失效主节点是主从关系的其中一个从节点升级为新的主节点，并且将其他的从节点指向新的主节点，这样人工干预就可以免了。
配置提供者：在Redis Sentinel模式下，客户端应用在初始化时连接的是Sentinel节点集合，从中获取主节点的信息。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425102901.png)

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425102919.png)

<!-- more -->

**部署哨兵前需要了解的基本知识**

* 需要至少三个Sentinel实例才能实现健壮的部署。
* 这三个Sentinel实例应该放在被认为以独立方式失败的计算机或虚拟机中。例如，在不同的可用性区域上执行不同的物理服务器或虚拟机。
* Sentinel+Redis分布式系统不保证在故障期间保留已确认的写操作，因为Redis使用异步复制。然而，有一些方法可以部署Sentinel，使窗口丢失写操作的时间限制在某些时刻，而还有其他不太安全的方法可以部署它。
* 客户端需要支持哨兵式。

## 完整步骤

Sentinel完整的流程大概分为以下几步，中间也会交替运行

* 获取主服务器信息
* 获取从服务器信息
* 监听主服务器和从服务器
* 检测主观下线
* 检测客观下线
* 选举领头Sentinel
* 故障转移

### 获取主服务器信息

Sentinel默认会以每十秒一次的频率，通过命令连接向被监视的主服务器发送INFO命令，并通过分析INFO命令的回复来获取主服务器的当前信息。

通过分析主服务器返回的INFO命令回复，Sentinel可以获取以下两方面的信息： 

* 一方面是关于主服务器本身的信息，包括run_id域记录的服务器运行ID，以及role域记录的服务器角色；
* 另一方面是关于主服务器属下所有从服务器的信息，每个从服务器都由一个"slave"字符串开头的行记录，每行的ip=域记录了从服务器的IP地址，而port=域则记录了从服务器的端口号。根据这些IP地址和端 口号，Sentinel无须用户提供从服务器的地址信息，就可以自动发现从服务器。

通过上面可以获取到master信息以及所有的从服务器信息

### 获取从服务器信息

当Sentinel发现主服务器有新的从服务器出现时，Sentinel除了会为这个新的从服务器创建相应的实例结构之外，Sentinel还会创建连接到从服务器的命令连接和订阅连接。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425105521.png)

在创建命令连接之后，Sentinel在默认情况下，会以每十秒一次的频率通过命令连接向从服务器发送INFO命令用于获取服务器信息。

### 监听主服务器和从服务器

通过上面俩步已经能够拿到master主服务器和slave从服务器的信息，接着这一步将对主从服务器进行监听。主要步骤如下：

**通过命令链接发送信息**
在默认情况下，Sentinel会以每两秒一次的频率，通过命令连接向所有被监视的主服务器和从服务器命令，这个命令主要包含Sentinel本身的信息以及master服务器的信息，发送的地点是`__sentinel__:hello`频道。

**接收来自主服务器和从服务器的频道信息**
当Sentinel与一个主服务器或者从服务器建立起订阅连接之后，Sentinel就会通过订阅连接，向服务器发送以下命令：`SUBSCRIBE __sentinel__:hello`

Sentinel对__sentinel__:hello频道的订阅会一直持续到Sentinel与服务器的连接断开为止。

这也就是说，对于每个与Sentinel连接的服务器，Sentinel既通过命 令连接向服务器的__sentinel__:hello频道发送信息，又通过订阅连接从 服务器的__sentinel__:hello频道接收信息，如图16-13所示。
![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425110658.png)

对于监视同一个服务器的多个Sentinel来说，一个Sentinel发送的信息会被其他Sentinel接收到，这些信息会被用于更新其他Sentinel对发送信息Sentinel的认知，也会被用于更新其他Sentinel对被监视服务器的认知。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425110948.png)

当一个Sentinel从__sentinel__:hello频道收到一条信息时，Sentinel会对这条信息进行分析，提取出信息中的SentinelIP地址、Sentinel端口 号、Sentinel运行ID等八个参数，并进行以下检查： 

* 如果信息中记录的Sentinel运行ID和接收信息的Sentinel的运行ID相同，那么说明这条信息是Sentinel自己发送的，Sentinel将丢弃这条信息，不做进一步处理。 
* 相反地，如果信息中记录的Sentinel运行ID和接收信息的Sentinel的运行ID不相同，那么说明这条信息是监视同一个服务器的其他Sentinel发来的，接收信息的Sentinel将根据信息中的各个参数，对相应主服务 器的实例结构进行更新。主要更新有俩方面
	- 提取主服务器信息，更新已保存的主服务器信息，如果发现新的主服务器，则执行获取主从服务器信息，并创建命令链接和订阅链接
	- 提取Sentinel信息，更新保存的Sentinel服务器，如果发现新的Sentinel服务器，则创建命令链接

从上面可以看出Sentinel之间也会建立链接

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425111601.png)

使用命令连接相连的各个Sentinel可以通过向其他Sentinel发送命令请求来进行信息交换，接下来将对Sentinel实现主观下线检测和客观下线检测的原理进行介绍，这两种检测都会使用Sentinel之间的命令连接来进行通信。


通过上面的三步，获取到所有的主从服务器并建立命令链接和订阅链接，同时也会建立Sentinel服务器之间的链接。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425111815.png)

**Sentinel之间不会创建订阅连接**

Sentinel在连接主服务器或者从服务器时，会同时创建命令连接和订阅连接，但是在连接其他Sentinel时，却只会创建命令连接，而不创建订阅连接。这是因为Sentinel需要通过接收主服务器或者从服务器发来的频道信息来发现未知的新Sentinel，所以才需要建立订阅连接，而相互已知的Sentinel只要使用命令连接来进行通信就足够了。

### 检测主观下线

在默认情况下，Sentinel会以每秒一次的频率向所有与它创建了命令连接的实例（包括主服务器、从服务器、其他Sentinel在内）发送PING命令，并通过实例返回的PING命令回复来判断实例是否在线。

实例对PING命令的回复可以分为以下两种情况：

* 有效回复：实例返回+PONG、-LOADING、-MASTERDOWN三种 回复的其中一种。 
* 无效回复：实例返回除+PONG、-LOADING、-MASTERDOWN三种回复之外的其他回复，或者在指定时限内没有返回任何回复。

Sentinel配置文件中的down-after-milliseconds选项指定了Sentinel判断实例进入主观下线所需的时间长度：如果一个实例在down-after-milliseconds毫秒内，连续向Sentinel返回无效回复，表示这个实例已经进入主观下线状态。

**主观下线时长选项的作用范围**：用户设置的down-after-milliseconds选项的值，不仅会被Sentinel用来判断主服务器的主观下线状态，还会被用于判断主服务器属下的所有从服务器，以及所有同样监视这个主服务器的其他Sentinel的主观下线状态。

**多个Sentinel设置的主观下线时长可能不同**：down-after-milliseconds选项另一个需要注意的地方是，对于监视同一个主服务器的多个Sentinel来说，这些Sentinel所设置的down-after-milliseconds选项的值也可能不同，因此，当一个Sentinel将主服务器判断为主观下线时，其他Sentinel可能仍然会认为主服务器处于在线状态。

### 检测客观下线

当Sentinel将一个主服务器判断为主观下线之后，为了确认这个主服务器是否真的下线了，它会向同样监视这一主服务器的其他Sentinel进行询问，看它们是否也认为主服务器已经进入了下线状态（可以是主观下线或者客观下线）。当Sentinel从其他Sentinel那里接收到足够数量的已下线判断之后，Sentinel就会将从服务器判定为客观下线，并对主服务器执行故障转移操作。

检测的步骤如下

1. 发送`SENTINEL is-master-down-by-addr`命令，询问其它Sentinel是否统一主服务器已下线
2. 接收`SENTINEL is-master-down-by-addr`命令，当接收到命令后，目标Sentinel会分析并取出 命令请求中包含的各个参数，并根据其中的主服务器IP和端口号，检查主服务器是否已下线，然后向源Sentinel返回一条是否主服务器已下线的回复信息。
3. 根据其他Sentinel发回的`SENTINEL is-master-down-by-addr`命令回复，Sentinel将统计其他Sentinel同意主服务器已下线的数量，当这一数量达到配置指定的判断客观下线所需的数量时，表示主服务器已经进入客观下线状态。

**客观下线状态的判断条件**：当认为主服务器已经进入下线状态的Sentinel的数量，超过Sentinel配置中设置的quorum参数的值，那么该Sentinel就会认为主服务器已经进入客观下线状态。

**不同Sentinel判断客观下线的条件可能不同**：对于监视同一个主服务器的多个Sentinel来说，它们将主服务器标判断为客观下线的条件可能也不同：当一个Sentinel将主服务器判断为客观下线时，其他Sentinel可能并不是那么认为的。


### 选举领头Sentinel

当一个主服务器被判断为客观下线时，监视这个下线主服务器的各个Sentinel会进行协商，选举出一个领头Sentinel，并由领头Sentinel对下线主服务器执行故障转移操作。

以下是Redis选举领头Sentinel的规则和方法： 

1. 所有在线的Sentinel都有被选为领头Sentinel的资格，换句话说，监视同一个主服务器的多个在线Sentinel中的任意一个都有可能成为领头Sentinel。
2. 每次进行领头Sentinel选举之后，不论选举是否成功，所有Sentinel 的配置纪元（configuration epoch）的值都会自增一次。配置纪元实际上 就是一个计数器，并没有什么特别的。 
3. 在一个配置纪元里面，所有Sentinel都有一次将某个Sentinel设置为局部领头Sentinel的机会，并且局部领头一旦设置，在这个配置纪元里面就不能再更改。 
4. 每个发现主服务器进入客观下线的Sentinel都会要求其他Sentinel将自己设置为局部领头Sentinel。
5. 当一个Sentinel（源Sentinel）向另一个Sentinel（目标Sentinel）发 送SENTINEL is-master-down-by-addr命令，并且命令中的runid参数不是\*符号而是源Sentinel的运行ID时，这表示源Sentinel要求目标Sentinel将前者设置为后者的局部领头Sentinel。 
6. Sentinel设置局部领头Sentinel的规则是先到先得：最先向目标Sentinel发送设置要求的源Sentinel将成为目标Sentinel的局部领头Sentinel，而之后接收到的所有设置要求都会被目标Sentinel拒绝。
7. 目标Sentinel在接收到`SENTINEL is-master-down-by-addr`命令之后，将向源Sentinel返回一条命令回复，回复中的leader_runid参数和leader_epoch参数分别记录了目标Sentinel的局部领头Sentinel的运行ID和配置纪元。
8. 源Sentinel在接收到目标Sentinel返回的命令回复之后，会检查回复中leader_epoch参数的值和自己的配置纪元是否相同，如果相同的话，那么源Sentinel继续取出回复中的leader_runid参数，如果leader_runid参数的值和源Sentinel的运行ID一致，那么表示目标Sentinel将源Sentinel设 置成了局部领头Sentinel。 
9. 如果有某个Sentinel被半数以上的Sentinel设置成了局部领头Sentinel，那么这个Sentinel成为领头Sentinel。举个例子，在一个由10个Sentinel组成的Sentinel系统里面，只要有大于等于10/2+1=6个Sentinel将某个Sentinel设置为局部领头Sentinel，那么被设置的那个Sentinel就会成 为领头Sentinel。 
10. 因为领头Sentinel的产生需要半数以上Sentinel的支持，并且每个Sentinel在每个配置纪元里面只能设置一次局部领头Sentinel，所以在一个配置纪元里面，只会出现一个领头Sentinel。 
11. 如果在给定时限内，没有一个Sentinel被选举为领头Sentinel，那么各个Sentinel将在一段时间之后再次进行选举，直到选出领头Sentinel为止。


### 故障转移

在选举产生出领头Sentinel之后，领头Sentinel将对已下线的主服务器执行故障转移操作，该操作包含以下三个步骤： 
1）在已下线主服务器属下的所有从服务器里面，挑选出一个从服务器，并将其转换为主服务器。 2）让已下线主服务器属下的所有从服务器改为复制新的主服务器。
3）将已下线主服务器设置为新的主服务器的从服务器，当这个旧的主服务器重新上线时，它就会成为新的主服务器的从服务器。

**选出新的主服务器**
故障转移操作第一步要做的就是在已下线主服务器属下的所有从服务器中，挑选出一个状态良好、数据完整的从服务器，然后向这个从服务器发送`SLAVEOF no one`命令，将这个从服务器转换为主服务器。

领头Sentinel会将已下线主服务器的所有从服务器保存到一个列表里面，然后按照以下规则，一项一项地对列表进行过滤： 

1. 删除列表中所有处于下线或者断线状态的从服务器，这可以保证列表中剩余的从服务器都是正常在线的。
2. 删除列表中所有最近五秒内没有回复过领头Sentinel的INFO命令的从服务器，这可以保证列表中剩余的从服务器都是最近成功 进行过通信的。 
3. 删除所有与已下线主服务器连接断开超过`down-after- milliseconds*10`毫秒的从服务器：down-after-milliseconds选项指定了判断主服务器下线所需的时间，而删除断开时长超过`down-after- milliseconds*10`毫秒的从服务器，则可以保证列表中剩余的从服务器都没有过早地与主服务器断开连接，换句话说，列表中剩余的从服务器保存的数据都是比较新的。

之后，领头Sentinel将根据从服务器的优先级，对列表中剩余的从服务器进行排序，并选出其中优先级最高的从服务器。

如果有多个具有相同最高优先级的从服务器，那么领头Sentinel将按照从服务器的复制偏移量，对具有相同最高优先级的 所有从服务器进行排序，并选出其中偏移量最大的从服务器（复制偏移量最大的从服务器就是保存着最新数据的从服务器）。

最后，如果有多个优先级最高、复制偏移量最大的从服务器，那么领头Sentinel将按照运行ID对这些从服务器进行排序，并选出其中运行ID最小的从服务器。

**修改从服务器的复制目标**
当新的主服务器出现之后，领头Sentinel下一步要做的就是，让已下线主服务器属下的所有从服务器去复制新的主服务器，这一动作可以 通过向从服务器发送SLAVEOF命令来实现。

**将旧的主服务器变为从服务器**
故障转移操作最后要做的是，将已下线的主服务器设置为新的主服务器的从服务器。

### 总结

通过上面已经了解每一步是做什么的，下面对上面的步骤做一个简短的总结

Sentinel经过一系列的数据交换，获取了所有的服务器信息以及Sentinel信息，构造出如下的网络

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425105521.png)

每个Sentinel节点都需要定期执行以下任务：每个Sentinel以每秒一次的频率，向它所知的主服务器、从服务器以及其他的Sentinel实例发送一个PING命令。（如上图）

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425114926.png)


2、如果一个实例距离最后一次有效回复PING命令的时间超过down-after-milliseconds所指定的值，那么这个实例会被Sentinel标记为主观下线。（如上图）

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425115104.png)

3、如果一个主服务器被标记为主观下线，那么正在监视这个服务器的所有Sentinel节点，要以每秒一次的频率确认主服务器的确进入了主观下线状态。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425115132.png)

4、如果一个主服务器被标记为主观下线，并且有足够数量的Sentinel（至少要达到配置文件指定的数量）在指定的时间范围内同意这一判断，那么这个主服务器被标记为客观下线。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425115147.png)

5、一般情况下，每个Sentinel会以每10秒一次的频率向它已知的所有主服务器和从服务器发送INFO命令，当一个主服务器被标记为客观下线时，Sentinel向下线主服务器的所有从服务器发送INFO命令的频率，会从10秒一次改为每秒一次。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425115202.png)

6、Sentinel和其他Sentinel协商客观下线的主节点的状态，如果处于SDOWN状态，则投票自动选出新的主节点，将剩余从节点指向新的主节点进行数据复制。

![](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425115216.png)

7、当没有足够数量的Sentinel同意主服务器下线时，主服务器的客观下线状态就会被移除。当主服务器重新向Sentinel的PING命令返回有效回复时，主服务器的主观下线状态就会被移除。

## 数据问题

Redis实现高可用，但实现期间可能产出一些风险：

* 主备切换的过程， 异步复制导致的数据丢失
* 脑裂导致的数据丢失
* 主备切换的过程，异步复制导致数据不一致

**数据丢失-主从异步复制**
因为master将数据复制给slave是异步实现的，在复制过程中，这可能存在master有部分数据还没复制到slave，master就宕机了，此时这些部分数据就丢失了。
总结：主库的数据还没有同步到从库，结果主库发生了故障，未同步的数据就丢失了。

**数据丢失-脑裂**
何为脑裂？当一个集群中的master恰好网络故障，导致与sentinal通信不上了，sentinal会认为master下线，且sentinal选举出一个slave作为新的master，此时就存在两个master了。
此时，可能存在client还没来得及切换到新的master，还继续写向旧master的数据，当master再次恢复的时候，会被作为一个slave挂到新的master上去，自己的数据将会清空，重新从新的master 复制数据，这样就会导致数据缺失。
总结：主库的数据还没有同步到从库，结果主库发生了故障，等从库升级为主库后，未同步的数据就丢失了。

**数据丢失解决方案**

数据丢失可以通过合理地配置参数 
min-slaves-to-write 和 min-slaves-max-lag 解决，比如

```
min-slaves-to-write 1
min-slaves-max-lag 10
```

如上两个配置：要求至少有1个 slave，数据复制和同步的延迟不能超过10秒，如果超过1个slave，数据复制和同步的延迟都超过了10秒钟，那么这个时候，maste 就不会再接收任何请求了。

数据不一致
在主从异步复制过程，当从库因为网络延迟或执行复杂度高命令阻塞导致滞后执行同步命令，这样就会导致数据不一致
解决方案： 可以开发一个外部程序来监控主从库间的复制进度（master_repl_offset 和 slave_repl_offset ），通过监控 master_repl_offset 与slave_repl_offset差值得知复制进度，当复制进度不符合预期设置的Client不再从该从库读取数据。
![数据不一致](https://cdn.jsdelivr.net/gh/fengxiu/img/20220425141528.png)

## 参考

1. [请讲一下Redis主从复制的功能及实现原理](https://segmentfault.com/a/1190000039167291)
2. [018.Redis Cluster故障转移原理](https://cloud.tencent.com/developer/article/1605715)
3. [Redis高可用总结：Redis主从复制、哨兵集群、脑裂...](https://juejin.cn/post/6920457759393742862#heading-7)