# 线上DB 数值类型字段溢出检查

---

## 背景
>
之前，房源图片id溢出，导致房源图片插入不进去，影响可想而知。
当初通过alter table 将图片id都设置成bigint，虽然问题解决，但是导致业务中断的损失不容小觑。
所以，这次我们主要讨论如何预防这种问题的发生。


## 如何检查

---

* **检查所有auto_increment字段是否溢出**

```
优点：
	检查点比较单一，方便&快速
	
缺点：
	如果某些字段不是自增，通过程序自增，这样的字段就会漏掉
```


* **检查所有字段（数值类型）**

```
优点：
	检查全面，不留漏网之鱼
	
缺点：
	性能极慢，甚至会拖死数据库
	因为很多字段无索引，取真实的max值就是全表扫描
```

* **检查具有索引的（数值类型）字段**

```
优点：
	兼顾以上两种的优点。
	覆盖面80%
	
缺点：
	部分没有索引的字段会遗漏（如果没有索引，则基本不会以此条件查询，忽略）
	需要过滤掉重复索引
	
```


## 检查脚本

---

* [检查具有索引的数值类型](http://gitlab.corp.anjuke.com/_dba/blog/blob/master/Keithlan/mysql/SCRIPT/check_int_overflow/check_int_overflow.pl)


## 检查结果，使用率超过70%

---

### AIFANG

INT_RATIO|TABLE_SCHEMA|TABLE_NAME|COLUMN_NAME|DATA_TYPE|COLUMN_TYPE|IS_UNSIGNED|IS_INT|MAX_VALUE|MAX_REAL_VALUE|INDEX_NAME|SEQ_IN_INDEX
----|----|----|----|----|----|----|----|----|----|----|----|
100|xx_db||xx_filed|int|int(11)|0|1|2147483647|2147483647|idx1|1|
