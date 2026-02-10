# Buzzy 测试与质量保障

## 1. 测试框架与工具

当前测试栈（见 `Gemfile` 与 `test/test_helper.rb`）：

- Minitest（Rails 默认）
- Capybara + Selenium（系统测试）
- WebMock + VCR（外部请求隔离/录制）
- Mocha（mock/stub）
- ActiveJob::TestHelper

## 2. 测试目录结构

主目录位于 `buzzy/test/`，按职责拆分：

- `models/`：模型行为与约束
- `controllers/`：控制器与权限路径
- `jobs/`：异步任务行为
- `integration/`：集成流程
- `system/`：端到端烟雾测试
- `policies/`：权限策略
- `test_helpers/`：共享测试辅助模块

## 3. test 环境配置要点

文件：`buzzy/config/environments/test.rb`

- `config.eager_load = ENV["CI"].present?`
- Active Storage 使用 `:test`
- `action_mailer.delivery_method = :test`
- 默认关闭缓存
- 开启 `config.x.multi_tenant.enabled = true`

## 4. 并行与租户上下文

文件：`buzzy/test/test_helper.rb`

- `ActiveSupport::TestCase.parallelize(workers: :number_of_processors)`
- Integration/System 测试默认设置 `script_name` 为 fixture 账户 slug
- 每个用例 setup 时设置 `Current.account`，teardown 清理 `Current`

这保证了多租户路径下的测试稳定性。

## 5. Fixture UUID 策略

`test_helper.rb` 中对 fixture 标识做了定制：

- 使用可预测 UUID（与 fixture 名相关）
- 使 fixture 数据的时间序关系稳定
- 减少 `.first/.last` 在测试中出现不确定排序

## 6. 质量门禁与 CI

入口文件：

- `buzzy/bin/ci`
- `buzzy/config/ci.rb`

当前 CI 主要步骤：

1. `bin/setup --skip-server`
2. Rubocop
3. Gemfile drift 检查
4. Bundler audit
5. Importmap audit
6. Brakeman
7. Gitleaks
8. SQLite 单元测试
9. SQLite 系统测试

建议本地提交前至少执行：

- `bin/rails test`
- `bin/ci`（完整变更时）
