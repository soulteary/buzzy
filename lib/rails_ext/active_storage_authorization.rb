ActiveSupport.on_load :active_storage_blob do
  def accessible_to?(user)
    attachments.includes(:record).any? { |attachment| attachment.accessible_to?(user) } || attachments.none?
  end

  def publicly_accessible?
    attachments.includes(:record).any? { |attachment| attachment.publicly_accessible? }
  end
end

ActiveSupport.on_load :active_storage_attachment do
  def accessible_to?(user)
    record.try(:accessible_to?, user)
  end

  def publicly_accessible?
    record.try(:publicly_accessible?)
  end
end

Rails.application.config.to_prepare do
  module ActiveStorage::Authorize
    extend ActiveSupport::Concern

    include Authentication

    included do
      # Ensure require_authentication runs after set_blob.
      skip_before_action :require_authentication
      before_action :require_authentication, :ensure_accessible, unless: :publicly_accessible_blob?
    end

    private
      def publicly_accessible_blob?
        @blob.publicly_accessible?
      end

      def ensure_accessible
        return if blob_accessible_to_current_identity?
        head :forbidden
      end

      # 跨账号场景：Current.user 可能为 nil（当前 identity 在此账号无 User），用 identity 下任一能访问该 blob 的用户通过校验
      def blob_accessible_to_current_identity?
        user = Current.user
        user ||= Current.identity.users.find { |u| @blob.accessible_to?(u) } if Current.identity.present?
        user.present? && @blob.accessible_to?(user)
      end
  end

  ActiveStorage::Blobs::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Blobs::ProxyController.include ActiveStorage::Authorize
  ActiveStorage::Representations::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Representations::ProxyController.include ActiveStorage::Authorize
end
