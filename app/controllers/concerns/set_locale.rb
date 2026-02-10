# frozen_string_literal: true

module SetLocale
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private
    def set_locale
      locale = locale_from_params || locale_from_session || locale_from_identity || locale_from_accept_language || I18n.default_locale
      locale = resolve_locale(locale) || I18n.default_locale
      I18n.locale = locale

      if locale_from_params.present?
        persist_locale(locale)
      elsif Current.identity.present? && Current.identity.locale.blank? && session[:locale].present?
        # Sync session locale to identity so it persists across sessions
        synced = resolve_locale(session[:locale])
        Current.identity.update_column(:locale, synced.to_s) if synced
      end
    end

    def locale_from_params
      return unless params[:locale].present?
      resolve_locale(params[:locale].to_s)
    end

    def locale_from_session
      return unless session[:locale].present?
      resolve_locale(session[:locale])
    end

    def locale_from_identity
      return unless Current.identity&.locale.present?
      resolve_locale(Current.identity.locale)
    end

    def locale_from_accept_language
      return unless request.env["HTTP_ACCEPT_LANGUAGE"].present?
      # Parse "zh-CN,zh;q=0.9,en;q=0.8" and pick first available locale
      request.env["HTTP_ACCEPT_LANGUAGE"].to_s.split(/,/).each do |part|
        tag = part.split(";q=").first.to_s.strip[0, 5]
        next if tag.blank?
        # Map "zh-CN"/"zh-TW"/"zh" to :zh, "en" to :en
        sym = (tag.start_with?("zh") ? :zh : tag.start_with?("en") ? :en : nil)
        return sym if sym && available_locales.include?(sym)
      end
      nil
    end

    def resolve_locale(value)
      return nil if value.blank?
      sym = value.to_s.underscore.to_sym
      available_locales.include?(sym) ? sym : nil
    end

    def available_locales
      Rails.application.config.i18n.available_locales
    end

    def persist_locale(locale)
      session[:locale] = locale.to_s
      if Current.identity.present?
        Current.identity.update_column(:locale, locale.to_s)
      end
    end
end
