# Support locating legacy gid://fizzy/... URIs (e.g. from Action Text, Active Job) after renaming to Buzzy.
# New records use gid://buzzy/...; existing data may still reference gid://fizzy/...
Rails.application.config.after_initialize do
  GlobalID::Locator.class_eval do
    class << self
      alias_method :locate_without_legacy_compat, :locate

      def locate(gid, *options)
        return locate_without_legacy_compat(gid, *options) if gid.nil?
        gid_str = gid.to_s
        # Legacy: stored data may still use gid://fizzy/ (upstream app name)
        if gid_str.start_with?("gid://fizzy/")
          gid_str = gid_str.sub("gid://fizzy/", "gid://buzzy/")
        end
        locate_without_legacy_compat(gid_str, *options)
      end
    end
  end
end
