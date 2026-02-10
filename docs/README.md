# Buzzy 文档中心

本目录汇总了 `buzzy/` 当前实现相关的开发、部署、架构与运维文档。

## 快速上手

在 `buzzy/` 目录执行：

```bash
bin/setup
bin/dev
```

访问：`http://buzzy.localhost:3006`

## 按角色阅读路径

### 1) 先跑起来（自托管/试用）

1. `docs/deployment.md`
2. `docs/buzzy-configuration-reference.md`
3. `docs/forward_auth.md`（如需接入反向代理认证）

### 2) 参与开发（推荐阅读顺序）

1. `docs/development.md`
2. `docs/buzzy-development-guide.md`
3. `docs/buzzy-implementation-overview.md`
4. `docs/buzzy-routing-authz.md`
5. `docs/buzzy-testing-quality.md`

### 3) 运营与稳定性关注

1. `docs/buzzy-jobs-ops.md`
2. `docs/buzzy-configuration-reference.md`
3. `docs/mysql-performance-checklist.md`
4. `docs/sqlite-performance.md`

## 文档索引（按主题）

- 架构总览：`docs/buzzy-implementation-overview.md`
- 开发指南：`docs/development.md`、`docs/buzzy-development-guide.md`
- 路由与权限：`docs/buzzy-routing-authz.md`
- 任务与运维：`docs/buzzy-jobs-ops.md`
- 测试与质量：`docs/buzzy-testing-quality.md`
- 配置总表：`docs/buzzy-configuration-reference.md`
- Forward Auth：`docs/forward_auth.md`
- 与上游差异：`docs/buzzy-vs-fizzy-diff-report.md`
- 技术报告：`docs/buzzy-technical-report.md`
- 数据库专题：`docs/mysql-performance-checklist.md`、`docs/mysql-sqlite-differences.md`、`docs/sqlite-performance.md`

## 维护约定

- 修改行为或配置时，请同步更新对应主题文档。
- 新文档优先放在 `docs/`，并在本索引中登记，避免入口分散。
- 若变更会影响上手流程，请优先更新 `README.md` 与 `docs/development.md` / `docs/deployment.md`。

## 关联来源

- 当前应用代码：`buzzy/`
- 上游参考实现：`fizzy/`
