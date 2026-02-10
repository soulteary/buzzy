require_relative "boot"
require "rails/all"
require_relative "../lib/buzzy"

Bundler.require(*Rails.groups)

module Buzzy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Include the `lib` directory in autoload paths. Use the `ignore:` option
    # to list subdirectories that don't contain `.rb` files or that shouldn't
    # be reloaded or eager loaded.
    config.autoload_lib ignore: %w[ assets tasks rails_ext ]

    # Enable debug mode for Rails event logging so we get SQL query logs.
    # This was made necessary by the change in https://github.com/rails/rails/pull/55900
    config.after_initialize do
      Rails.event.debug_mode = true
    end

    # Use UUID primary keys for all new tables
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    config.mission_control.jobs.http_basic_auth_enabled = false

    config.i18n.default_locale = :en
    # Fallback to default locale is enabled via config.i18n.fallbacks (e.g. true in production).
    # config.i18n.fallback_locales is not set to avoid I18n.fallback_locales= when the gem only provides fallbacks=
    config.i18n.available_locales = [:en, :zh]

    # 启动前确保运行所需目录存在（Puma/SQLite/Active Storage/storage.oss.yml），避免权限与路径错误
    config.before_initialize do
      require "fileutils"
      dirs = %w[
        log storage tmp/pids tmp/storage tmp/storage/files
        storage/development/files storage/test/files storage/production/files
      ].map { |d| Rails.root.join(d) }
      FileUtils.mkdir_p(dirs)
    end
  end
end
