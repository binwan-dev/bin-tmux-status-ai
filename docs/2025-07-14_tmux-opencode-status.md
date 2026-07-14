# tmux opencode 状态指示器 — 设计方案

## 需求理解

用户希望在 tmux 状态栏中展示 opencode 的运行状态，用图标和颜色区分不同状态，方便快速识别哪个窗口的 opencode 在等待、哪个已经完成。

核心需求：
- 检测当前 tmux window 中是否有 opencode 进程在运行
- 在状态栏显示 "oc" 标识 + 状态图标 + 颜色
- 区分「等待中」「运行中」「已完成」「异常」等状态

## 状态设计

| 状态 | 图标 | 颜色 | 含义 |
|------|------|------|------|
| `running` | ⚡ | 蓝色 | opencode 正在活跃执行（进程状态 R） |
| `waiting` | ⏳ | 黄色 | opencode 在等待用户输入（进程状态 S，CPU 低） |
| `done` | ✓ | 绿色 | opencode 最近运行过，现已退出 |
| `error` | ✗ | 红色 | opencode 进程异常退出 |
| `none` | — | 无 | 没有 opencode 活动 |

## 检测机制

1. **进程检测**：通过 `pgrep -f "opencode"` 查找 opencode 进程
2. **状态区分**：通过 `/proc/<pid>/stat` 读取进程状态（R=运行, S=睡眠等待）
3. **完成检测**：使用 `/tmp/tmux_opencode_<window_id>` 标记文件记录上次状态，进程消失后判定为「已完成」
4. **异常检测**：检查标记文件中的退出码，非零则为 error

## 项目结构

```
bin-tmux-status-ai/
├── opencode.tmux              # 插件入口（TPM 兼容）
├── scripts/
│   └── opencode_status.sh     # 核心状态检测脚本
└── docs/
```

## 实现要点

- 纯 Shell 实现，零外部依赖
- 兼容 TPM (Tmux Plugin Manager)
- 脚本输出 tmux 格式字符串（含颜色 code）
- 通过 `#(scripts/opencode_status.sh)` 嵌入 status-right
- 阈值：CPU 使用率 < 5% 且状态为 S 判定为 waiting

## 颜色方案

```
running:  #[fg=blue,bold]   ⚡ oc
waiting:  #[fg=yellow]      ⏳ oc
done:     #[fg=green]       ✓ oc
error:    #[fg=red,bold]    ✗ oc
```

## 注意事项

- 避免频繁 fork 消耗性能，依赖 tmux 的 status-interval 控制刷新频率
- 标记文件按 window_id 隔离，避免多窗口互相干扰
- 进程检测使用 `pgrep` 而非 `ps | grep`，避免自身匹配