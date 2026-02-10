# 静态资源请求不记录到 Rails 日志，减少噪音。
# 对 /assets/、favicon、/packs/ 等路径在请求期间静默 Rails.logger（不输出 Started GET / Completed）。
# 若使用 Thruster 反向代理，其 JSON 请求日志需通过 SKIP_STATIC_REQUEST_LOGS 或入口脚本过滤。
class QuietStaticAssets
  # 匹配这些前缀的请求不记录到 Rails 日志
  STATIC_PATH_PREFIXES = %w[
    /assets/
    /favicon
    /packs/
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    if STATIC_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }
      Rails.logger.silence { @app.call(env) }
    else
      @app.call(env)
    end
  end
end

Rails.application.config.middleware.insert_before Rails::Rack::Logger, QuietStaticAssets
