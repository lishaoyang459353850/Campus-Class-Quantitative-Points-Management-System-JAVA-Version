-- =============================================================================
-- 校园班级量化积分管理系统 —— 数据库初始化脚本
-- School Class Quantitative Points Management System
--
-- 文件路径：sql/init.sql
-- 数据库：MySQL 8.0+
-- 字符集：utf8mb4 / utf8mb4_general_ci
--
-- 执行方式（二选一）：
--   1) 命令行：mysql -uroot -p --default-character-set=utf8mb4 < sql/init.sql
--   2) 客户端：用 Navicat / DBeaver 打开本文件，整体执行
--
-- 脚本内容：
--   一、建库
--   二、核心业务表（14 张）：user / student / teacher / class / quant_category /
--       quant_record / email_code / login_log / operation_log / announcement /
--       appeal / import_log / captcha_log / class_teacher
--   三、扩展表（11 张）：role / permission / role_permission / user_role /
--       system_config / email_template / notification / token_blacklist /
--       login_fail_record / file_upload / rate_limit_record
--   四、外键、索引（随表定义一并给出）
--   五、默认数据：管理员、量化分类、演示班级/教师/学生、演示积分、公告、申诉、系统配置、邮件模板
--
-- 约定：
--   1. 所有业务表均包含：created_at、updated_at、created_by、updated_by、deleted（软删除）
--   2. 逻辑删除统一为 deleted：0 未删除 / 1 已删除
--   3. 状态字段统一为大写英文枚举，前端负责中文展示
--   4. 所有时间字段使用 DATETIME，由 MySQL 维护创建/更新时间
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- 一、建库
-- =============================================================================
CREATE DATABASE IF NOT EXISTS `school_points`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_general_ci;

USE `school_points`;

-- 【危险操作，默认注释】需要完全重建库时手动放开下面一行
-- DROP DATABASE IF EXISTS `school_points`;

