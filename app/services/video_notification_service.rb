class VideoNotificationService
    NTFY_TOPIC = ENV["VIDEO_NOTIFICATION_TOPIC"] || "sardis-video-notifications"
    
    def initialize(video)
        @video = video
    end

    def notify
        message = <<~MESSAGE
            #{@video.user.username} downloaded #{@video.title} from #{@video.link} at #{@video.updated_at.strftime("%Y-%m-%d %H:%M:%S")}
            --------------------------------
            Video: #{@video.title}
            Link: #{@video.link}
            Status: #{@video.status}
            --------------------------------
            Video Utilization: #{@video.user.videos.count} / #{User::MAX_VIDEOS}
            Storage Utilization: #{@video.user.total_storage_used} / #{User::MAX_STORAGE}
            --------------------------------
            Total Storage Used: #{User.all.sum { |user| user.total_storage_used }}
            Total Videos: #{User.all.sum { |user| user.videos.count }}
            --------------------------------
        MESSAGE

        Ntfy.new(NTFY_TOPIC).send_notification("Video Downloaded", message)
    end
end