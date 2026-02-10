module Attachments
  extend ActiveSupport::Concern

  # Variants used by ActionText embeds. Processed immediately on attachment to avoid
  # read replica issues (lazy variants would attempt writes on read replicas).
  #
  # Patched into ActionText::RichText in config/initializers/action_text.rb
  VARIANTS = {
    # vipsthumbnail used to create sized image variants has a intent setting to manage colors during
    # resize. By setting an invalid intent value the gif-incompatible intent filtering is skipped and
    # the gif can be rendered with all its frame intact.
    #
    # Only `n` is accepted as an override, using the full parameter name `intent` doesn’t work.
    #
    # This was cargo-culted from know-it-all and I imagine it may be fixed at some point.
    small: { loader: { n: -1 }, resize_to_limit: [ 800, 600 ] },
    large: { loader: { n: -1 }, resize_to_limit: [ 1024, 768 ] }
  }

  def attachments
    rich_text_record&.embeds || []
  end

  def has_attachments?
    attachments.any?
  end

  def remote_images
    @remote_images ||= remote_attachables_for("image/")
  end

  def has_remote_images?
    remote_images.any?
  end

  def remote_videos
    @remote_videos ||= remote_attachables_for("video/")
  end

  def has_remote_videos?
    remote_videos.any?
  end

  private
    def remote_attachables_for(content_type_prefix)
      attachables = rich_text_record&.body&.attachables || []
      attachables.select do |attachable|
        attachable_content_type(attachable).start_with?(content_type_prefix)
      end
    end

    def attachable_content_type(attachable)
      attachable.try(:content_type).to_s.presence ||
        attachable.try(:node)&.[]("content-type").to_s.presence ||
        attachable.try(:node)&.[](:'content-type').to_s.presence ||
        ""
    end

    def rich_text_record
      @rich_text_record ||= begin
        association = self.class.reflect_on_all_associations(:has_one).find { it.klass == ActionText::RichText }
        public_send(association.name)
      end
    end
end