-- =============================================================================
-- 二、核心业务表
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. user 用户表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user` (
    `id`                   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `username`             VARCHAR(50)  NOT NULL                COMMENT '登录名',
    `password`             VARCHAR(255) NOT NULL                COMMENT '密码（BCrypt 加密，禁止明文）',
    `email`                VARCHAR(100) NOT NULL                COMMENT '邮箱（唯一）',
    `phone`                VARCHAR(20)           DEFAULT NULL   COMMENT '手机号',
    `role`                 VARCHAR(20)  NOT NULL DEFAULT 'STUDENT' COMMENT '角色：STUDENT 学生 / TEACHER 教师 / ADMIN 管理员',
    `status`               VARCHAR(20)  NOT NULL DEFAULT 'ENABLED' COMMENT '状态：ENABLED 启用 / DISABLED 禁用 / PENDING 待审核',
    `avatar`               VARCHAR(255)          DEFAULT NULL   COMMENT '头像地址',
    `must_change_password` TINYINT      NOT NULL DEFAULT 0      COMMENT '是否强制修改密码：1 是（默认管理员首次登录为 1）',
    `login_fail_count`     INT          NOT NULL DEFAULT 0      COMMENT '连续登录失败次数',
    `locked_until`         DATETIME              DEFAULT NULL   COMMENT '锁定截止时间',
    `last_login_time`      DATETIME              DEFAULT NULL   COMMENT '最后登录时间',
    `last_login_ip`        VARCHAR(50)           DEFAULT NULL   COMMENT '最后登录 IP',
    `remark`               VARCHAR(255)          DEFAULT NULL   COMMENT '备注',
    `created_by`           BIGINT                DEFAULT NULL   COMMENT '创建人 user.id',
    `updated_by`           BIGINT                DEFAULT NULL   COMMENT '更新人 user.id',
    `created_at`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`              TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记：0 正常 / 1 已删除',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_username` (`username`),
    UNIQUE KEY `uk_user_email` (`email`),
    KEY `idx_user_role` (`role`),
    KEY `idx_user_status` (`status`),
    KEY `idx_user_deleted` (`deleted`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '用户表';

-- -----------------------------------------------------------------------------
-- 2. teacher 教师表（先建，class 需要外键引用）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `teacher` (
    `id`         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`    BIGINT      NOT NULL                COMMENT '关联 user.id',
    `teacher_no` VARCHAR(50) NOT NULL                COMMENT '工号（唯一）',
    `name`       VARCHAR(50) NOT NULL                COMMENT '姓名',
    `phone`      VARCHAR(20)          DEFAULT NULL   COMMENT '手机号',
    `status`     VARCHAR(20) NOT NULL DEFAULT 'ENABLED' COMMENT '状态：ENABLED / DISABLED / PENDING',
    `created_by` BIGINT               DEFAULT NULL   COMMENT '创建人',
    `updated_by` BIGINT               DEFAULT NULL   COMMENT '更新人',
    `created_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`    TINYINT     NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_teacher_user` (`user_id`),
    UNIQUE KEY `uk_teacher_no` (`teacher_no`),
    KEY `idx_teacher_name` (`name`),
    KEY `idx_teacher_status` (`status`),
    CONSTRAINT `fk_teacher_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '教师表';

-- -----------------------------------------------------------------------------
-- 3. class 班级表
--    head_teacher_id 的外键在教师表之后创建（避免循环依赖）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `class` (
    `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `name`            VARCHAR(50)  NOT NULL                COMMENT '班级名称，如 高一(1)班',
    `grade`           VARCHAR(50)           DEFAULT NULL   COMMENT '年级，如 高一',
    `head_teacher_id` BIGINT                DEFAULT NULL   COMMENT '班主任 teacher.id',
    `description`     VARCHAR(255)          DEFAULT NULL   COMMENT '班级描述',
    `status`          VARCHAR(20)  NOT NULL DEFAULT 'ENABLED' COMMENT '状态：ENABLED / DISABLED',
    `created_by`      BIGINT                DEFAULT NULL   COMMENT '创建人',
    `updated_by`      BIGINT                DEFAULT NULL   COMMENT '更新人',
    `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`         TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_class_name` (`name`),
    KEY `idx_class_grade` (`grade`),
    KEY `idx_class_head_teacher` (`head_teacher_id`),
    KEY `idx_class_status` (`status`),
    CONSTRAINT `fk_class_head_teacher` FOREIGN KEY (`head_teacher_id`) REFERENCES `teacher` (`id`) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '班级表';

-- -----------------------------------------------------------------------------
-- 4. student 学生表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `student` (
    `id`         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`    BIGINT               DEFAULT NULL   COMMENT '关联 user.id（导入的学生可能暂无账号）',
    `student_no` VARCHAR(50) NOT NULL                COMMENT '学号（唯一）',
    `name`       VARCHAR(50) NOT NULL                COMMENT '姓名',
    `gender`     VARCHAR(10)          DEFAULT NULL   COMMENT '性别：男 / 女 / 未知',
    `class_id`   BIGINT               DEFAULT NULL   COMMENT '所属班级 class.id',
    `phone`      VARCHAR(20)          DEFAULT NULL   COMMENT '手机号',
    `status`     VARCHAR(20) NOT NULL DEFAULT 'ENABLED' COMMENT '状态：ENABLED / DISABLED',
    `created_by` BIGINT               DEFAULT NULL   COMMENT '创建人',
    `updated_by` BIGINT               DEFAULT NULL   COMMENT '更新人',
    `created_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`    TINYINT     NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_student_no` (`student_no`),
    UNIQUE KEY `uk_student_user` (`user_id`),
    KEY `idx_student_class` (`class_id`),
    KEY `idx_student_name` (`name`),
    KEY `idx_student_status` (`status`),
    CONSTRAINT `fk_student_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`),
    CONSTRAINT `fk_student_class` FOREIGN KEY (`class_id`) REFERENCES `class` (`id`) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '学生表';

-- -----------------------------------------------------------------------------
-- 5. class_teacher 班级-教师关联表（支持一个班多个任课教师）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `class_teacher` (
    `id`         BIGINT   NOT NULL AUTO_INCREMENT COMMENT '主键',
    `class_id`   BIGINT   NOT NULL                COMMENT '班级 class.id',
    `teacher_id` BIGINT   NOT NULL                COMMENT '教师 teacher.id',
    `is_head`    TINYINT  NOT NULL DEFAULT 0      COMMENT '是否班主任：1 是',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_class_teacher` (`class_id`, `teacher_id`),
    KEY `idx_ct_teacher` (`teacher_id`),
    CONSTRAINT `fk_ct_class` FOREIGN KEY (`class_id`) REFERENCES `class` (`id`),
    CONSTRAINT `fk_ct_teacher` FOREIGN KEY (`teacher_id`) REFERENCES `teacher` (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '班级教师关联表';

-- -----------------------------------------------------------------------------
-- 6. quant_category 量化分类表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `quant_category` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `name`          VARCHAR(50)  NOT NULL                COMMENT '分类名称，如 纪律',
    `type`          VARCHAR(20)  NOT NULL DEFAULT 'BOTH' COMMENT '类型：ADD 加分 / SUBTRACT 减分 / BOTH 加减分',
    `default_score` INT          NOT NULL DEFAULT 1      COMMENT '默认分值（正数）',
    `description`   VARCHAR(255)          DEFAULT NULL   COMMENT '分类描述',
    `status`        VARCHAR(20)  NOT NULL DEFAULT 'ENABLED' COMMENT '状态：ENABLED 启用 / DISABLED 禁用',
    `sort_order`    INT          NOT NULL DEFAULT 0      COMMENT '排序号，越小越靠前',
    `created_by`    BIGINT                DEFAULT NULL   COMMENT '创建人',
    `updated_by`    BIGINT                DEFAULT NULL   COMMENT '更新人',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`       TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_cat_name` (`name`),
    KEY `idx_cat_type` (`type`),
    KEY `idx_cat_status` (`status`),
    KEY `idx_cat_sort` (`sort_order`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '量化分类表';

-- -----------------------------------------------------------------------------
-- 7. quant_record 量化积分记录表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `quant_record` (
    `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `student_id`  BIGINT       NOT NULL                COMMENT '学生 student.id',
    `class_id`    BIGINT       NOT NULL                COMMENT '班级 class.id（冗余，便于按班统计）',
    `category_id` BIGINT       NOT NULL                COMMENT '分类 quant_category.id',
    `score`       INT          NOT NULL                COMMENT '分值：正数加分 / 负数减分',
    `reason`      VARCHAR(255) NOT NULL                COMMENT '原因',
    `recorder_id` BIGINT       NOT NULL                COMMENT '记录人 user.id',
    `record_time` DATETIME     NOT NULL                COMMENT '发生时间',
    `status`      VARCHAR(20)  NOT NULL DEFAULT 'NORMAL' COMMENT '状态：NORMAL 正常 / REVOKED 已撤销 / PENDING 待审核',
    `remark`      VARCHAR(500)          DEFAULT NULL   COMMENT '备注',
    `attachment`  VARCHAR(255)          DEFAULT NULL   COMMENT '附件地址（可选）',
    `created_by`  BIGINT                DEFAULT NULL   COMMENT '创建人',
    `updated_by`  BIGINT                DEFAULT NULL   COMMENT '更新人',
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`     TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_qr_student` (`student_id`),
    KEY `idx_qr_class` (`class_id`),
    KEY `idx_qr_category` (`category_id`),
    KEY `idx_qr_record_time` (`record_time`),
    KEY `idx_qr_status` (`status`),
    KEY `idx_qr_recorder` (`recorder_id`),
    CONSTRAINT `fk_qr_student` FOREIGN KEY (`student_id`) REFERENCES `student` (`id`),
    CONSTRAINT `fk_qr_class` FOREIGN KEY (`class_id`) REFERENCES `class` (`id`),
    CONSTRAINT `fk_qr_category` FOREIGN KEY (`category_id`) REFERENCES `quant_category` (`id`),
    CONSTRAINT `fk_qr_recorder` FOREIGN KEY (`recorder_id`) REFERENCES `user` (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '量化积分记录表';

-- -----------------------------------------------------------------------------
-- 8. email_code 邮箱验证码表
--    Redis 关闭时使用本表；Redis 开启时本表同时留档，便于审计
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `email_code` (
    `id`             BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
    `email`          VARCHAR(100) NOT NULL               COMMENT '接收邮箱',
    `code`           VARCHAR(10) NOT NULL                COMMENT '6 位数字验证码',
    `type`           VARCHAR(20) NOT NULL                COMMENT '类型：REGISTER / RESET_PASSWORD / BIND_EMAIL / CHANGE_PASSWORD',
    `expires_at`     DATETIME    NOT NULL                COMMENT '过期时间（默认 5 分钟）',
    `used`           TINYINT     NOT NULL DEFAULT 0      COMMENT '是否已使用：0 未用 / 1 已用',
    `verify_fail`    INT         NOT NULL DEFAULT 0      COMMENT '校验失败次数',
    `ip`             VARCHAR(50)          DEFAULT NULL   COMMENT '请求 IP',
    `created_at`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_ec_email` (`email`),
    KEY `idx_ec_type` (`type`),
    KEY `idx_ec_expires` (`expires_at`),
    KEY `idx_ec_used` (`used`),
    KEY `idx_ec_created` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '邮箱验证码表';

-- -----------------------------------------------------------------------------
-- 9. login_log 登录日志表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `login_log` (
    `id`         BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`    BIGINT                DEFAULT NULL   COMMENT '用户 id（登录失败时可能为空）',
    `account`    VARCHAR(100) NOT NULL                COMMENT '登录账号 / 邮箱',
    `ip`         VARCHAR(50)           DEFAULT NULL   COMMENT '登录 IP',
    `user_agent` VARCHAR(500)          DEFAULT NULL   COMMENT '浏览器 UA',
    `success`    TINYINT      NOT NULL DEFAULT 1      COMMENT '是否成功：1 成功 / 0 失败',
    `message`    VARCHAR(255)          DEFAULT NULL   COMMENT '结果说明',
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '登录时间',
    PRIMARY KEY (`id`),
    KEY `idx_ll_user` (`user_id`),
    KEY `idx_ll_account` (`account`),
    KEY `idx_ll_created` (`created_at`),
    KEY `idx_ll_success` (`success`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '登录日志表';

-- -----------------------------------------------------------------------------
-- 10. operation_log 操作日志表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `operation_log` (
    `id`         BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`    BIGINT                DEFAULT NULL   COMMENT '操作人 user.id',
    `username`   VARCHAR(50)           DEFAULT NULL   COMMENT '操作人登录名',
    `module`     VARCHAR(50)           DEFAULT NULL   COMMENT '模块：用户管理 / 班级管理 / 积分管理 …',
    `operation`  VARCHAR(100)          DEFAULT NULL   COMMENT '操作描述',
    `method`     VARCHAR(10)           DEFAULT NULL   COMMENT '请求方法：GET / POST / PUT / DELETE',
    `url`        VARCHAR(255)          DEFAULT NULL   COMMENT '请求地址',
    `params`     TEXT                                 COMMENT '请求参数（已脱敏）',
    `result`     TEXT                                 COMMENT '返回结果摘要',
    `ip`         VARCHAR(50)           DEFAULT NULL   COMMENT '操作 IP',
    `cost_time`  BIGINT                DEFAULT NULL   COMMENT '耗时（毫秒）',
    `success`    TINYINT      NOT NULL DEFAULT 1      COMMENT '是否成功：1 成功 / 0 失败',
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    PRIMARY KEY (`id`),
    KEY `idx_ol_user` (`user_id`),
    KEY `idx_ol_module` (`module`),
    KEY `idx_ol_created` (`created_at`),
    KEY `idx_ol_success` (`success`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '操作日志表';

-- -----------------------------------------------------------------------------
-- 11. announcement 公告表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `announcement` (
    `id`           BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `title`        VARCHAR(100) NOT NULL                COMMENT '标题',
    `content`      TEXT         NOT NULL                COMMENT '正文（支持纯文本 / 简单 HTML）',
    `type`         VARCHAR(20)  NOT NULL DEFAULT 'SCHOOL' COMMENT '类型：SCHOOL 学校公告 / CLASS 班级公告 / SYSTEM 系统公告',
    `target_role`  VARCHAR(20)  NOT NULL DEFAULT 'ALL'  COMMENT '可见角色：ALL / STUDENT / TEACHER / ADMIN',
    `class_id`     BIGINT                DEFAULT NULL   COMMENT '班级公告对应的 class.id，可空',
    `publisher_id` BIGINT                DEFAULT NULL   COMMENT '发布人 user.id',
    `top`          TINYINT      NOT NULL DEFAULT 0      COMMENT '是否置顶：1 是',
    `status`       VARCHAR(20)  NOT NULL DEFAULT 'PUBLISHED' COMMENT '状态：DRAFT 草稿 / PUBLISHED 已发布',
    `publish_time` DATETIME              DEFAULT NULL   COMMENT '发布时间',
    `created_by`   BIGINT                DEFAULT NULL   COMMENT '创建人',
    `updated_by`   BIGINT                DEFAULT NULL   COMMENT '更新人',
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`      TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_an_type` (`type`),
    KEY `idx_an_target_role` (`target_role`),
    KEY `idx_an_class` (`class_id`),
    KEY `idx_an_publish_time` (`publish_time`),
    KEY `idx_an_top` (`top`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '公告表';

-- -----------------------------------------------------------------------------
-- 12. appeal 积分申诉表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `appeal` (
    `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `student_id`      BIGINT       NOT NULL                COMMENT '申诉学生 student.id',
    `quant_record_id` BIGINT                DEFAULT NULL   COMMENT '被申诉的积分记录 quant_record.id',
    `reason`          VARCHAR(500) NOT NULL                COMMENT '申诉理由',
    `status`          VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING 待处理 / APPROVED 同意 / REJECTED 驳回',
    `reply`           VARCHAR(500)          DEFAULT NULL   COMMENT '教师回复',
    `handler_id`      BIGINT                DEFAULT NULL   COMMENT '处理人 user.id',
    `handle_time`     DATETIME              DEFAULT NULL   COMMENT '处理时间',
    `created_by`      BIGINT                DEFAULT NULL   COMMENT '创建人',
    `updated_by`      BIGINT                DEFAULT NULL   COMMENT '更新人',
    `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`         TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_ap_student` (`student_id`),
    KEY `idx_ap_record` (`quant_record_id`),
    KEY `idx_ap_status` (`status`),
    KEY `idx_ap_created` (`created_at`),
    CONSTRAINT `fk_ap_student` FOREIGN KEY (`student_id`) REFERENCES `student` (`id`),
    CONSTRAINT `fk_ap_record` FOREIGN KEY (`quant_record_id`) REFERENCES `quant_record` (`id`) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '积分申诉表';

-- -----------------------------------------------------------------------------
-- 13. import_log 学生名单导入日志表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `import_log` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `file_name`     VARCHAR(255) NOT NULL                COMMENT '原始文件名',
    `file_size`     BIGINT       NOT NULL DEFAULT 0      COMMENT '文件大小（字节）',
    `total_count`   INT          NOT NULL DEFAULT 0      COMMENT '总行数',
    `success_count` INT          NOT NULL DEFAULT 0      COMMENT '成功条数',
    `fail_count`    INT          NOT NULL DEFAULT 0      COMMENT '失败条数',
    `skip_count`    INT          NOT NULL DEFAULT 0      COMMENT '跳过条数',
    `update_count`  INT          NOT NULL DEFAULT 0      COMMENT '更新条数',
    `status`        VARCHAR(20)  NOT NULL DEFAULT 'SUCCESS' COMMENT '状态：SUCCESS / PARTIAL 部分成功 / FAILED',
    `strategy`      VARCHAR(20)           DEFAULT NULL   COMMENT '导入策略：SKIP / UPDATE / ABORT',
    `error_report`  TEXT                                 COMMENT '错误报告（JSON 数组，含行号与原因）',
    `operator_id`   BIGINT                DEFAULT NULL   COMMENT '操作人 user.id',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '导入时间',
    PRIMARY KEY (`id`),
    KEY `idx_il_operator` (`operator_id`),
    KEY `idx_il_created` (`created_at`),
    KEY `idx_il_status` (`status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '导入日志表';

-- -----------------------------------------------------------------------------
-- 14. captcha_log hCaptcha 校验日志表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `captcha_log` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `account`       VARCHAR(100)          DEFAULT NULL   COMMENT '账号 / 邮箱',
    `email`         VARCHAR(100)          DEFAULT NULL   COMMENT '邮箱',
    `ip`            VARCHAR(50)           DEFAULT NULL   COMMENT '请求 IP',
    `scene`         VARCHAR(50)           DEFAULT NULL   COMMENT '场景：REGISTER / LOGIN / SEND_EMAIL / RESET_PASSWORD / CHANGE_PASSWORD / BIND_EMAIL',
    `success`       TINYINT      NOT NULL DEFAULT 0      COMMENT '是否通过：1 通过 / 0 失败',
    `error_code`    VARCHAR(100)          DEFAULT NULL   COMMENT 'hCaptcha 返回的错误码',
    `error_message` VARCHAR(255)          DEFAULT NULL   COMMENT '错误说明',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '时间',
    PRIMARY KEY (`id`),
    KEY `idx_cl_account` (`account`),
    KEY `idx_cl_email` (`email`),
    KEY `idx_cl_ip` (`ip`),
    KEY `idx_cl_scene` (`scene`),
    KEY `idx_cl_created` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = 'hCaptcha 校验日志表';

-- =============================================================================
-- 三、扩展表（RBAC / 配置 / 通知 / 黑名单 / 限流 / 文件）
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 15. role 角色表（RBAC 扩展，基础权限仍由 user.role 字段驱动，二者可并存）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `role` (
    `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `role_code`   VARCHAR(50)  NOT NULL                COMMENT '角色编码：STUDENT / TEACHER / ADMIN',
    `role_name`   VARCHAR(50)  NOT NULL                COMMENT '角色名称：学生 / 教师 / 管理员',
    `description` VARCHAR(255)          DEFAULT NULL   COMMENT '描述',
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`     TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_role_code` (`role_code`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '角色表';

-- -----------------------------------------------------------------------------
-- 16. permission 权限表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `permission` (
    `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `perm_code`   VARCHAR(100) NOT NULL                COMMENT '权限编码，如 user:list',
    `perm_name`   VARCHAR(50)  NOT NULL                COMMENT '权限名称',
    `perm_type`   VARCHAR(20)  NOT NULL DEFAULT 'API'  COMMENT '类型：MENU / BUTTON / API',
    `parent_id`   BIGINT                DEFAULT 0      COMMENT '父级 id，0 为顶级',
    `path`        VARCHAR(255)          DEFAULT NULL   COMMENT '菜单路径',
    `sort_order`  INT          NOT NULL DEFAULT 0      COMMENT '排序号',
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`     TINYINT      NOT NULL DEFAULT 0      COMMENT '软删除标记',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_perm_code` (`perm_code`),
    KEY `idx_perm_parent` (`parent_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '权限表';

-- -----------------------------------------------------------------------------
-- 17. role_permission 角色权限关联表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `role_permission` (
    `id`      BIGINT   NOT NULL AUTO_INCREMENT COMMENT '主键',
    `role_id` BIGINT   NOT NULL                COMMENT '角色 id',
    `perm_id` BIGINT   NOT NULL                COMMENT '权限 id',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_role_perm` (`role_id`, `perm_id`),
    CONSTRAINT `fk_rp_role` FOREIGN KEY (`role_id`) REFERENCES `role` (`id`),
    CONSTRAINT `fk_rp_perm` FOREIGN KEY (`perm_id`) REFERENCES `permission` (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '角色权限关联表';

-- -----------------------------------------------------------------------------
-- 18. user_role 用户角色关联表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_role` (
    `id`         BIGINT   NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`    BIGINT   NOT NULL                COMMENT '用户 id',
    `role_id`    BIGINT   NOT NULL                COMMENT '角色 id',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_role` (`user_id`, `role_id`),
    CONSTRAINT `fk_ur_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`),
    CONSTRAINT `fk_ur_role` FOREIGN KEY (`role_id`) REFERENCES `role` (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '用户角色关联表';

-- -----------------------------------------------------------------------------
-- 19. system_config 系统配置表（管理员后台「系统设置」持久化）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `system_config` (
    `id`           BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `config_key`   VARCHAR(100) NOT NULL                COMMENT '配置键',
    `config_value` TEXT                                 COMMENT '配置值',
    `remark`       VARCHAR(255)          DEFAULT NULL   COMMENT '说明',
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '系统配置表';

-- -----------------------------------------------------------------------------
-- 20. email_template 邮件模板表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `email_template` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `template_code` VARCHAR(50)  NOT NULL                COMMENT '模板编码：REGISTER / RESET_PASSWORD / BIND_EMAIL / CHANGE_PASSWORD / WELCOME',
    `template_name` VARCHAR(50)  NOT NULL                COMMENT '模板名称',
    `subject`       VARCHAR(200) NOT NULL                COMMENT '邮件主题',
    `content`       TEXT         NOT NULL                COMMENT '邮件正文（HTML，占位符 ${code} ${schoolName} ${expireMinutes} ${time}）',
    `enabled`       TINYINT      NOT NULL DEFAULT 1      COMMENT '是否启用',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_et_code` (`template_code`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '邮件模板表';

-- -----------------------------------------------------------------------------
-- 21. notification 站内通知表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `notification` (
    `id`         BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`    BIGINT       NOT NULL                COMMENT '接收人 user.id',
    `title`      VARCHAR(200) NOT NULL                COMMENT '标题',
    `content`    TEXT                                 COMMENT '内容',
    `type`       VARCHAR(20)  NOT NULL DEFAULT 'SYSTEM' COMMENT '类型：SYSTEM / APPEAL / POINTS',
    `read_flag`  TINYINT      NOT NULL DEFAULT 0      COMMENT '是否已读：1 已读',
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_nt_user` (`user_id`),
    KEY `idx_nt_read` (`read_flag`),
    KEY `idx_nt_created` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '站内通知表';

-- -----------------------------------------------------------------------------
-- 22. token_blacklist JWT 黑名单表（退出登录 / 强制下线）
--     开启 Redis 时优先写 Redis，本表作为降级与留档
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `token_blacklist` (
    `id`         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
    `jti`        VARCHAR(64) NOT NULL                COMMENT 'JWT 唯一标识',
    `user_id`    BIGINT               DEFAULT NULL   COMMENT '用户 id',
    `expire_at`  DATETIME    NOT NULL                COMMENT '原 token 过期时间',
    `created_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入黑名单时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_tb_jti` (`jti`),
    KEY `idx_tb_expire` (`expire_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = 'JWT 黑名单表';

-- -----------------------------------------------------------------------------
-- 23. login_fail_record 登录失败记录表（防暴力破解）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `login_fail_record` (
    `id`            BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
    `account`       VARCHAR(100) NOT NULL               COMMENT '账号 / 邮箱',
    `ip`            VARCHAR(50)          DEFAULT NULL   COMMENT '最近失败 IP',
    `fail_count`    INT         NOT NULL DEFAULT 0      COMMENT '连续失败次数',
    `locked_until`  DATETIME             DEFAULT NULL   COMMENT '锁定截止时间',
    `last_fail_time` DATETIME            DEFAULT NULL   COMMENT '最近失败时间',
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lfr_account` (`account`),
    KEY `idx_lfr_locked` (`locked_until`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '登录失败记录表';

-- -----------------------------------------------------------------------------
-- 24. file_upload 文件上传记录表
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `file_upload` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `original_name` VARCHAR(255) NOT NULL                COMMENT '原始文件名',
    `stored_name`   VARCHAR(255) NOT NULL                COMMENT '存储文件名',
    `file_path`     VARCHAR(500) NOT NULL                COMMENT '存储路径',
    `file_size`     BIGINT       NOT NULL DEFAULT 0      COMMENT '文件大小',
    `content_type`  VARCHAR(100)          DEFAULT NULL   COMMENT 'MIME 类型',
    `uploader_id`   BIGINT                DEFAULT NULL   COMMENT '上传人 user.id',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上传时间',
    PRIMARY KEY (`id`),
    KEY `idx_fu_uploader` (`uploader_id`),
    KEY `idx_fu_created` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '文件上传记录表';

-- -----------------------------------------------------------------------------
-- 25. rate_limit_record 限流记录表（无 Redis 时的降级存储，开启 Redis 时不用）
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rate_limit_record` (
    `id`            BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
    `limit_key`     VARCHAR(200) NOT NULL               COMMENT '限流键：接口 + IP / 邮箱',
    `window_start`  DATETIME    NOT NULL                COMMENT '窗口开始时间',
    `request_count` INT         NOT NULL DEFAULT 0      COMMENT '窗口内请求次数',
    `created_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_rlr_key_window` (`limit_key`, `window_start`),
    KEY `idx_rlr_created` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '限流记录表';

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 四、默认数据
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1 默认用户
--     密码均为 BCrypt（$2b$12$…）加密后的结果，可用 Spring Security 的
--     BCryptPasswordEncoder.matches(明文, 密文) 校验：
--       admin    / Admin@123    （管理员，must_change_password = 1，首次登录强制改密）
--       teacher01/ Teacher@123  （教师，班主任）
--       student01~04 / Student@123（高一(1)班学生）
--       student05~06 / Student@123（高一(2)班学生，用于验证「学生不能看别班」）
-- -----------------------------------------------------------------------------
INSERT INTO `user`
(`id`, `username`, `password`, `email`, `phone`, `role`, `status`, `must_change_password`, `remark`)
VALUES
(1, 'admin', '$2b$12$kDL1fUoaSqKJ225xwB1cIOWev/dKu4Q1g4QvrGxwzy4FCHprQa83m', 'admin@school.com', '13800000001', 'ADMIN', 'ENABLED', 1, '系统默认管理员，首次登录必须修改密码'),
(2, 'teacher01', '$2b$12$3kz5BHb6b/u0WzSOYuNtBureDHJJUwxxmAHjlYWZwayTjnxeImKhS', 'teacher@school.com', '13800000002', 'TEACHER', 'ENABLED', 0, '演示教师账号'),
(3, 'student01', '$2b$12$AJG.OQEoANwIFvmPS1PNGOYzun7ujjkCU4UPCKBwh6gCFzWNx0rca', 'student1@school.com', '13800000003', 'STUDENT', 'ENABLED', 0, '演示学生账号'),
(4, 'student02', '$2b$12$AJG.OQEoANwIFvmPS1PNGOYzun7ujjkCU4UPCKBwh6gCFzWNx0rca', 'student2@school.com', '13800000004', 'STUDENT', 'ENABLED', 0, '演示学生账号'),
(5, 'student03', '$2b$12$AJG.OQEoANwIFvmPS1PNGOYzun7ujjkCU4UPCKBwh6gCFzWNx0rca', 'student3@school.com', '13800000005', 'STUDENT', 'ENABLED', 0, '演示学生账号'),
(6, 'student04', '$2b$12$AJG.OQEoANwIFvmPS1PNGOYzun7ujjkCU4UPCKBwh6gCFzWNx0rca', 'student4@school.com', '13800000006', 'STUDENT', 'ENABLED', 0, '演示学生账号'),
(7, 'student05', '$2b$12$AJG.OQEoANwIFvmPS1PNGOYzun7ujjkCU4UPCKBwh6gCFzWNx0rca', 'student5@school.com', '13800000007', 'STUDENT', 'ENABLED', 0, '高一(2)班演示学生，用于越权测试'),
(8, 'student06', '$2b$12$AJG.OQEoANwIFvmPS1PNGOYzun7ujjkCU4UPCKBwh6gCFzWNx0rca', 'student6@school.com', '13800000008', 'STUDENT', 'ENABLED', 0, '高一(2)班演示学生，用于越权测试');

-- -----------------------------------------------------------------------------
-- 4.2 默认教师
-- -----------------------------------------------------------------------------
INSERT INTO `teacher` (`id`, `user_id`, `teacher_no`, `name`, `phone`, `status`, `created_by`)
VALUES (1, 2, 'T2024001', '张老师', '13800000002', 'ENABLED', 1);

-- -----------------------------------------------------------------------------
-- 4.3 默认班级
-- -----------------------------------------------------------------------------
INSERT INTO `class` (`id`, `name`, `grade`, `head_teacher_id`, `description`, `status`, `created_by`)
VALUES
(1, '高一(1)班', '高一', 1,    '演示班级，班主任为张老师', 'ENABLED', 1),
(2, '高一(2)班', '高一', NULL, '演示班级，暂无班主任，用于权限隔离测试', 'ENABLED', 1);

-- -----------------------------------------------------------------------------
-- 4.4 班级-教师关联
-- -----------------------------------------------------------------------------
INSERT INTO `class_teacher` (`id`, `class_id`, `teacher_id`, `is_head`)
VALUES (1, 1, 1, 1);

-- -----------------------------------------------------------------------------
-- 4.5 默认学生
-- -----------------------------------------------------------------------------
INSERT INTO `student` (`id`, `user_id`, `student_no`, `name`, `gender`, `class_id`, `phone`, `status`, `created_by`)
VALUES
(1, 3, '20240101', '李明', '男', 1, '13800000003', 'ENABLED', 1),
(2, 4, '20240102', '王芳', '女', 1, '13800000004', 'ENABLED', 1),
(3, 5, '20240103', '赵磊', '男', 1, '13800000005', 'ENABLED', 1),
(4, 6, '20240104', '陈静', '女', 1, '13800000006', 'ENABLED', 1),
(5, 7, '20240201', '孙浩', '男', 2, '13800000007', 'ENABLED', 1),
(6, 8, '20240202', '周婷', '女', 2, '13800000008', 'ENABLED', 1);

-- -----------------------------------------------------------------------------
-- 4.6 默认量化分类（11 类，覆盖加分 / 减分 / 加减分三种类型）
-- -----------------------------------------------------------------------------
INSERT INTO `quant_category` (`id`, `name`, `type`, `default_score`, `description`, `status`, `sort_order`, `created_by`)
VALUES
(1,  '纪律',     'BOTH',     2,  '课堂纪律、集会纪律、两操纪律等',           'ENABLED', 1,  1),
(2,  '卫生',     'BOTH',     2,  '教室卫生、包干区卫生、个人卫生等',         'ENABLED', 2,  1),
(3,  '学习',     'ADD',      3,  '作业完成、考试成绩、竞赛获奖等',           'ENABLED', 3,  1),
(4,  '活动',     'ADD',      2,  '学校活动、班级活动、社会实践等',           'ENABLED', 4,  1),
(5,  '违纪',     'SUBTRACT', 5,  '迟到早退、打架斗殴、破坏公物等违纪行为',   'ENABLED', 5,  1),
(6,  '考勤',     'BOTH',     1,  '出勤、请假、旷课等考勤相关',               'ENABLED', 6,  1),
(7,  '宿舍',     'BOTH',     2,  '宿舍卫生、就寝纪律、晚归等',               'ENABLED', 7,  1),
(8,  '体育',     'ADD',      2,  '体育课表现、运动会、体育竞赛等',           'ENABLED', 8,  1),
(9,  '艺术',     'ADD',      2,  '文艺演出、书画比赛、社团活动等',           'ENABLED', 9,  1),
(10, '志愿服务', 'ADD',      3,  '志愿服务、公益活动、好人好事等',           'ENABLED', 10, 1),
(11, '其他',     'BOTH',     1,  '其他需要记录的量化事项',                   'ENABLED', 11, 1);

-- -----------------------------------------------------------------------------
-- 4.7 演示积分记录（便于登录后立即看到数据）
-- -----------------------------------------------------------------------------
INSERT INTO `quant_record`
(`student_id`, `class_id`, `category_id`, `score`, `reason`, `recorder_id`, `record_time`, `status`, `remark`, `created_by`)
VALUES
(1, 1, 3,  3,  '数学单元测试班级第一名',       2, NOW() - INTERVAL 3 DAY, 'NORMAL', NULL, 2),
(1, 1, 2,  2,  '本周教室卫生检查优秀',         2, NOW() - INTERVAL 2 DAY, 'NORMAL', NULL, 2),
(1, 1, 6, -1,  '早读迟到一次',                 2, NOW() - INTERVAL 1 DAY, 'NORMAL', NULL, 2),
(2, 1, 4,  2,  '参加校运动会志愿服务',         2, NOW() - INTERVAL 2 DAY, 'NORMAL', NULL, 2),
(2, 1, 3,  3,  '语文作文获校级优秀',           2, NOW() - INTERVAL 1 DAY, 'NORMAL', NULL, 2),
(3, 1, 5, -5,  '上课期间使用手机，违反校规',   2, NOW() - INTERVAL 2 DAY, 'NORMAL', '已通知家长', 2),
(3, 1, 1,  2,  '本周课堂纪律表现良好',         2, NOW() - INTERVAL 1 DAY, 'NORMAL', NULL, 2),
(4, 1, 8,  2,  '体育课表现积极',               2, NOW() - INTERVAL 1 DAY, 'NORMAL', NULL, 2),
(4, 1, 10, 3,  '参加社区志愿服务',             2, NOW(),                  'NORMAL', NULL, 2),
(5, 2, 3,  3,  '期中考试进步明显',             1, NOW() - INTERVAL 1 DAY, 'NORMAL', NULL, 1),
(6, 2, 2,  2,  '卫生值日认真负责',             1, NOW() - INTERVAL 1 DAY, 'NORMAL', NULL, 1);

-- -----------------------------------------------------------------------------
-- 4.8 演示公告
-- -----------------------------------------------------------------------------
INSERT INTO `announcement`
(`id`, `title`, `content`, `type`, `target_role`, `class_id`, `publisher_id`, `top`, `status`, `publish_time`, `created_by`)
VALUES
(1, '关于本周量化积分公示的通知',
 '各位同学：本周量化积分已录入完毕，请登录系统在「个人积分明细」中核对。如有异议，请在「我的申诉」中提交申诉，班主任将在 3 个工作日内处理。',
 'SCHOOL', 'ALL', NULL, 1, 1, 'PUBLISHED', NOW() - INTERVAL 1 DAY, 1),
(2, '高一(1)班班级卫生安排',
 '本周卫生值日表已更新，请各值日小组按时完成包干区清扫，卫生检查结果将计入量化积分。',
 'CLASS', 'STUDENT', 1, 2, 0, 'PUBLISHED', NOW() - INTERVAL 6 HOUR, 2);

-- -----------------------------------------------------------------------------
-- 4.9 演示申诉
-- -----------------------------------------------------------------------------
INSERT INTO `appeal` (`id`, `student_id`, `quant_record_id`, `reason`, `status`, `created_by`)
VALUES (1, 3, 6, '当天因身体不适前往医务室，已向老师请假，并非无故使用手机，申请撤销该条扣分。', 'PENDING', 5);

-- -----------------------------------------------------------------------------
-- 4.10 系统配置初始值
-- -----------------------------------------------------------------------------
INSERT INTO `system_config` (`config_key`, `config_value`, `remark`)
VALUES
('site.name',            '校园班级量化积分管理系统', '站点名称'),
('school.name',          '示范中学',               '学校名称'),
('points.rule',          '量化积分由班主任及各科教师根据学生日常表现录入，加分项与减分项均需注明原因；学生可在 3 个工作日内提出申诉。', '积分规则说明'),
('import.max.size.mb',   '10',                     '导入文件最大体积（MB）'),
('import.preview.size',  '100',                    '导入预览条数'),
('hcaptcha.enabled',     'true',                   'hCaptcha 开关（true 时必须通过人机校验，仅开发环境可临时关闭）'),
('register.teacher.audit','true',                  '教师注册是否需要管理员审核'),
('login.max.fail',       '5',                      '登录连续失败锁定次数'),
('login.lock.minutes',   '10',                     '登录锁定分钟数');

-- -----------------------------------------------------------------------------
-- 4.11 邮件模板初始值（占位符：${schoolName} ${code} ${expireMinutes} ${time}）
-- -----------------------------------------------------------------------------
INSERT INTO `email_template` (`template_code`, `template_name`, `subject`, `content`, `enabled`)
VALUES
('REGISTER', '注册验证码',
 '【${schoolName}】注册验证码',
 '<div style="font-family:Microsoft YaHei,Arial,sans-serif;font-size:14px;color:#333;line-height:1.8">'
 '<p>您好，欢迎使用 <b>${schoolName}</b> 校园班级量化积分管理系统。</p>'
 '<p>您的注册验证码是：</p>'
 '<p style="font-size:26px;font-weight:bold;color:#1677ff;letter-spacing:6px">${code}</p>'
 '<p>验证码 ${expireMinutes} 分钟内有效，请勿泄露给他人。若非本人操作，请忽略本邮件。</p>'
 '<p style="color:#999">发件时间：${time}</p></div>', 1),
('RESET_PASSWORD', '找回密码验证码',
 '【${schoolName}】找回密码验证码',
 '<div style="font-family:Microsoft YaHei,Arial,sans-serif;font-size:14px;color:#333;line-height:1.8">'
 '<p>您正在申请重置 <b>${schoolName}</b> 量化积分管理系统的登录密码。</p>'
 '<p>您的验证码是：</p>'
 '<p style="font-size:26px;font-weight:bold;color:#fa541c;letter-spacing:6px">${code}</p>'
 '<p>验证码 ${expireMinutes} 分钟内有效。如非本人操作，请立即联系管理员。</p>'
 '<p style="color:#999">发件时间：${time}</p></div>', 1),
('BIND_EMAIL', '绑定邮箱验证码',
 '【${schoolName}】绑定邮箱验证码',
 '<div style="font-family:Microsoft YaHei,Arial,sans-serif;font-size:14px;color:#333;line-height:1.8">'
 '<p>您正在为账号绑定邮箱，验证码为：</p>'
 '<p style="font-size:26px;font-weight:bold;color:#52c41a;letter-spacing:6px">${code}</p>'
 '<p>验证码 ${expireMinutes} 分钟内有效，请勿泄露给他人。</p>'
 '<p style="color:#999">发件时间：${time}</p></div>', 1),
('CHANGE_PASSWORD', '修改密码验证码',
 '【${schoolName}】修改密码验证码',
 '<div style="font-family:Microsoft YaHei,Arial,sans-serif;font-size:14px;color:#333;line-height:1.8">'
 '<p>您正在修改登录密码，验证码为：</p>'
 '<p style="font-size:26px;font-weight:bold;color:#722ed1;letter-spacing:6px">${code}</p>'
 '<p>验证码 ${expireMinutes} 分钟内有效。如非本人操作，请立即联系管理员。</p>'
 '<p style="color:#999">发件时间：${time}</p></div>', 1),
('WELCOME', '注册欢迎邮件',
 '【${schoolName}】欢迎使用量化积分管理系统',
 '<div style="font-family:Microsoft YaHei,Arial,sans-serif;font-size:14px;color:#333;line-height:1.8">'
 '<p>您好，您的账号已注册成功。</p>'
 '<p>登录账号：您的邮箱地址；登录后可在「个人中心」查看本班量化积分、个人明细与班级排名。</p>'
 '<p style="color:#999">发信时间：${time}</p></div>', 1);

-- -----------------------------------------------------------------------------
-- 4.12 RBAC 基础角色与权限（与 user.role 字段并存，供后续细粒度扩展）
-- -----------------------------------------------------------------------------
INSERT INTO `role` (`id`, `role_code`, `role_name`, `description`)
VALUES
(1, 'STUDENT', '学生', '查看本班积分、个人明细、排名，提交申诉'),
(2, 'TEACHER', '教师', '管理自己负责班级的量化积分与申诉'),
(3, 'ADMIN',   '管理员', '拥有系统全部权限');

INSERT INTO `permission` (`id`, `perm_code`, `perm_name`, `perm_type`, `parent_id`, `path`, `sort_order`)
VALUES
(1,  'student:view',   '学生端访问',   'MENU',   0, '/student/index.html', 1),
(2,  'teacher:view',   '教师端访问',   'MENU',   0, '/teacher/index.html', 2),
(3,  'admin:view',     '管理后台访问', 'MENU',   0, '/admin/index.html',   3),
(4,  'user:manage',    '用户管理',     'BUTTON', 3, NULL, 10),
(5,  'class:manage',   '班级管理',     'BUTTON', 3, NULL, 11),
(6,  'import:manage',  '名单导入',     'BUTTON', 3, NULL, 12),
(7,  'quant:manage',   '量化分类管理', 'BUTTON', 3, NULL, 13),
(8,  'record:manage',  '积分记录管理', 'BUTTON', 3, NULL, 14),
(9,  'announce:manage','公告管理',     'BUTTON', 3, NULL, 15),
(10, 'log:view',       '日志查看',     'BUTTON', 3, NULL, 16),
(11, 'points:record',  '积分录入',     'BUTTON', 2, NULL, 20),
(12, 'appeal:audit',   '申诉审核',     'BUTTON', 2, NULL, 21),
(13, 'points:query',   '积分查询',     'BUTTON', 1, NULL, 30),
(14, 'appeal:submit',  '提交申诉',     'BUTTON', 1, NULL, 31);

INSERT INTO `role_permission` (`role_id`, `perm_id`)
VALUES
(1, 1), (1, 13), (1, 14),
(2, 2), (2, 11), (2, 12), (2, 13),
(3, 3), (3, 4), (3, 5), (3, 6), (3, 7), (3, 8), (3, 9), (3, 10);

INSERT INTO `user_role` (`user_id`, `role_id`)
VALUES (1, 3), (2, 2), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1);

-- =============================================================================
-- 初始化完成
-- 默认账号：
--   管理员  admin@school.com  / Admin@123   （首次登录强制修改密码）
--   教师    teacher@school.com / Teacher@123
--   学生    student1@school.com / Student@123（其余学生 student2~6 密码相同）
-- 安全提示：
--   1) 首次登录后请立即修改默认密码；
--   2) 生产环境请删除或禁用演示账号（student05 / student06 等）。
-- =============================================================================
