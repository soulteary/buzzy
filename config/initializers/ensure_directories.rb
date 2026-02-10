# frozen_string_literal: true

# 项目启动时确保 log、storage、tmp/pids、tmp/storage 存在，避免 SQLite/Active Storage/Puma 等因目录缺失报错。
Rails.application.config.after_initialize do
  %w[log storage tmp/pids tmp/storage].each do |dir|
    path = Rails.root.join(dir)
    FileUtils.mkdir_p(path) unless File.directory?(path)
  end
end
