require_relative "production"

# Staging 可选开启 Bullet（N+1 检测），见 docs/mysql-performance-checklist.md。设置 BULLET_ENABLED=true 并确保 Gemfile 中 staging 组含 bullet。
Rails.application.config.after_initialize do
  if ENV["BULLET_ENABLED"] == "true"
    begin
      require "bullet"
      Bullet.enable = true
      Bullet.rails_logger = true
      Bullet.add_footer = true
      Bullet.unused_eager_loading_enable = true
      Bullet.counter_cache_enable = true
    rescue LoadError
      Rails.logger.warn "Bullet 未安装：Gemfile 中请加入 group :staging 并包含 gem 'bullet' 后 bundle install"
    end
  end
end
