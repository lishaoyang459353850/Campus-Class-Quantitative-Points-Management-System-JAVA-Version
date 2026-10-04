# 校园班级量化积分管理系统

一套可直接部署运行的中小学班级量化积分管理系统，覆盖「管理员 — 教师 — 学生」三种角色，
实现量化分类维护、积分录入与审核、班级与学生排名、学生申诉、公告发布、Excel 批量导入导出、
操作日志留痕等完整闭环。

- 后端：Spring Boot 3.2.5 + Java 17 + MyBatis-Plus 3.5.7 + MySQL 8 + Redis（可选）
- 安全：Spring Security + JWT + BCrypt 密码加密 + hCaptcha 人机校验 + 自建 SMTP 邮件验证码
- 前端：原生 HTML / CSS / JavaScript（无框架、无构建步骤），ECharts 图表本地化，离线可用
- 打包产物：`target/school-points.jar`（内嵌 Tomcat，前端页面与静态资源全部打进 jar）

---

## 一、功能清单

### 1. 通用能力
- 统一响应体 `{code, message, data}`，统一异常处理与中文错误提示
- 统一分页参数：`page / size / keyword / role / classId / status / startTime / endTime`
- 登录态基于 JWT，支持「记住我」7 天；未登录跳登录页，越权跳 403 页面并记录安全日志
- 敏感操作（增删改、导入、重置密码、审核、导出等）通过 AOP 自动写入操作日志
- 文件上传与 Excel 导出统一走服务端生成，中文文件名不乱码

### 2. 注册 / 登录 / 账号安全
- 注册（学生 / 教师）、登录、找回密码、修改密码、绑定邮箱
- 以上所有操作**必须先通过 hCaptcha 人机校验**，校验失败写 hCaptcha 日志
- 邮箱验证码通过**自建 SMTP 服务器**发送（`spring-boot-starter-mail` + `JavaMailSender`），
  不使用任何第三方邮件 API；验证码 5 分钟有效，同一邮箱 60 秒内不可重发
- 密码 BCrypt 加密存储，长度至少 8 位且需包含字母与数字
- 默认管理员 `admin@school.com` / `Admin@123`，**首次登录强制修改密码**
- 连续登录失败 5 次锁定 10 分钟

### 3. 学生端
- 首页：个人总分、本班排名、最近积分变动
- 本班量化积分：班级汇总、分类占比图表（ECharts）
- 个人积分明细：按分类 / 时间筛选，查看每条加分减分事由
- 班级排名：名次、总分、加分合计、减分合计
- 我的申诉：对某条积分记录发起申诉，查看处理结果与教师回复
- 公告：查看面向学生的公告，支持置顶
- 个人中心：完善资料、绑定邮箱、修改密码

### 4. 教师端
- 首页看板：我负责的班级、学生总数、今日录入条数、待处理申诉
- 我的班级：班级列表、学生名单（仅限自己负责的班级）
- 积分录入：单条录入（班级 → 学生 → 分类 → 分值 → 事由 → 时间）
- 批量录入：一个班级勾选多名学生，一次写入同一事由的积分
- 积分记录：多条件筛选、修改、撤销、删除、导出 Excel
- 统计图表：汇总指标、分类占比饼图、近 7 天 / 近 6 个月趋势、学生排行
- 申诉审核：通过 / 驳回申诉，可同步撤销对应积分记录，支持导出

### 5. 管理员端
- 数据看板：用户 / 学生 / 教师 / 班级总数、今日记录与登录数、hCaptcha 失败数、
  全校积分合计、近 7 天趋势、分类占比
- 用户管理：多条件查询、启用 / 禁用、重置密码、修改角色、删除、导出
- 班级管理：班级增删改查、指定班主任、查看班级学生名单
- 学生导入：下载 Excel 模板 → 上传预览（区分可导入 / 错误行）→ 选择冲突策略执行导入 →
  查看导入历史与错误报告下载
- 量化分类：加分 / 减分 / 加减分三类分类的增删改查与启用禁用
- 量化记录：全校记录查询、审核（通过 / 驳回）、撤销、删除、导出
- 公告管理：发布 / 编辑 / 置顶 / 下线 / 删除，支持全校、班级、系统三类公告
- 日志中心：登录日志、操作日志、hCaptcha 日志，支持条件筛选与导出
- 回收站：用户、班级、积分记录、公告四类已删除数据的一键恢复
- 系统设置：业务参数在线维护（安全密钥仍走环境变量，不落数据库、不进前端）

