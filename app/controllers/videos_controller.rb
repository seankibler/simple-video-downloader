class VideosController < ApplicationController
    before_action :authenticate_user!

    def index
        @video = Video.new
        @videos = current_user.videos.order(created_at: :desc)
    end

    def create
        @video = current_user.videos.build(video_params)
        if @video.save
            ExtractVideoJob.perform_later(@video)
            redirect_to videos_path, notice: "Video added successfully"
        else
            redirect_to videos_path, alert: "Failed to add video: #{@video.errors.full_messages.join(', ')}"
        end
    end

    def retry
        @video = current_user.videos.find(params[:id])
        ExtractVideoJob.perform_later(@video)
        redirect_to videos_path, notice: "Video retried successfully"
    end

    def download
        @video = current_user.videos.find(params[:id])
        if @video.recording.attached?
            name = @video.download_filename || @video.recording.filename.to_s
            Rails.logger.info "Downloading video: #{name}"
            redirect_to rails_blob_path(
                @video.recording,
                disposition: :attachment,
                filename: name
            )
        else
            redirect_to videos_path, alert: "Video recording not found"
        end
    end

    def destroy
        @video = current_user.videos.find(params[:id])
        @video.destroy
        if @video.destroyed?
            redirect_to videos_path, notice: "Video deleted successfully"
        else
            redirect_to videos_path, alert: "Failed to delete video"
        end
    end

    private

    def video_params
        params.require(:video).permit(:link)
    end
end