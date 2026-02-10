Rails.application.configure do
  config.after_initialize do
    enabled = ENV["MULTI_TENANT"] == "true" || config.x.multi_tenant.enabled == true

    begin
      next unless ActiveRecord::Base.connection.data_source_exists?("accounts")
      Account.multi_tenant = enabled
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      # Build-time tasks (for example assets:precompile) may boot without schema.
      # Skip setting runtime tenant flags when DB/schema is unavailable.
      nil
    end
  end
end
