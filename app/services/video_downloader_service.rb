require "fileutils"
require "open3"

class VideoDownloaderService
    # Strip bulky fields yt-dlp adds for players/UI; we only need metadata like title.
    # formats — every available rendition (URLs, fragments, codecs); often 100KB–MB+.
    # requested_formats — merged format selection for -f; still large.
    # automatic_captions / subtitles — per-language track lists + URLs; very large on YouTube.
    # thumbnails — full list of sizes; keep string "thumbnail" / "thumbnail_url" if needed.
    # heatmap — engagement heatmap samples.
    # storyboards — DASH/sprite storyboard specs (especially YouTube).
    YTDLP_KEYS_TO_EXCLUDE = %w[
      formats requested_formats automatic_captions subtitles thumbnails
      heatmap storyboards
    ].freeze

    COOKIE_FILE_PATH = File.join(Rails.root.join('tmp'), 'cookies-latest.txt').freeze
    COOKIE_FILE_S3_KEY = "private/auth/cookies-latest.txt".freeze
    COOKIE_CACHE_DURATION = 1.hour.freeze

    attr_reader :dir

    def initialize(video)
        @video = video
        @dir = Dir.mktmpdir("ytdlp-#{@video.id}")

        initialize_s3_client
    end

    # `--dump-json` (-j) implies --simulate unless you pass --no-simulate, so without it
    # yt-dlp never writes files (-P / -o only apply to real downloads).
    def download
        unless yt_dlp_installed?
            @video.command_output = {"error" => "yt-dlp is not installed"}
            @video.status = :failed
            @video.save
            return
        end

        @video.recording.purge if @video.recording.attached?

        Rails.logger.info "Downloading video from #{@video.link}"

        stdout, status = Open3.capture2("yt-dlp", *download_args.compact)

        begin
            @video.command_output = JSON.parse(stdout).except(*YTDLP_KEYS_TO_EXCLUDE)
        rescue JSON::ParserError
            @video.command_output = {
                "error" => "Failed to parse command output",
                "output" => stdout.to_s
            }
        end

        if status.success?
            path = Dir.glob(File.join(dir, "#{@video.id}.*")).find { |p| File.file?(p) && !p.end_with?(".part") }
            if path
                # Active Storage may read `io` during `save`, so keep the handle open until then.
                io = File.open(path, "rb")
                begin
                    @video.recording.attach(
                        io: io,
                        filename: File.basename(path),
                        content_type: recording_content_type(path)
                    )
                    @video.status = :downloaded
                    @video.save!
                ensure
                    io.close
                end
            else
                @video.status = :failed
                @video.command_output = (@video.command_output || {}).merge("error" => "yt-dlp exited 0 but no file was written")
            end
        else
            @video.status = :failed
        end

        @video.save if @video.changed?
    ensure
      FileUtils.rm_rf(dir)
      VideoNotificationJob.perform_later(@video)
    end

    # Find the preferred format code from the available formats
    def find_preferred_format
        output, status = Open3.capture2("yt-dlp", *simulate_args.compact)
        begin
            Rails.logger.info "Available formats: #{output}"
            available_formats = JSON.parse(output)["formats"]
        rescue JSON::ParserError
            Rails.logger.error "Failed to parse available formats: #{output}"
            return nil
        end
        # Get all the formats that have both audio and video in an mp4 container
        mp4_combined_formats = available_formats.select  { |format| 
            format["acodec"] != "none" && format["vcodec"] != "none" && format["ext"] == "mp4"
        }

        Rails.logger.info "MP4 combined formats: #{mp4_combined_formats.inspect}"

        # Now find the format with the highest quality
        best_format = mp4_combined_formats.max_by { |format| format["quality"] }
        
        Rails.logger.info "Best format: #{best_format.inspect}"
        
        if best_format.blank?
            Rails.logger.error "No format available with audio and video in mp4 container"
            return nil
        end
        best_format["format_id"]
    end

    private

    def recording_content_type(path)
        Marcel::MimeType.for(Pathname.new(path), name: File.basename(path))
    end

    def yt_dlp_installed?
        _, status = Open3.capture2("yt-dlp", "--version")
        status.success?
    rescue Errno::ENOENT
        false
    end

    def download_args
      cookie_options + ["--no-simulate",
       "-f", best_format_id,
       "-j",
       "--no-progress",
       "-o", output_template,
       "--",
       @video.link]
    end

    def simulate_args
      cookie_options + ["--dump-json", "--quiet", "--", @video.link]
    end

    def output_template
      @output_template ||= File.join(dir, "#{@video.id}.%(ext)s")
    end

    def best_format_id
      @best_format_id ||= find_preferred_format
    end

    def download_cookie_file
        if File.exist?(COOKIE_FILE_PATH) && File.mtime(COOKIE_FILE_PATH) >= COOKIE_CACHE_DURATION.ago
            Rails.logger.info("Using cached cookie file from #{COOKIE_FILE_PATH}, cache valid for #{File.mtime(COOKIE_FILE_PATH) - COOKIE_CACHE_DURATION.ago}ms")
            return true
        end

        Rails.logger.info("Downloading cookie file from s3://#{ENV["AWS_BUCKET"]}/#{COOKIE_FILE_S3_KEY} to #{COOKIE_FILE_PATH}")

        cookies_content = @s3_client.get_object(
            response_target: COOKIE_FILE_PATH, 
            bucket: ENV["AWS_BUCKET"], 
            key: COOKIE_FILE_S3_KEY
        )

        if cookies_content.content_length > 0
            Rails.logger.info("Downloaded cookie file from S3 with etag: #{cookies_content.etag}")
            return true
        else
            Rails.logger.warn("Failed to download cookie file from S3")
            return false
        end
    end

    def always_download_cookie_file?
        return false unless ENV["ALWAYS_DOWNLOAD_COOKIE_FILE"].present?

        # allow values true, t, yes, y, 1, anything else is false
        ENV["ALWAYS_DOWNLOAD_COOKIE_FILE"].downcase.in?(%w[true t yes y 1])
    end

    def cookie_options
        return [] unless always_download_cookie_file? || !Rails.env.production?
        
        return [] unless download_cookie_file

        ["--cookies", COOKIE_FILE_PATH]
    end

    def initialize_s3_client
        return unless s3_configured?

        @s3_client = Aws::S3::Client.new(
            region: ENV["AWS_REGION"],
            access_key_id: ENV["AWS_ACCESS_KEY_ID"],
            secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
            endpoint: ENV["AWS_ENDPOINT"]
        )
    end

    def s3_configured?
        ENV["AWS_REGION"].present? &&
        ENV["AWS_ACCESS_KEY_ID"].present? &&
        ENV["AWS_SECRET_ACCESS_KEY"].present? &&
        ENV["AWS_ENDPOINT"].present?
    end
end
