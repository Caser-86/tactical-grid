# 第三方通知 (Third Party Notices)

> status: Active compliance record
> updated: 2026-07-30
> applies_to: 源码仓库；正式发布包仍需生成不可变通知副本

## 1. Godot Engine

- 组件：Godot Engine 4.7.1 stable。
- 用途：编辑器和导出游戏运行时。
- 项目许可：MIT License。
- 官方网站：https://godotengine.org
- 源码：https://github.com/godotengine/godot

正式分发必须提供：

1. Godot MIT 许可证文本。
2. 与实际导出所用 Godot 二进制对应的 `COPYRIGHT.txt`，覆盖引擎所含第三方组件。
3. 在游戏内可访问的许可证入口，或随包附带清楚可见的文本文件。

官方合规说明：
https://docs.godotengine.org/en/stable/about/complying_with_licenses.html

当前仓库尚未把上述文件复制到 Windows 发布目录，因此这是发布阻断项。

## 2. 默认字体

当前 UI 主要依赖 Godot 随运行时提供的默认嵌入字体。项目不再将该字体笼统标记为 MIT。

正式通知应以实际 Godot 4.7.1 构建附带的 `COPYRIGHT.txt` 为准。若后续引入独立简体中文字体，必须记录字体名称、作者、来源 URL、许可证版本、是否修改和随包许可证文本。

## 3. Node 开发工具

`tactical-grid/server` 是开发期地图/API 工具，不是玩家客户端运行依赖，默认不随 Windows 游戏包分发。

直接依赖和开发依赖以：

- `tactical-grid/server/package.json`
- `tactical-grid/server/package-lock.json`

为版本权威。许可证不能靠手写“全部 MIT”推断。若发布任何服务端或工具二进制，必须从锁文件和实际安装树生成完整第三方许可证清单，并人工处理未知、双重许可或需要附带文本的包。

本轮未安装服务端依赖，无法重新生成依赖许可证报告。

## 4. 游戏美术与音频

当前正式候选资源仅允许：

- 项目自行创作。
- 项目脚本程序化生成。
- 使用内置 Image Generation 生成并由项目处理。
- 许可证明确允许目标商用、修改和分发的外部资源。

逐项来源、修改、用途和验证记录见：

`tactical-grid/client/data/RESOURCE_MANIFEST.md`

没有清单记录、来源不明、带水印或许可证无法确认的资源不得进入发布包。

## 5. 开发工具

Git、Node.js、npm、Godot 编辑器和图像/音频处理工具属于开发环境。只有实际复制进玩家包的组件才进入发布通知，但生成记录仍应保留以支持追溯。

## 6. 发布前合规门

- [ ] Godot MIT 文本随包。
- [ ] 对应 Godot 构建的 `COPYRIGHT.txt` 随包。
- [ ] 正式中文字体许可证随包。
- [ ] 资源清单没有路径重叠、未知来源或未接入资源冒充完成。
- [ ] 若分发 Node 工具，生成锁文件级依赖通知。
- [ ] 发布目录包含本文件、`PRIVACY.md`、资源清单和 SHA-256 清单。

## 7. 变更记录

- 2026-07-27：初次建立通知清单。
- 2026-07-30：修正默认字体和 Node 许可证宣称，增加 Godot `COPYRIGHT.txt` 与发布包合规门。
