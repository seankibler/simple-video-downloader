class User < ApplicationRecord
    MAX_VIDEOS = (ENV["MAX_VIDEOS"] || 50).to_i.freeze
    MAX_STORAGE = (ENV["MAX_STORAGE_MB"] || 1000).to_i.megabyte.freeze

    attr_accessor :secret_code

    validates :username, presence: true, uniqueness: true

    has_many :videos

    def total_storage_used
        return 0 if videos.nil? || videos.empty?
        videos.sum { |video| video&.recording&.byte_size || 0 }
    end

    def video_limit_exceeded?
        return false if videos.nil? || videos.empty?
        videos.count >= MAX_VIDEOS
    end

    def video_storage_limit_exceeded?
        return false if Video.where(user: self).blank?
        Video.where(user: self).sum { |video| video&.recording&.byte_size || 0 } >= MAX_STORAGE
    end
end
