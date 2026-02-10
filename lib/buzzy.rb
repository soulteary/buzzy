module Buzzy
  class << self
    def saas?
      false
    end

    # When true, session transfer (share login link) is available; when false, all transfer links are disabled.
    # Set DISABLE_SESSION_TRANSFER=true to turn off and hide session transfer / share link functionality.
    def session_transfer_enabled?
      return @session_transfer_enabled if defined?(@session_transfer_enabled)
      @session_transfer_enabled = ENV["DISABLE_SESSION_TRANSFER"] != "true"
    end

    # When true, account export and user data export are available in the UI and via API.
    # Set DISABLE_EXPORT_DATA=true to turn off and hide all export data functionality.
    def export_data_enabled?
      return @export_data_enabled if defined?(@export_data_enabled)
      @export_data_enabled = ENV["DISABLE_EXPORT_DATA"] != "true"
    end

    # When true, user email addresses are hidden across the UI (replaced with a placeholder).
    # Set HIDE_EMAILS=true to enable. Does not affect mail delivery or form inputs.
    def hide_emails?
      return @hide_emails if defined?(@hide_emails)
      @hide_emails = ENV["HIDE_EMAILS"] == "true"
    end

    # Comma-separated list of email addresses that have super-admin access (view all boards and members).
    # Set ADMIN_EMAILS=admin@example.com,other@example.com to enable.
    def admin_emails
      return @admin_emails if defined?(@admin_emails)
      raw = ENV["ADMIN_EMAILS"].to_s.strip
      @admin_emails = raw.present? ? raw.split(/\s*,\s*/).map { |e| e.strip.downcase }.reject(&:blank?).to_set : Set.new
    end

    def db_adapter
      @db_adapter ||= DbAdapter.new ENV.fetch("DATABASE_ADAPTER", "sqlite")
    end

    def configure_bundle
    end
  end

  class DbAdapter
    def initialize(name)
      @name = name.to_s
    end

    def to_s
      @name
    end

    # Not using inquiry so that it works before Rails env loads.
    def sqlite?
      @name == "sqlite"
    end
  end
end
