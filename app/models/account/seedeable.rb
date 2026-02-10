module Account::Seedeable
  extend ActiveSupport::Concern

  def setup_customer_template
    creator = users.admin.first || users.owner.first
    return if creator.blank?

    Account::Seeder.new(self, creator).seed
  end
end
