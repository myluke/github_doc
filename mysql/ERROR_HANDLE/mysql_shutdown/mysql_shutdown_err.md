# mysql shutdown 异常处理和分析
> 任何东西都有结束的一天，当初分析过linux的开机与关机流程。现在遇到了mysql关机异常，顺便了解一下mysql的关机流程。


## 先了解一下mysql的shutdown流程
---
1. The shutdown process is initiated.
2. The server creates a shutdown thread if necessary.
3. The server stops accepting new connections.
4. The server terminates current activity.
5. The server shuts down or closes storage engines.
6. The server exits.

以上只是官方文档中介绍的一些基本的关机流程,正确的关机命令当然是mysqladmin -xx  shutdown 。接下来，我们来关注一下我们的问题

## 问题描述
----
**mysqladmin shutdown 不但没有关闭掉，反而会restart**

提示信息如下：

```
150105 14:50:47 mysqld_safe Number of processes running now: 0
150105 14:50:47 mysqld_safe mysqld restarted
```
齐了个怪了，我的参数明明是shutdown ，为什么提示信息是 restart呢？ 错误日志中也无明显错误， 程序Bug了？

唯一能关闭的方法就是： kill ， 这是非法的，我们当然不能这样做。

于是尝试了N种方法

```
* 可能是/usr/local/mysql/data/xxxx.pid文件没有写的权限
* 可能进程里已经存在mysql进程
* 可能是第二次在机器上安装mysql，有残余数据影响了服务的启动。
* mysql在启动时没有指定配置文件时会使用/etc/my.cnf配置文件，请打开这个文件查看在[mysqld]节下有没有指定数据目录(datadir)。
* skip-federated字段问题
* 错误日志目录不存在
* selinux惹的祸，如果是centos系统，默认会开启selinux
```

很不幸的是，都不是上述问题造成。既然google也找不到，那只能看源码了。

大家都知道，mysqld_safe 是 启动mysql的守护进程，我想89不离10，应该是由它重启的，那就一窥究竟吧。

源码文件如下： [mysqld_safe](http://gitlab.corp.anjuke.com/_dba/blog/blob/master/Keithlan/mysql/ERROR_HANDLE/mysql_shutdown/mysqld_safe)

下面是部分重要的部分，特拿出来分析,其中添加了一些注释和一些方便调试的断点代码（add by keithlan）。

```
# 后面就是用它启动的mysqld，通过logging变量区分记录日志的类型，分错误日志和系统日志syslog两种
# 最后的eval命令会解析 $cmd 中的值并执行命令
eval_log_error () {
  cmd="$1"
  case $logging in
    file) cmd="$cmd >> "`shell_quote_string "$err_log"`" 2>&1" ;;
    syslog)
      # mysqld often prefixes its messages with a timestamp, which is
      # redundant when logging to syslog (which adds its own timestamp)
      # However, we don't strip the timestamp with sed here, because
      # sed buffers output (only GNU sed supports a -u (unbuffered) option)
      # which means that messages may not get sent to syslog until the
      # mysqld process quits.
      cmd="$cmd 2>&1 | logger -t '$syslog_tag_mysqld' -p daemon.error"
      ;;
    *)
      echo "Internal program error (non-fatal):" \
           " unknown logging method '$logging'" >&2
      ;;
  esac

  echo "Running mysqld: [$cmd]"   --add by Keithlan
  eval "$cmd"
}

# 后台循环 执行mysqld
log_notice "Starting $MYSQLD daemon with databases from $DATADIR"
while true
do
  rm -f $safe_mysql_unix_port "$pid_file"       # Some extra safety # 保险起见，又删除了一次pid文件
  log_notice "rm -f $safe_mysql_unix_port $pid_file !"  #add by Keithlan

  eval_log_error "$cmd"
  log_notice " after running mysql "                     #add by Keithlan
  last_pid=`ls -l /usr/local/mysql/var/`      #add by Keithlan
  log_notice " last_pid = $last_pid !!"       #add by Keithlan

  # 正常的shutdown 会删除pid文件，如果没有pid文件，会正常退出，如果有，则继续。
  # 可想而知，这是唯一跳出循环的地方，这里一定有猫腻。
  if test ! -f "$pid_file"              # This is removed if normal shutdown  
  then
    log_notice "$pid_file"             #add by Keithlan
    break
  fi

# mysqld_safe已经启动的处理方法，保证只有一个mysqld_safe程序启动
  if true && test $KILL_MYSQLD -eq 1
  then
    # Test if one process was hanging.
    # This is only a fix for Linux (running as base 3 mysqld processes)
    # but should work for the rest of the servers.
    # The only thing is ps x => redhat 5 gives warnings when using ps -x.
    # kill -9 is used or the process won't react on the kill.
    # 统计启动的mysqld进程的数目
    numofproces=`ps xaww | grep -v "grep" | grep "$ledir/$MYSQLD\>" | grep -c "pid-file=$pid_file"`

    log_notice "Number of processes running now: $numofproces"
    I=1
    while test "$I" -le "$numofproces"
    do
      # 这个PROC的数据即是ps mysqld_safe程序的输出 第一个数字即为进程ID
      PROC=`ps xaww | grep "$ledir/$MYSQLD\>" | grep -v "grep" | grep "pid-file=$pid_file" | sed -n '$p'`
	  # 使用T来获取进程ID
      for T in $PROC
      do
        break
      done
      #    echo "TEST $I - $T **"
      # kill掉该个mysqld_safe程序
      if kill -9 $T
      then
        log_error "$MYSQLD process hanging, pid $T - killed"
      else
        break
      fi
      # 每干掉一个mysqld_safe就把I加一，这样没有多余的mysqld_safe时就可以跳出循环了
      I=`expr $I + 1`
    done
  fi
  log_notice "mysqld restarted"
  log_notice "Keithlan"

done

#mysql shutdown 成功，打印pid文件
log_notice "mysqld from pid file $pid_file ended"
```

简单描述一下过程就是：myqsld_safe 会用eval去启动mysqld，再后台运行，知道接受到kill 命令，或者shutdown 进程来kill掉它。
如果是非正常kill，mysqld_safe 会一直监控，将mysqld进程 restart起来。

经过调试后，手动去rm -f 掉pid文件， 然后再mysqladmin shutdown，是可以正常关闭的，很明显，就能定位到问题就出在pid上。为什么mysqladmin 进程shutdown的时候没有删除掉pid文件呢？ 首先可以排除掉权限等问题，因为既然能够create pid，当然可以delete pid咯。问题一定是mysqladmin 哪个地方出问题了，果然，根据线索找到mysqladmin 代码中断言出现问题Failing assertion: UT_LIST_GET_LEN(rseg->update_undo_list) == 0，网上搜了一堆的bug。 后来，想想，是不是表空间出了问题,mysql shutdown的时候回去回收表空间记录，如果回收不成功，导致不能normal shutdown，导致无法删除掉pid文件。 于是，将表空间重建后，问题消失。


## 总结
---

由于时间成本的问题，没能去详细了解mysqladmin 和 table space 的关系，但是却对mysql 的shutdown 流程有了进一步的认识，总算对自己有了一点交代。

