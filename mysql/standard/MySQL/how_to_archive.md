# How to archive MySQL data

两种用途：

1. 直接将过期不使用的删除数据
2. 将过期不使用的数据线搬迁到其他存储，如：Hbase，然后再将其从MySQL中删除 



## 删除MySQL数据的规范
----

### DBA 操作的表

1. 表名为： table_YYYYMMDD （日表）
2. 表名为： table_YYYYMM	  （月表）
3. 表名为： table_YYYY    (年表)

#### 删除规范

以上表由DBA 直接truncate & drop

---

### 开发 操作的表

1. 单表大小超过5G
2. 单表记录数超过1千万

以上表均由开发自行删除delete

#### 删除规范

* **必须按照主键删除，且只能是主键**

```
SQL> delete from table where pk in (N,N,N);   -- in 后面的列表必须小于200个
```

* **一次只能删除200条记录**

```
SQL> delete from table where pk in (N,...,N+200); 
```


* **每条delete语句执行完后，必须sleep 1;**

```
SQL> delete from table where pk in (N,N,N....N+200); sleep 1;
```


* **delete 语句后面一定不能使用 limit**

```
SQL> delete from table where pk in (N,N) limit N; -- 请禁止这种类型的操作
```

