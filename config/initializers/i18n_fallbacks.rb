# frozen_string_literal: true

# Rails may set config.i18n.fallback_locales (e.g. via load_defaults), which gets
# applied as I18n.fallback_locales= during initialization. The I18n gem only
# provides I18n.fallbacks=, so we remove the key and rely on config.i18n.fallbacks
# (e.g. true in production) which is handled by I18n::Railtie via init_fallbacks.
Rails.application.config.i18n.delete(:fallback_locales)