---

## 二、目录结构

```
school-points-system/
├── pom.xml                      Maven 构建文件（Spring Boot 3.2.5 / Java 17）
├── Dockerfile                   生产镜像构建文件
├── docker-compose.yml           MySQL 8 + Redis + 应用 一键编排
├── .dockerignore
├── .env.example                 环境变量样例（复制为 .env 后填写真实值）
├── .gitignore                   已忽略 .env / target / logs / data 等敏感与临时目录
├── sql/
│   └── init.sql                 建库建表 + 初始数据（分类、管理员、示例班级）
├── target/
│   └── school-points.jar        编译产物（可执行 jar，内嵌 Tomcat 与前端页面）
└── src/main/
    ├── java/com/school/points/
    │   ├── SchoolPointsApplication.java   启动类
    │   ├── common/          统一响应、分页、常量、操作日志注解与切面
    │   ├── config/          应用配置、MyBatis-Plus、RestTemplate、WebMvc、OpenAPI
    │   ├── controller/      Auth / Common / Student / Teacher / Admin 五个入口
    │   ├── dto/ vo/         入参与出参对象
    │   ├── entity/ mapper/  数据库实体与 MyBatis-Plus Mapper
    │   ├── exception/       业务异常与全局异常处理
    │   ├── job/ listener/   定时任务、EasyExcel 导入监听器
    │   ├── security/        JWT 过滤器、登录用户、权限处理器、请求守卫拦截器
    │   ├── service/         业务接口与实现
    │   └── util/            工具类（IP、密码校验、Excel、JWT、脱敏、日期）
    └── resources/
        ├── application.yml           主配置（全部使用环境变量占位符）
        ├── application-dev.yml       开发环境
        ├── application-prod.yml      生产环境
        ├── logback-spring.xml        日志分级、滚动、脱敏
        ├── mapper/                   MyBatis XML
        └── static/                   前端页面（打包进 jar，随服务一起提供）
            ├── index.html  login.html  register.html  forgot.html  profile.html
            ├── 403.html  404.html     500.html
            ├── student/   学生端 7 个页面
            ├── teacher/   教师端 8 个页面
            ├── admin/     管理端 12 个页面
            ├── css/common.css
            ├── js/request.js  js/common.js  js/captcha.js
            └── lib/echarts.min.js        本地化图表库
```

---

## 三、默认账号

| 角色 | 账号 | 密码 | 说明 |
| --- | --- | --- | --- |
| 管理员 | `admin@school.com` | `Admin@123` | 首次登录强制修改密码 |
| 教师 | 由管理员创建或教师自行注册（需审核） | 初始密码 `12345678` | 首次登录强制修改密码 |
| 学生 | 由管理员 Excel 批量导入或自行注册 | 初始密码 `12345678` | 首次登录强制修改密码 |

> 教师注册默认需要管理员审核（`app.register.teacher-need-audit=true`），
> 审核前状态为 `PENDING` 无法登录，管理员在「用户管理」中把角色改为教师即可自动启用。

---

## 四、本机运行（开发调试）

1. 准备 MySQL 8 并创建数据库（或直接执行 `sql/init.sql`）：

```bash
mysql -uroot -p < sql/init.sql
```

2. 复制环境变量样例并填写真实值：

```bash
cp .env.example .env
```

3. 编译打包：

```bash
mvn clean package -DskipTests
```

4. 启动：

```bash
java -jar target/school-points.jar
```

5. 浏览器访问 `http://localhost:8080`，接口文档 `http://localhost:8080/swagger-ui/index.html`。

---

## 五、服务器部署（Ubuntu 22.04）

详细的傻瓜式步骤见同目录下的 `部署说明.md`。核心流程：

1. 安装 JDK 17、MySQL 8（Redis 可选）
2. 执行 `sql/init.sql` 建库建表
3. 导出环境变量（数据库密码、SMTP、hCaptcha、JWT 密钥）
4. `nohup java -jar school-points.jar &` 启动
5. 浏览器访问 `http://服务器IP:8080`，用 admin@school.com / Admin@123 登录并改密

推荐使用 Docker 一键部署（见 `部署说明.md` 方式二）：

```bash
docker compose up -d
```

---

## 六、必须配置的环境变量

