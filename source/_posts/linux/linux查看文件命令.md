---
categories:
  - linux
title: inux 查看文件命令
abbrlink: b4c41cf9
date: 2021-07-28 10:09:53
---
# linux 查看文件命令

当我们在进行调试的时候，经常需要查看各种日志文件，这时候熟悉linux下一些常用的查看文件命令是非常重要的，本篇文章专门整理了这些常用的命令，主要有下面几个。

1. tail
2. cat
3. more

## tail命令

ltail命令用途是依照要求将指定的文件的最后部分输出到标准设备，通常是终端，通俗讲来，就是把某个文件的最后几行显示到终端上，假设该文件有更新，tail会自己主动刷新，确保你看到最新的文件内容。

### tail命令语法

tail [ -f ] [ -c Number | -n Number | -m Number | -b Number | -k Number ]  [-r]  [ File ]

参数解释：

1. -f 该参数用于监视File文件动态增长。
2. -c Number 从 Number 字节位置读取指定文件
3. -n Number 从 Number 行位置读取指定文件。
4. -m Number 从 Number 多字节字符位置读取指定文件，比方你的文件假设包括中文字，假设指定-c参数，可能导致截断，但使用-m则会避免该问题。
5. -b Number 从 Number 表示的512字节块位置读取指定文件。
6. -k Number 从 Number 表示的1KB块位置读取指定文件。
7. -r 这个会似的按照现实内容相反的顺序现实，具体见下面例子 
8. File 指定操作的目标文件名称

上述命令中，都涉及到number，假设不指定，默认显示10行。Number前面可使用正负号，表示该偏移从顶部还是从尾部开始计算。这个具体看下面例子。
<!-- more -->
### tail命令使用例子

1. tail -f filename
说明：监视filename文件的尾部内容（默认10行，相当于增加参数 -n 10），刷新显示在屏幕上。退出，按下CTRL+C。

2. tail -n 20 filename
说明：显示filename最后20行。

3. tail -n +20 filename
说明：显示filename前面20行。

4. tail -r -n 10 filename
说明：逆序显示filename最后10行。

    ``` bash
    $ tail -n 2 filename
        source ~/.zshrc
        echo 'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles' >> ~/.zshrc

    $ tail -r -n 2 filename
        echo 'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles' >> ~/.zshrc
        source ~/.zshrc
    ```

## cat命令

cat命令用于连接文件并打印到标准输出设备上。

### cat命令语法

cat [-benstuv] [file ...]

参数解释：

1. -n   由 1 开始对所有输出的行数编号。
2. -b  和 -n 相似，只不过对于空白行不编号。
3. -s  当遇到有连续两行以上的空白行，就代换为一行的空白行。
4. -v  显示非打印字符，使用 ^ 和 M- 符号，除了 LFD 和 TAB 之外。
5. -e 显示非打印字符 在每行结束处显示 $。
6. -t 显示非打印字符，将 TAB 字符显示为 ^I。
7. -u 禁用输出缓冲
8. file... 可以同时指定多个文件，会按照文件名输入的顺序显示文件，如果文件名不存在或者是"-"，表示读取标准输入作为内容，如果文件是一个socket文件，cat链接这个文件直到读取EOF标志为止。

### cat使用例子

1. cat -n textfile1 > textfile2
把 textfile1 的文档内容加上行号后输入 textfile2 这个文档里：

2. cat -b textfile1 textfile2 >> textfile3
把 textfile1 和 textfile2 的文档内容加上行号（空白行不加）之后将内容附加到 textfile3 文档里：

3. cat /dev/null > /etc/test.txt
清空 /etc/test.txt 文档内容：

4. cat /dev/fd0 > OUTFILE
cat 也可以用来制作镜像文件。例如要制作软盘的镜像文件，将软盘放好后输入.

5. 相反的，如果想把 image file 写到软盘，输入：
cat IMG_FILE > /dev/fd0

## more命令

more命令类似 cat ，不过会以一页一页的形式显示，更方便使用者逐页阅读，而最基本的指令就是按空白键（space）就往下一页显示，按b键就会往回（back）一页显示，而且还有搜寻字串的功能（与 vi 相似），使用中的说明文件，请按 h 。

### more命令语法

more [-dlfpcsu] [-num] [+/pattern] [+lnum] [fileNames..]
参数解释：

1. -num 一次显示的行数
2. -d 提示使用者，在画面下方显示 [Press space to continue, 'q' to quit.] ，如果使用者按错键，则会显示 [Press 'h' for instructions.] 而不是 '哔' 声
3. -l 取消遇见特殊字元 ^L（送纸字元）时会暂停的功能
4. -f 计算行数时，以实际上的行数，而非自动换行过后的行数（有些单行字数太长的会被扩展为两行或两行以上）
5. -p 不以卷动的方式显示每一页，而是先清除萤幕后再显示内容
6. -c 跟 -p 相似，不同的是先显示内容再清除其他旧资料
7. -s 当遇到有连续两行以上的空白行，就代换为一行的空白行
8. -u 不显示下引号 （根据环境变数 TERM 指定的 terminal 而有所不同）
9. +/pattern 在每个文档显示前搜寻该字串（pattern），然后从该字串之后开始显示
10. +num 从第 num 行开始显示
11. -num 设置每屏显示的行数
12. fileNames 欲显示内容的文档，可为复数个数

### more命令实例

1. more -s testfile
逐页显示 testfile 文档内容，如有连续两行以上空白行则以一行空白行显示。

2. more +20 testfile
从第 20 行开始显示 testfile 之文档内容。

3. more -5  testfile
每屏显示5行

4. more +/day3 testfile
从文件中查找第一个出现"day3"字符串的行，并从该处前两行开始显示输出 

配置more常用操作命令

1. Enter 向下n行，需要定义。默认为1行
2. Ctrl+F 向下滚动一屏
3. 空格键 向下滚动一屏
4. Ctrl+B 返回上一屏
5. = 输出当前行的行号
6. ：f 输出文件名和当前行的行号
7. V 调用vi编辑器
8. !命令 调用Shell，并执行命令
9. q 退出more

## less命令

![导航](https://www.runoob.com/linux/linux-comm-less.html)