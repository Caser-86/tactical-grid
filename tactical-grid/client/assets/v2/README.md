# V2 资源目录

V2 新增或复制后的资源放在本目录及其子目录中。资源必须在 V2 资源清单中记录来源、许可证、尺寸、导入设置和游戏内用途。

禁止从 V2 运行时通过相对路径读取 V1 worktree 的资源。

M1 美术整合约束：运行时角色、目标图标和 Echo Yard 环境组件统一由 `ArtCatalog` 查找，资源实际文件位于 `assets/generated/chapter1/runtime`。新增图像必须使用真实透明背景，标注处理尺寸，并在 `data/v2/resource_manifest.md` 登记来源和许可证结论。
