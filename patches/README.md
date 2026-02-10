# 补丁说明

## lexxy-prompt-space-key.patch

修复 lexxy 编辑器中 prompt（如 @ 提及、# 标签）的行为：

- **问题**：在未输入任何查询内容时按空格，会错误地选中当前 prompt 选项，导致无法在触发符后直接输入空格（例如 Markdown 标题 `# `）。
- **修复**：仅在用户已输入查询内容时，才将空格视为“选择当前选项”；若查询为空，将空格交给编辑器处理。

### 应用方式

在项目根目录（buzzy）下执行：

```bash
./script/setup_lexxy
bundle install
```

脚本会克隆 [basecamp/lexxy](https://github.com/basecamp/lexxy) 到 `vendor/lexxy`、应用本补丁并构建；Gemfile 会自动使用该本地版本。
