---
title: latex之列表使用
categories:
  - tex
abbrlink: dd2855a
date: 2019-12-26 09:08:11
tags:
---

列表就是将所要表达的内容分为若干个条目并按一定的顺序排列，达到简明、直观的效果。在论文的写作中会经常使用到列表。LaTeX 中常见的列表环境有 enumerate、itemize 和description。这三种列表环境的主要区别是列表项标签的不同。
<!-- more -->

### enumerate是有序列表

``` tex
\begin{enumerate}
    \item This is the first item
    \item This is the second item
    \item This is the third item
\end{enumerate}
```

生成效果如下
![181604170295824](https://cdn.jsdelivr.net/gh/fengxiu/img/181604170295824.png)

### itemize 是无序列表

``` tex
\begin{itemize}
    \item This is the first item
    \item This is the second item
    \item This is the third item
\end{itemize}
```

生成效果如下
![181609245917394](https://cdn.jsdelivr.net/gh/fengxiu/img/181609245917394.png)

### description 是解说列表，可以指定标签

``` tex
%\usepackage{pifont}
\begin{description}
    \item[\ding{47}] This is the first item
    \item[\ding{47}] This is the second item
    \item[\ding{47}] This is the third item
\end{description}
```

生成效果如下
![181615512164578](https://cdn.jsdelivr.net/gh/fengxiu/img/181615512164578.png)

列表环境也可以互相嵌套，默认情况下不同层级的标签不同，以体现分级层次。
同时为也可以定制列表前的序号，可以使用 A，a，I，i，1 作为可选项产生 \Alph，\alph，\Roman，\roman，\arabic的效果。比如下面这个例子:

``` tex
\begin{enumerate}[label=\Alph*)]
    \item  ddd
    \item ddd
\end{enumerate}

```

效果如下
![Xnip2020-02-15_21-30-18](https://cdn.jsdelivr.net/gh/fengxiu/img/Xnip2020-02-15_21-30-18.jpg)



### 参考
1. [latex 使用 enumitem 宏包调整 enumerate 或 itemize 的上下左右缩进间距](https://blog.csdn.net/robert_chen1988/article/details/83179571)
2. [定义不同的格式](https://www.cnblogs.com/ahhylau/p/4586167.html)
