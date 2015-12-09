# 深入浅出timestamp

---

## 前提

```
对于timestamp相关的错误，之前也有耳闻，但是并没有详细去了解，导致昨天有位同事描述的错误场景不能及时回答，这说明自己对Mysql的理解还是知之甚少。故，这里详细谈谈timestamp
```

## 错误场景

---

好了，这里直奔主题吧。昨天有位同事遇到的错误ERROR 1293 (HY000):

```
* Mysql version 5.1.54

create table lc_test_0(
	`update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'cms时间' ,
    `upload_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '上传时间'
)ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';

ERROR 1293 (HY000): Incorrect table definition; there can be only one TIMESTAMP column with CURRENT_TIMESTAMP in DEFAULT or ON UPDATE clause


```

通过以上错误，查查手册就知道，timestamp类型不允许有两个CURRENT_TIMESTAMP作为default值。

既然如此，那我们就去掉一个呗

```
create table lc_test_3(
    `upload_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '上传时间',
	`update_time` timestamp NOT NULL
)ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';

Query OK, 0 rows affected (0.00 sec)

```

so easy，这不就解决了嘛。

可是问题真是这样嘛？有些同学比较严谨和认真，将两个字段的顺序对调一下，则

```
create table lc_test_2(
	`update_time` timestamp NOT NULL ,
    `upload_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '上传时间'
)ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';

ERROR 1293 (HY000): Incorrect table definition; there can be only one TIMESTAMP column with CURRENT_TIMESTAMP in DEFAULT or ON UPDATE clause

```

你看看，问题又来了，这样彻底晕了，同样的建表语句，只是字段顺序变掉了，就错了？

莫非这是Mysql 的 BUG？ 去Mysql Buglist中去查查看，结果没有类似bug。

目前能想到的就是仔细去看看官方文档对于CURRENT_TIMESTAMP的描述

```
* Mysql 5.1 *
 
One TIMESTAMP column in a table can have the current timestamp as the default value for initializing the column, as the auto-update value, or both. It is not possible to have the current timestamp be the default value for one column and the auto-update value for another column.
```
看的仔细的同学就会发现，current timestamp as the default value for initializing the column，意思就是Mysql 会初始化第一个TIMESTAMP字段的default值为‘current timestamp’。一个表里面多个TIMESTAMP column 只能拥有一个‘current timestamp’值。

so，这下豁然开朗,既然如此，那么就开始测试以上理论吧。

* **既然第一个timestamp字段的默认default为‘current timestamp’,那我显示更改默认值总可以吧**

```
create table lc_test_1(
	`update_time` timestamp NOT NULL default '0000-00-00',
    `upload_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '上传时间'
)ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';
Query OK, 0 rows affected  (0.10 sec)
```

* **第一个timestamp字段的默认default为‘current timestamp’，第二个字段总不会了吧**

```
root:test> create table lc_test_4(
      `update_time` timestamp NOT NULL ,
      `upload_time` timestamp NOT NULL
     )ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';
Query OK, 0 rows affected (0.00 sec)

root:test> desc lc_test_4;
+-------------+-----------+------+-----+---------------------+-----------------------------+
| Field       | Type      | Null | Key | Default             | Extra                       |
+-------------+-----------+------+-----+---------------------+-----------------------------+
| update_time | timestamp | NO   |     | CURRENT_TIMESTAMP   | on update CURRENT_TIMESTAMP |
| upload_time | timestamp | NO   |     | 0000-00-00 00:00:00 |                             |
+-------------+-----------+------+-----+---------------------+-----------------------------+
2 rows in set (0.01 sec)
```

ok，到这里，我想这个问题应该彻底明白了吧。

那我们又回过头来思考一下，为什么只能拥有一个CURRENT_TIMESTAMP default值呢？说实话，我还真没想明白。但是，我知道Mysql 5.5 高版本和Mysql5.6 以及更高版本以及去掉了这个限制

```
Previously, at most one TIMESTAMP column per table could be automatically initialized or updated to the current date and time. This restriction has been lifted. Any TIMESTAMP column definition can have any combination of DEFAULT CURRENT_TIMESTAMP and ON UPDATE CURRENT_TIMESTAMP clauses. In addition, these clauses now can be used with DATETIME column definitions. For more information, see Automatic Initialization and Updating for TIMESTAMP and DATETIME.

```

测试：

```
* Mysql 5.6 *

dbadmin:test> create table lc_test_1(
     `update_time` timestamp NOT NULL,
     `upload_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '上传时间'
     )ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';
Query OK, 0 rows affected (0.01 sec)

dbadmin:test> create table lc_test_2(
        `upload_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '上传时间',
     `update_time` timestamp NOT NULL
    )ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='已推送客户列表';
Query OK, 0 rows affected (0.02 sec)

```

## 结论

---


*  以上问题，均源于对Mysql 官方文档的不细致学习造成。

*  Mysql官方文档目前虽然讲解的原理不是很深，很细，但是确实值得我们仔细阅读。

