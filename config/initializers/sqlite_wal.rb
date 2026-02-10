# frozen_string_literal: true

# Enable WAL for the primary SQLite connection in production to reduce risk of
# "database disk image is malformed" when multiple processes write to the same volume.
# Rails 7.1+ sets WAL by default for new connections; the queue DB gets it when
# Solid Queue establishes its connection (same adapter defaults).
return unless Rails.env.production?

Rails.application.config.after_initialize do
  config = ActiveRecord::Base.connection_db_config.configuration_hash
  next unless config[:adapter] == "sqlite3"

  ActiveRecord::Base.connection.execute("PRAGMA journal_mode=WAL")
rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
  # DB not created yet (e.g. during assets:precompile), skip
end
