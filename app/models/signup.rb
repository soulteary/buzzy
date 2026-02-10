class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address, :identity, :skip_account_seeding
  attr_reader :account, :user

  # 内存 hash 缓存：identity_id => owner user_id，避免每次请求重复查询用户是否存在
  OWNER_CACHE_EXPIRES_IN = 5.minutes
  OWNER_CACHE_SIZE = 2048

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, :identity, presence: true, on: :completion
  validates :full_name, length: { maximum: 240 }

  class << self
    def owner_cache
      @owner_cache ||= ActiveSupport::Cache::MemoryStore.new(size: OWNER_CACHE_SIZE)
    end

    # 带缓存的查询：该 identity 是否已有 owner 用户（用于防重复注册）
    def find_owner_for_identity(identity)
      return nil if identity.blank?

      key = "signup_owner/#{identity.id}"
      cached_id = owner_cache.read(key)
      if cached_id == false
        nil
      elsif cached_id.present?
        owner = User.includes(:account).find_by(id: cached_id)
        owner_cache.write(key, owner&.id || false, expires_in: OWNER_CACHE_EXPIRES_IN) if owner.nil?
        owner
      else
        owner = User.includes(:account).find_by(identity: identity, role: :owner)
        owner_cache.write(key, owner&.id || false, expires_in: OWNER_CACHE_EXPIRES_IN)
        owner
      end
    end

    def write_owner_cache(identity, user)
      return if identity.blank?
      key = "signup_owner/#{identity.id}"
      owner_cache.write(key, user&.id || false, expires_in: OWNER_CACHE_EXPIRES_IN)
    end

    def delete_owner_cache(identity)
      return if identity.blank?
      owner_cache.delete("signup_owner/#{identity.id}")
    end
  end

  def initialize(...)
    super

    @email_address = @identity.email_address if @identity
  end

  def create_identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link for: :sign_up
  end

  def complete
    if valid?(:completion)
      begin
        # 创建前确认该 identity 只注册过一次，避免重复提交或异常重试时创建多个用户/账户（走内存缓存）
        existing_owner = self.class.find_owner_for_identity(identity)
        if existing_owner
          @account = existing_owner.account
          @user = existing_owner
          return true
        end

        @tenant = create_tenant
        create_account
        true
      rescue => error
        destroy_account
        handle_account_creation_error(error)

        errors.add(:base, I18n.t("activerecord.errors.models.signup.attributes.base.creation_failed"))
        Rails.error.report(error, severity: :error)
        Rails.logger.error error
        Rails.logger.error error.backtrace.join("\n")

        false
      end
    else
      false
    end
  end

  private
    # Override to customize the handling of external accounts associated to the account.
    def create_tenant
      nil
    end

    # Override to inject custom handling for account creation errors
    def handle_account_creation_error(error)
    end

    def create_account
      @account = Account.create_with_owner(
        account: {
          external_account_id: @tenant,
          name: generate_account_name
        },
        owner: {
          name: full_name,
          identity: identity
        }
      )
      @user = @account.users.find_by!(role: :owner)
      self.class.write_owner_cache(identity, @user)
      @account.setup_customer_template unless skip_account_seeding
    end

    def generate_account_name
      AccountNameGenerator.new(identity: identity, name: full_name).generate
    end


    def destroy_account
      self.class.delete_owner_cache(identity) if identity.present?
      @account&.destroy!

      @user = nil
      @account = nil
      @tenant = nil
    end

    def subscription_attributes
      subscription = FreeV1Subscription

      {}.tap do |attributes|
        attributes[:name]  = subscription.to_param
        attributes[:price] = subscription.price
      end
    end

    def request_attributes
      {}.tap do |attributes|
        attributes[:remote_address] = Current.ip_address
        attributes[:user_agent]     = Current.user_agent
        attributes[:referrer]       = Current.referrer
      end
    end
end
