desc "Clean up old videos"
task :clean_videos do
    Video.where("created_at < ?", 30.days.ago).destroy_all
end