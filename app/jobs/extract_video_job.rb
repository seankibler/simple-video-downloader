class ExtractVideoJob < ApplicationJob
  queue_as :default

  def perform(video)
    video.update_column(:status, :processing)
    VideoDownloaderService.new(video).download
  rescue StandardError => e
    Rails.logger.error "Error performing ExtractVideoJob #{e.message}"
    video.update_column(:status, :failed)
  end
end
