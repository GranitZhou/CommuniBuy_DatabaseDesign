一、社区团购平台数据库设计文档

1\. 设计目标与约定

项目	约定

数据库	MySQL 8.0

存储引擎	InnoDB

字符集	utf8mb4

用户 ID	VARCHAR(32)，只允许字母、数字、下划线，不能数字开头；使用 utf8mb4\_bin 区分大小写

金额	整数，单位：分，避免浮点误差

时间	Unix 时间戳，单位：秒，使用 BIGINT

删除策略	核心表使用逻辑删除 deleted，避免破坏历史订单

密码	只存 BCrypt 哈希，不存明文

库存	items.stock 为剩余可售库存，下单时原子扣减

令牌	JWT 无状态；登出吊销可落库或放 Redis



2\. ER 关系

erDiagram

&#x20;   users ||--o{ user\_addresses : has

&#x20;   users ||--o{ items : owns

&#x20;   users ||--o{ orders : buys

&#x20;   users ||--o{ orders : sells

&#x20;   items ||--o{ orders : contains

&#x20;   items ||--o{ stock\_logs : logs

&#x20;   orders ||--o{ stock\_logs : triggers

说明：



users 是用户表。



user\_addresses 保存用户收货地址，API 返回时聚合为字符串列表。



items 是团购/商品表，owner\_id 指向发起人。



orders 是订单表，user\_id 是买家，owner\_id 是团购发起人。



stock\_logs 是库存流水，用于审计和对账。



token\_blacklist 可选，用于 JWT 登出吊销。



3\. 表结构设计

3.1 用户表 users

字段	类型	说明

id	VARCHAR(32)	用户唯一 ID，主键，大小写敏感

password\_hash	VARCHAR(255)	BCrypt 密码哈希

nickname	VARCHAR(64)	昵称

description	VARCHAR(255)	描述

role	INT	0 普通用户，1 管理员，-1 封禁

deleted	TINYINT	逻辑删除，0 正常，1 删除

create\_time	BIGINT	创建时间 Unix 秒

update\_time	BIGINT	更新时间 Unix 秒

3.2 用户地址表 user\_addresses

字段	类型	说明

id	BIGINT UNSIGNED	主键，自增

user\_id	VARCHAR(32)	用户 ID

address	VARCHAR(255)	收货地址

is\_default	TINYINT	是否默认地址

create\_time	BIGINT	创建时间

update\_time	BIGINT	更新时间

API 中 GET /api/v1/user/{id} 返回 address 字符串列表，可通过该表聚合。

POST /api/v1/user/{id} 传 address 时，建议新增一条地址；若只允许一个默认地址，则先取消旧默认再插入新默认。



3.3 团购/商品表 items

字段	类型	说明

id	BIGINT UNSIGNED	主键，自增

name	VARCHAR(128)	团购商品名称

description	TEXT	商品描述

price	INT UNSIGNED	单价，单位：分

stock	INT UNSIGNED	剩余库存

status	INT	负数下架；>=0 上架且已发货 n 次

owner\_id	VARCHAR(32)	发起人用户 ID

start\_time	BIGINT	开始时间，0 表示立即开始

end\_time	BIGINT	结束时间，-1 表示永不结束

deleted	TINYINT	逻辑删除

create\_time	BIGINT	创建时间

update\_time	BIGINT	更新时间



3.4 订单表 orders

字段	类型	说明

id	BIGINT UNSIGNED	主键，自增

item\_id	BIGINT UNSIGNED	团购 ID

user\_id	VARCHAR(32)	买家用户 ID

owner\_id	VARCHAR(32)	团购发起人用户 ID，冗余便于查询

quantity	INT UNSIGNED	购买数量

price	INT UNSIGNED	成交时单价，单位：分

address	VARCHAR(255)	收货地址

status	INT	0 待支付，1 待发货，2 待收货，3 已完成，-1 已取消

create\_time	BIGINT	下单时间

pay\_time	BIGINT	支付时间

ship\_time	BIGINT	发货时间

receipt\_time	BIGINT	收货时间

close\_time	BIGINT	关闭时间

deleted	TINYINT	逻辑删除



3.5 库存流水表 stock\_logs

字段	类型	说明

id	BIGINT UNSIGNED	主键，自增

item\_id	BIGINT UNSIGNED	团购 ID

order\_id	BIGINT UNSIGNED	关联订单，可为空

change\_type	VARCHAR(16)	LOCK / RELEASE / DEDUCT / ADJUST

quantity	INT	变动数量

before\_stock	INT	变动前库存

after\_stock	INT	变动后库存

create\_time	BIGINT	创建时间

3.6 JWT 吊销表 token\_blacklist，可选

字段	类型	说明

id	BIGINT UNSIGNED	主键，自增

token\_hash	CHAR(64)	JWT 或 jti 的 SHA-256

user\_id	VARCHAR(32)	用户 ID

expire\_at	BIGINT	令牌过期时间

revoked\_at	BIGINT	吊销时间

如果使用 Redis 做登出黑名单，可省略此表。

