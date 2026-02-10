# 评论、可见性与 @ 提及（开发参考）

简要说明评论与 @ 提及的权限行为及「隐藏看板 + 提及」的已实现改动。详细模型/控制器逻辑见代码：`Comment`、`Card::Commentable`、`Card::Accessible`、`Board::Accessible`、`Cards::CommentsController`（混入 `CardScoped`）、`User::Accessor#accessible_cards`。

---

## 行为小结

| 场景 | 能否打开卡片 | 能否参与讨论（发评论） |
|------|----------------|------------------------|
| 公开看板（all_access） | ✅ | ✅ |
| 已添加当前用户的看板 | ✅ | ✅ |
| 隐藏看板 + 当前用户被 @ 提及 | ✅（已实现） | ✅（已实现） |

---

## 已实现：「隐藏看板 + 提及」可参与讨论

- **User::Accessor#cards_accessible_via_mention(account)**：返回因被卡片/评论 @ 提及而可访问的卡片。
- **CardScoped**：在 `find_board_in_account_or_accessible` 中增加「提及回退」：用 `cards_accessible_via_mention` 按 board_id + number 查已发布卡片，设 `@board_accessed_via_mention`；`set_card` 在该情况下仅允许已发布卡片。
- **CardsController**：`set_board` 在 `Current.user.boards.find` 失败时走提及回退；对「仅提及可访问」时，edit/update/destroy 由 `ensure_not_mention_only_access` 返回 403；评论不受限。
- **视图**：`board_accessed_via_mention?` 为真时隐藏编辑标题、关闭/删除、指派、标签、列编辑、步骤编辑等，仅保留评论与只读展示。

---

## 权限要点

- 评论的「谁能发/改/删」由 **能否通过 set_board + set_card 找到该卡片** 决定；`commentable?` 仅要求卡片已发布。
- 仅因提及可访问时：允许评论的 create/update/destroy，不允许卡片/看板的结构性修改。
