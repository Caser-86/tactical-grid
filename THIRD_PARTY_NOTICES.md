# 第三方通知 (Third Party Notices)

本文件列出 Tactical Grid 项目使用的第三方软件、库和资源及其许可证。

## 1. 游戏引擎

### Godot Engine
- 版本：4.7.1 stable
- 许可证：MIT License
- 官网：https://godotengine.org
- 用途：游戏客户端运行时和编辑器
- 来源：https://github.com/godotengine/godot
- 说明：Godot Engine 自身以 MIT 许可证发布，允许商业使用、修改和分发。导出的游戏包不附带 Godot 编辑器代码，仅嵌入运行时。

## 2. 服务端依赖（Node.js）

服务端为开发期工具，不随玩家发布包分发。以下依赖通过 npm 安装，许可证均允许内部使用：

| 包名 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| express | ^4.18.2 | MIT | HTTP 服务器框架 |
| cors | ^2.8.5 | MIT | 跨域请求支持 |
| bcryptjs | ^2.4.3 | MIT | 密码哈希 |
| jsonwebtoken | ^9.0.2 | MIT | JWT 认证 |
| sql.js | ^1.10.3 | MIT | SQLite WebAssembly 实现 |
| uuid | ^9.0.1 | MIT | UUID 生成 |
| zod | ^3.22.4 | MIT | 数据模式校验 |
| dotenv | ^16.4.1 | BSD-2-Clause | 环境变量加载 |
| morgan | ^1.10.0 | MIT | HTTP 请求日志 |
| helmet | ^7.1.0 | MIT | HTTP 安全头 |
| express-rate-limit | ^7.1.5 | MIT | 速率限制 |
| ws | ^8.16.0 | MIT | WebSocket 实现 |
| typescript | ^5.3.3 | Apache-2.0 | TypeScript 编译器 |
| tsx | ^4.7.1 | MIT | TypeScript 执行器 |
| jest | ^29.7.0 | MIT | 测试框架 |
| ts-jest | ^29.1.2 | MIT | Jest TypeScript 支持 |
| eslint | ^8.56.0 | MIT | 代码风格检查 |
| @typescript-eslint/* | ^7.0.0 | MIT | TypeScript ESLint 插件 |

## 3. 字体

当前游戏内文本使用 Godot 默认字体（Open Sans Embedded，随 Godot 引擎以 MIT 许可证分发）。
未来如引入第三方字体，必须在此处登记来源、作者、许可证和修改记录。

## 4. 数据格式与协议

- JSON：ECMA-404 标准，无许可证限制
- NDJSON：社区事实标准，无许可证限制

## 5. 工具链

| 工具 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| Node.js | 20.x | MIT | 服务端运行时 |
| npm | 10.x | MIT | 包管理器 |
| Git | 2.x | GPL-2.0 / GPL-3.0 | 版本控制（开发工具，不分发） |

## 6. 修改记录

- 2026-07-27：初次创建第三方通知清单
