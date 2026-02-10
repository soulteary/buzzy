class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  configure_replica_connections

  # Use hyphenated UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) in URLs for UUID primary keys
  def to_param
    if self.class.type_for_attribute(self.class.primary_key).is_a?(ActiveRecord::Type::Uuid)
      ActiveRecord::Type::Uuid.to_url_format(id.to_s)
    else
      id&.to_s
    end
  end
end
