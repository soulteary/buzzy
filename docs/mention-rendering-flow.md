# @Mention 渲染链路分析

## 问题现象

卡片描述中输入的 `@用户` 在编辑器中显示正确（头像 + 名字），保存后展示为 ☒ 或异常。

## 数据流

### 1. 编辑 / 提交

- Lexxy 编辑器将 mention 序列化为 `<action-text-attachment content-type="application/vnd.actiontext.mention" sgid="..." content="...">`，或带 `gid`、或节点内带占位符（如 ☒）。
- 表单提交的 `description` 为上述 HTML 字符串。

### 2. 保存（ActionText 扩展）

`config/initializers/action_text.rb` 中 `before_save` 顺序：

1. **normalize_action_text_attachment_gids_to_sgids**  
   将仅带 `gid` 的节点转为 `sgid`（保留 `content-type` 等），便于后续用 SignedGlobalID 解析。

2. **strip_mention_content_attribute**  
   对 `content-type="application/vnd.actiontext.mention"` 的节点：
   - 删除 `content` 属性（避免多次转义导致预览异常）；
   - **清空节点内部文本/子节点**（`node.content = ""`），避免 ☒ 等占位符被存库并在默认渲染时显示。

入库 body 形态：`<action-text-attachment sgid="..." content-type="application/vnd.actiontext.mention"></action-text-attachment>`（无 content、无子内容）。

### 3. 渲染（富文本 → HTML）

- 入口：`rich_text_with_attachments(card.description)`（见 `cards/container/_content_display.html.erb` 等）。
- 流程：
  1. `rich_text.body.render_attachments { |attachment| ... }`  
     Rails 对每个 `action-text-attachment` 节点调用 block，**用 block 的返回值替换该节点**。
  2. **Mention 专用路径**：根据 `content-type` 判断为 mention 时，**不**调用 `render_action_text_attachment(attachment)`，改为直接 `render "via/vium", vium: attachment`，避免 Rails 默认逻辑回退到节点内容（含 ☒）。
  3. `via/vium` 根据 `attachment.attachable` 派发：
     - `User` → `users/attachable`（头像 + 名字）；
     - `MissingAttachable`（用户已删 / sgid 无效）→ `users/missing_attachable`。
  4. 非 mention 的 attachment 仍走 `render_action_text_attachment(attachment)`。
  5. 最后对整段结果执行 `sanitize_action_text_content(content)`（对 Content 调 `.to_html` 再 sanitize）。

### 4. 异常与占位

- `InvalidSignature` / `RecordNotFound`：mention 改为 `render "users/missing_attachable")`，不返回空字符串。
- `MissingTemplate` / `NoMethodError`：mention 同样只渲染 `users/missing_attachable`，不再对 mention 使用 `attachment.to_html`，避免输出节点内残留 ☒。

## 关键点小结

| 环节       | 作用 |
|------------|------|
| 保存时清空 mention 节点内容 | 库中不存 ☒，任何回退逻辑也不会展示占位符。 |
| Mention 一律走 via/vium   | 不经过 `render_action_text_attachment`，避免默认 partial 或回退到节点内容。 |
| Rescue 中 mention 只渲染 missing_attachable | sgid 无效或异常时统一占位，不重试 via/vium、不用 to_html。 |
| content-type 判断用 downcase | 兼容不同大小写，避免误判为非 mention。 |

## 其他渲染点

- **卡片正文**：`cards/container/_content_display.html.erb` → `rich_text_with_attachments(card.description)` ✅  
- **评论**：`cards/comments/_comment.html.erb` → `rich_text_with_attachments(comment.body)` ✅  
- **JSON**：`cards/_card.json.jbuilder` → `rich_text_with_attachments(card.description)` ✅  
- **事件时间线**：`events/event/_layout.html.erb` 中的 `event.description_for(...).to_html` 使用的是 `Event::Description`（活动描述句子），**不是**卡片 rich text body，与 mention 渲染无关。

## 已保存旧数据

若库里已有带 ☒ 或错误 content 的 mention 节点，需一次性迁移：对相关 `action_text_rich_texts.body` 做与 `strip_mention_content_attribute` 相同的清理（仅针对 mention 节点去掉 content 并清空节点内容），再渲染即会走 via/vium，显示正常或“缺失用户”占位。
