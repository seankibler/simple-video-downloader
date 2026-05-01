class VideoNotificationService
    NTFY_TOPIC = ENV["VIDEO_NOTIFICATION_TOPIC"] || "sardis-video-notifications"
    
    def initialize(video)
        @video = video
    end

    def notify
        Ntfy.new(NTFY_TOPIC).send_notification("Video Downloaded", "#{@video.user.username} downloaded #{@video.title} from #{@video.link} at #{@video.updated_at.strftime("%Y-%m-%d %H:%M:%S")}")
    end
end