| 变量 | 说明 | 是否必填 |
| --- | --- | --- |
| `DB_HOST` `DB_PORT` `DB_NAME` `DB_USERNAME` `DB_PASSWORD` | MySQL 连接信息 | 必填 |
| `MAIL_HOST` `MAIL_PORT` `MAIL_USERNAME` `MAIL_PASSWORD` `MAIL_FROM` | 自建 SMTP 服务器（465 用 SSL，587 用 STARTTLS） | 必填 |
| `HCAPTCHA_SITE_KEY` / `HCAPTCHA_SECRET_KEY` | hCaptcha 站点密钥与密钥（secret 只放后端） | 必填 |
| `JWT_SECRET` | JWT 签名密钥，至少 32 字节随机串 | 必填 |
| `REDIS_ENABLED` / `REDIS_HOST` / `REDIS_PORT` | Redis 开关与地址；关闭时自动降级为数据库模式 | 可选 |
| `SERVER_PORT` | 服务端口，默认 8080 | 可选 |
| `SPRING_PROFILES_ACTIVE` | `dev` 或 `prod` | 可选 |
| `LOG_LEVEL` / `LOG_PATH` | 日志级别与目录 | 可选 |

生成随机 JWT 密钥：

```bash
openssl rand -base64 48
```

---

## 七、验收用例（建议按顺序执行）

| 编号 | 用例 | 预期结果 |
| --- | --- | --- |
| 1 | 访问首页 | 未登录跳转登录页 |
| 2 | 用 admin@school.com / Admin@123 登录 | 登录成功并弹出「强制修改初始密码」弹窗 |
| 3 | 不完成改密直接操作 | 被强制弹窗阻断，无法继续 |
| 4 | 完成改密后重新登录 | 正常进入数据看板，看到统计卡片与图表 |
| 5 | 关闭 hCaptcha 勾选后提交登录 | 提示需先完成人机验证，且 hCaptcha 日志中新增失败记录 |
| 6 | 管理员新增班级并指定班主任 | 班级列表出现该班级，学生人数为 0 |
| 7 | 下载学生导入模板并填写 3 行数据（含 1 行错误） | 预览显示「可导入 2 行、错误 1 行」，错误行给出具体原因 |
| 8 | 选择「跳过已存在学号」执行导入 | 提示新增人数，导入历史新增一条记录，可下载错误报告 |
| 9 | 教师登录 | 只能看到自己负责的班级，看不到其他班级数据 |
| 10 | 教师单条录入积分 | 记录列表出现该条记录，学生总分同步变化 |
| 11 | 教师批量录入 5 名学生 | 一次生成 5 条记录 |
| 12 | 教师修改 / 撤销某条记录 | 撤销后该记录状态为「已撤销」，学生总分相应回退 |
| 13 | 学生登录查看个人明细 | 能看到刚才的记录，总分与教师端一致 |
| 14 | 学生对某条记录发起申诉 | 教师端「申诉审核」出现待处理申诉 |
| 15 | 教师通过申诉并勾选撤销记录 | 申诉状态变「已通过」，对应记录变为「已撤销」 |
| 16 | 教师访问其他班级学生名单接口 | 返回 403 并跳转 403 页面，操作日志/安全日志有记录 |
| 17 | 管理员发布置顶公告 | 学生端与教师端公告列表顶部显示该公告 |
| 18 | 管理员导出积分记录 | 下载 xlsx，中文表头与文件名正常 |
| 19 | 管理员删除一名学生后在回收站恢复 | 该学生重新出现在用户列表 |
| 20 | 管理员重置某用户密码 | 弹窗显示新密码，该用户下次登录被要求改密 |
| 21 | 登录日志 / 操作日志 / hCaptcha 日志 | 分别能看到刚才的登录、敏感操作与人机校验记录 |
| 22 | 发送邮箱验证码（绑定邮箱 / 找回密码） | 通过自建 SMTP 真实收到邮件，验证码 5 分钟内有效 |

---

## 八、安全说明

1. 所有敏感配置（数据库密码、SMTP 密码、JWT 密钥、hCaptcha secret）只通过环境变量注入，
   `application.yml` 中仅保留占位符，`.env` 已被 `.gitignore` 忽略，不会进入版本库。
2. hCaptcha 校验在后端调用 `https://api.hcaptcha.com/siteverify` 完成，secret 不出现在任何前端文件。
3. 密码使用 BCrypt 加密；日志对邮箱、手机号、密码、token 等字段做脱敏处理。
4. 越权访问统一返回 403，并写入安全日志；学生不可跨班查询，教师不可管理非本人班级。
5. 前端资源全部本地化（含 ECharts），页面运行期间唯一允许联网的外部脚本是 hCaptcha 官方 JS。
