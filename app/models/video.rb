class Video < ApplicationRecord
    MAX_VIDEOS = 50.freeze
    MAX_STORAGE = 100.megabyte.freeze

    belongs_to :user

    has_one_attached :recording

    before_create :set_status

    enum :status, { pending: 0, downloaded: 1, failed: 2, processing: 3 }

    validate :video_limit
    validate :video_storage_limit

    def set_status
        self.status = :pending
    end

    def title
        return 'Unknown Title' if self.command_output.blank?
        self.command_output["title"]
    end

    def author
        self.uploader
    end

    def uploader
        return nil if self.command_output.blank?
        self.command_output["uploader"]
    end

    def thumbnail_url
        return nil if self.command_output.blank?
        self.command_output["thumbnail"]
    end

    def download_filename
        return nil unless recording.attached?

        base = title.presence || recording.filename.base
        ext = recording.filename.extension
        safe = ActiveStorage::Filename.new(base).sanitized
        ext.present? ? "#{safe}.#{ext}" : safe
    end

    def purge_recording
        recording.purge if recording.attached?
    end

    private

    def video_limit
        return true if user.nil?

        if user.video_limit_exceeded?
            errors.add(:base, "You have reached the maximum number of videos (#{User::MAX_VIDEOS})")
        end
    end

    def video_storage_limit
        return true if user.nil?
        
        if user.video_storage_limit_exceeded?
            errors.add(:base, "You have reached the maximum storage limit (#{User::MAX_STORAGE / 1.megabyte}MB)")
        end
    end
end
