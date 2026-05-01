class VideoNotificationJob < ApplicationJob
  queue_as :default

  def perform(video)
    VideoNotificationService.new(video).notify
  end
end