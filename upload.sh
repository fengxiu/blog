#!/bin/bash
if [ ! -n "$1" ] ;then
    echo "请输入此次提交git的注释"
else
    git config --global user.email "zhangkefengxiu@gmail.com"
    git config  --global user.name "zhangke"
    hexo clean
    git add --all
    git commit -m $1
    git remote rm origin
    git remote add origin git@github.com:fengxiu/blog.git
    git push origin master:master
fi