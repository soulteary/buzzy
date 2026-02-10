module Identity::Transferable
  extend ActiveSupport::Concern

  TRANSFER_LINK_EXPIRY_DURATION = 4.hours

  class_methods do
    def find_by_transfer_id(id)
      return unless Buzzy.session_transfer_enabled?

      identity = Identity::TransferToken.find_identity_by_token_id(id) ||
        find_signed(id, purpose: :transfer)
      identity if identity&.session_transfer_enabled?
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end

  def transfer_id
    return unless Buzzy.session_transfer_enabled?
    return unless session_transfer_enabled?

    token = Identity::TransferToken.valid.find_by(identity_id: id)
    token ||= Identity::TransferToken.create!(
      identity_id: id,
      expires_at: TRANSFER_LINK_EXPIRY_DURATION.from_now
    )
    token.update!(expires_at: TRANSFER_LINK_EXPIRY_DURATION.from_now) if token.expires_at < 2.hours.from_now
    ActiveRecord::Type::Uuid.to_url_format(token.id)
  end
end
