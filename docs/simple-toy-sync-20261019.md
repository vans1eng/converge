# simple-toy 关卡同步（2026-10-19）

逐关对比 `/Users/fansheng/Desktop/hexnum/simple-toy/levels/1-1.json` 至 `1-23.json`。
除导入来源标记外，21 关数据一致；本次更新 `1-9` 和 `1-23`。

- `1-9`：同步名称、教程、规则版本及完整砖块数据。
- `1-23`：同步固定线索、候选答案、数字、范围半径、隐藏和永久隐藏状态；移除已过期的“尚无可见数字线索”备注。

两关来源记录为 `simple-toy-sync:<编号>`，原始来源快照保存在
`resources/levels/archive/simple-toy-sync-20261019/`。

验证：全部 23 关与来源逐字段一致（仅 source_id 保留 Godot 导入来源）；
Godot 4.7 无界面运行，全部 23 关通过 LevelLoader 加载与 LevelValidator 结构、答案数字一致性校验。

本次仅更新上述关卡、对应来源记录和同步文档；保留现有关卡顺序、进度迁移及游戏模式设置。
