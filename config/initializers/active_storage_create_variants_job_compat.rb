# frozen_string_literal: true

# Rails 8.1 only defines ActiveStorage::TransformJob; there is no CreateVariantsJob.
# SolidQueue may have jobs in the queue serialized with class name "ActiveStorage::CreateVariantsJob"
# (e.g. from an older Rails or from a different enqueue path). Define the constant as an alias
# so those jobs can be deserialized and run (TransformJob has the same perform(blob, transformations) contract).
ActiveSupport.on_load(:active_storage) do
  unless defined?(ActiveStorage::CreateVariantsJob)
    ActiveStorage.const_set(:CreateVariantsJob, ActiveStorage::TransformJob)
  end
end
