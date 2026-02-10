# Only hyphenated UUID account prefixes are supported in URLs (account id is used;
# external_account_id is not used for URL resolution). Numeric and base36
# prefixes are no longer accepted; legacy links will 404.
module AccountSlug
  # Hyphenated UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  HYPHENATED_UUID_PATTERN = /([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i
  PATH_INFO_MATCH = /\A(\/#{HYPHENATED_UUID_PATTERN})/

  class Extractor
    def initialize(app)
      @app = app
    end

    # We're using account UUID prefixes in the URL path. Rather than namespace
    # all our routes, we're "mounting" the Rails app at this URL prefix.
    def call(env)
      request = ActionDispatch::Request.new(env)

      # $1 = prefix (e.g. /uuid), $2 = hyphenated UUID
      if request.script_name && request.script_name =~ PATH_INFO_MATCH
        slug = $2
      elsif request.path_info =~ PATH_INFO_MATCH
        request.engine_script_name = request.script_name = $1
        request.path_info = $'.empty? ? "/" : $'
        slug = $2
      end

      account = Account.find_by(id: slug) if slug.present?

      if account
        env["buzzy.account_id"] = account.id
        Current.with_account(account) do
          @app.call env
        end
      elsif (user_id = request.path_info[%r{\A/users/([0-9a-f-]{36})(?:/|\z)}i, 1]) && (user = User.active.find_by(id: user_id))
        # 无账号前缀的 /users/:id：用被查看用户所在账号进入，避免 require_account 重定向到 session menu
        env["buzzy.account_id"] = user.account_id
        Current.with_account(user.account) do
          @app.call env
        end
      else
        Current.without_account do
          @app.call env
        end
      end
    end
  end

  # Encode account for URL: hyphenated UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  def self.encode(account_or_id)
    id = account_or_id.respond_to?(:id) ? account_or_id.id : account_or_id
    ActiveRecord::Type::Uuid.to_url_format(id.to_s)
  end

  # Decode slug for lookup: pass through (Uuid type cast handles hyphenated → base36)
  def self.decode(slug)
    slug.to_s
  end
end

Rails.application.config.middleware.insert_after Rack::TempfileReaper, AccountSlug::Extractor
