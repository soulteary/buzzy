# Buzzy

![](.github/logo.svg)

> "Get something real up and running first, then make it better." — inspired by *Rework*
>
> We recommend the same approach with Buzzy: start with a working setup, then iterate on configuration, workflow, and user experience for your own context.

Buzzy is a fork of [Fizzy](https://fizzy.do/) — the Kanban tracking tool for issues and ideas by [37signals](https://37signals.com). This repository contains the Buzzy fork source code.

## 项目简介

> “先去做，再把它做好。” —— 《Rework》
>
> 使用 Buzzy 也建议采用同样的方式：先把系统跑起来，再按你的场景逐步调整配置、流程与体验。

Buzzy 是 [Fizzy](https://fizzy.do/) 的分支项目。Fizzy 是 [37signals](https://37signals.com) 出品的看板工具，用于跟踪问题与想法；本仓库提供 Buzzy 分支的完整源码与文档。

## 部署（自建实例）

如果你希望运行自己的 Buzzy 实例，但暂不修改源码，建议优先使用预构建 Docker 镜像快速上线。

你需要准备：

- 一台可运行 Docker 的服务器
- 基础网络与域名配置（按需）
- 按业务场景设置环境变量与认证选项

具体步骤请参考 [部署指南](docs/deployment.md)：

- 使用 Docker 进行标准部署
- 需要更高灵活性（包括改代码）时，可选择 Kamal

## 开发（本地）

欢迎并鼓励你按自己的需求定制 Buzzy。
请先阅读 [开发指南](docs/development.md)，完成本地依赖与环境准备。

### 快速开始

在 `buzzy/` 目录中执行：

```bash
bin/setup
bin/dev
```

启动后访问：`http://buzzy.localhost:3006`

### 文档索引

- [文档索引](docs/README.md)：按角色与主题组织的完整阅读入口
- [实现概览](docs/buzzy-implementation-overview.md)：架构、模块关系与核心领域模型
- [路由 / 认证 / 授权](docs/buzzy-routing-authz.md)：多租户、会话机制与权限体系
- [任务与运维](docs/buzzy-jobs-ops.md)：Solid Queue、定时任务与运维关注点
- [测试与质量](docs/buzzy-testing-quality.md)：测试策略、CI 约束与质量基线
- [配置参考](docs/buzzy-configuration-reference.md)：环境变量与运行时开关说明
- [Forward Auth 指南](docs/forward_auth.md)：基于反向代理的认证集成方案

## 贡献

欢迎贡献！提交代码前请先阅读：

- [贡献指南](CONTRIBUTING.md)
- [风格指南](STYLE.md)

## 许可证

Buzzy 以 [O'Saasy License](LICENSE.md) 许可证发布。
