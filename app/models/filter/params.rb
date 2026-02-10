module Filter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = [
    :assignment_status,
    :indexed_by,
    :sorted_by,
    :creation,
    :closure,
    card_ids: [],
    assignee_ids: [],
    creator_ids: [],
    closer_ids: [],
    board_ids: [],
    tag_ids: [],
    terms: []
  ]

  class_methods do
    def find_by_params(params)
      find_by params_digest: digest_params(params)
    end

    def digest_params(params)
      Digest::MD5.hexdigest normalize_params(params).to_json
    end

    def normalize_params(params)
      params
        .to_h
        .compact_blank
        .reject(&method(:default_value?))
        .collect { |name, value| [ name, value.is_a?(Array) ? value.collect(&:to_s) : value.to_s ] }
        .sort_by { |name, _| name.to_s }
        .to_h
    end
  end

  included do
    before_save { self.params_digest = self.class.digest_params(as_params) }
  end

  def used?(ignore_boards: false)
    tags.any? || assignees.any? || creators.any? || closers.any? ||
      terms.any? || card_ids&.any? || (!ignore_boards && boards.present?) ||
      assignment_status.unassigned? || !indexed_by.all? || !sorted_by.latest?
  end

  # +as_params+ uses URL-safe param format (hyphenated UUID for UUID models, etc.)
  # so generated links use consistent UUIDs. Unpersisted filters use resource collections.
  def as_params
    @as_params ||= {}.tap do |params|
      params[:indexed_by]        = indexed_by
      params[:sorted_by]         = sorted_by
      params[:creation]          = creation
      params[:closure]           = closure
      params[:assignment_status] = assignment_status
      params[:terms]             = terms
      params[:tag_ids]           = tags.map(&:to_param)
      params[:board_ids]         = boards.map(&:to_param)
      params[:card_ids]          = card_ids
      params[:assignee_ids]      = assignees.map(&:to_param)
      params[:creator_ids]       = creators.map(&:to_param)
      params[:closer_ids]        = closers.map(&:to_param)
    end.compact_blank.reject(&method(:default_value?))
  end

  def as_params_without(key, value)
    as_params.dup.tap do |params|
      if params[key].is_a?(Array)
        params[key] = params[key] - [ value ]
        params.delete(key) if params[key].empty?
      elsif params[key] == value
        params.delete(key)
      end
    end
  end

  def params_digest
    super.presence || self.class.digest_params(as_params)
  end
end
