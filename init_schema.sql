-- 社区团购平台初始化表结构
-- MySQL 8.0, InnoDB, utf8mb4

CREATE TABLE users (
    id VARCHAR(32) COLLATE utf8mb4_bin NOT NULL COMMENT '用户唯一ID，字母数字下划线，不能数字开头',
    password_hash VARCHAR(255) NOT NULL COMMENT 'BCrypt 密码哈希',
    nickname VARCHAR(64) NOT NULL DEFAULT '' COMMENT '昵称',
    description VARCHAR(255) NOT NULL DEFAULT '' COMMENT '描述',
    role INT NOT NULL DEFAULT 0 COMMENT '0普通用户，1管理员，-1封禁用户',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0正常，1删除',
    create_time BIGINT NOT NULL COMMENT '创建时间 Unix 秒',
    update_time BIGINT NOT NULL COMMENT '更新时间 Unix 秒',
    PRIMARY KEY (id),
    KEY idx_users_role (role),
    KEY idx_users_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户表';

CREATE TABLE user_addresses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '地址ID',
    user_id VARCHAR(32) COLLATE utf8mb4_bin NOT NULL COMMENT '用户ID',
    address VARCHAR(255) NOT NULL COMMENT '收货地址',
    is_default TINYINT NOT NULL DEFAULT 0 COMMENT '是否默认地址',
    create_time BIGINT NOT NULL COMMENT '创建时间 Unix 秒',
    update_time BIGINT NOT NULL COMMENT '更新时间 Unix 秒',
    PRIMARY KEY (id),
    KEY idx_addr_user (user_id),
    CONSTRAINT fk_addr_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户收货地址表';

CREATE TABLE items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '团购ID',
    name VARCHAR(128) NOT NULL COMMENT '团购商品名称',
    description TEXT NULL COMMENT '商品描述',
    price INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '单价，单位：分',
    stock INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '剩余库存',
    status INT NOT NULL DEFAULT 0 COMMENT '负数下架；>=0上架且已发货n次',
    owner_id VARCHAR(32) COLLATE utf8mb4_bin NOT NULL COMMENT '发起人用户ID',
    start_time BIGINT NOT NULL DEFAULT 0 COMMENT '开始时间，0表示立即开始',
    end_time BIGINT NOT NULL DEFAULT -1 COMMENT '结束时间，-1表示永不结束',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0正常，1删除',
    create_time BIGINT NOT NULL COMMENT '创建时间 Unix 秒',
    update_time BIGINT NOT NULL COMMENT '更新时间 Unix 秒',
    PRIMARY KEY (id),
    KEY idx_items_owner (owner_id),
    KEY idx_items_status (status),
    KEY idx_items_time (start_time, end_time),
    KEY idx_items_deleted (deleted),
    CONSTRAINT fk_items_owner FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='团购/商品表';

CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单ID',
    item_id BIGINT UNSIGNED NOT NULL COMMENT '团购ID',
    user_id VARCHAR(32) COLLATE utf8mb4_bin NOT NULL COMMENT '买家用户ID',
    owner_id VARCHAR(32) COLLATE utf8mb4_bin NOT NULL COMMENT '团购发起人用户ID',
    quantity INT UNSIGNED NOT NULL COMMENT '购买数量',
    price INT UNSIGNED NOT NULL COMMENT '成交时单价，单位：分',
    address VARCHAR(255) NOT NULL COMMENT '收货地址',
    status INT NOT NULL DEFAULT 0 COMMENT '0待支付，1待发货，2待收货，3已完成，-1已取消',
    create_time BIGINT NOT NULL COMMENT '下单时间 Unix 秒',
    pay_time BIGINT NULL COMMENT '支付时间 Unix 秒',
    ship_time BIGINT NULL COMMENT '发货时间 Unix 秒',
    receipt_time BIGINT NULL COMMENT '收货时间 Unix 秒',
    close_time BIGINT NULL COMMENT '关闭时间 Unix 秒',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0正常，1删除',
    PRIMARY KEY (id),
    KEY idx_orders_user (user_id),
    KEY idx_orders_owner (owner_id),
    KEY idx_orders_item (item_id),
    KEY idx_orders_status (status),
    KEY idx_orders_create_time (create_time),
    CONSTRAINT fk_orders_item FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE RESTRICT,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_orders_owner FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='订单表';

CREATE TABLE stock_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '库存流水ID',
    item_id BIGINT UNSIGNED NOT NULL COMMENT '团购ID',
    order_id BIGINT UNSIGNED NULL COMMENT '关联订单ID',
    change_type VARCHAR(16) NOT NULL COMMENT 'LOCK/RELEASE/DEDUCT/ADJUST',
    quantity INT NOT NULL COMMENT '变动数量',
    before_stock INT NOT NULL COMMENT '变动前库存',
    after_stock INT NOT NULL COMMENT '变动后库存',
    create_time BIGINT NOT NULL COMMENT '创建时间 Unix 秒',
    PRIMARY KEY (id),
    KEY idx_stock_item (item_id),
    KEY idx_stock_order (order_id),
    CONSTRAINT fk_stock_item FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE RESTRICT,
    CONSTRAINT fk_stock_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='库存流水表';

CREATE TABLE token_blacklist (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    token_hash CHAR(64) NOT NULL COMMENT 'JWT/jti 的 SHA-256',
    user_id VARCHAR(32) COLLATE utf8mb4_bin NOT NULL COMMENT '用户ID',
    expire_at BIGINT NOT NULL COMMENT '令牌过期时间 Unix 秒',
    revoked_at BIGINT NOT NULL COMMENT '吊销时间 Unix 秒',
    PRIMARY KEY (id),
    UNIQUE KEY uk_token_hash (token_hash),
    KEY idx_token_user (user_id),
    KEY idx_token_expire (expire_at),
    CONSTRAINT fk_token_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='JWT吊销黑名单，可选';