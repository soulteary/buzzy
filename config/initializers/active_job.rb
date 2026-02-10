# frozen_string_literal: true

# inspired from code in ActiveRecord::Tenanted
module BuzzyActiveJobExtensions
  extend ActiveSupport::Concern

  prepended do
    attr_reader :account
    self.enqueue_after_transaction_commit = true
  end

  def initialize(...)
    super
    @account = Current.account
  end

  def serialize
    super.merge({ "account" => @account&.to_gid })
  end

  def deserialize(job_data)
    super
    if _account = job_data.fetch("account", nil)
      @account = GlobalID::Locator.locate(_account)
    end
  end

  def perform_now
    run = -> {
      if account.present?
        Current.with_account(account) { super }
      else
        super
      end
    }
    if storage_variant_job?
      begin
        run.call
      rescue ActiveRecord::RecordNotSaved => e
        # Cross-account comment (or card image variant) can enqueue variant jobs with account from
        # request; blob may belong to another account (e.g. embed uploaded in commenter's workspace).
        # Avoid surfacing 422 to the client when the main action (e.g. comment create) succeeded.
        Rails.logger.warn "[#{self.class.name}] RecordNotSaved (likely blob/account mismatch), skipping: #{e.message}"
      end
    else
      run.call
    end
  end

  def storage_variant_job?
    # Rails 8.1 only has TransformJob; CreateVariantsJob does not exist. Use safe check so we
    # don't reference an uninitialized constant (e.g. when SolidQueue deserializes old job class names).
    as_variant_jobs = [ ActiveStorage::TransformJob ]
    as_variant_jobs << ActiveStorage::CreateVariantsJob if defined?(ActiveStorage::CreateVariantsJob)
    self.class.in?(as_variant_jobs)
  end
end

ActiveSupport.on_load(:active_job) do
  prepend BuzzyActiveJobExtensions
end
