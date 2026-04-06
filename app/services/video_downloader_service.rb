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

    def initialize(video)
        @video = video
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

        format_id = find_preferred_format

        @video.recording.purge if @video.recording.attached?

        Rails.logger.info "Downloading video from #{@video.link}"

        Dir.mktmpdir("ytdlp-#{@video.id}") do |dir|
            output_template = File.join(dir, "#{@video.id}.%(ext)s")
            stdout, status = Open3.capture2(
                "yt-dlp",
                "--no-simulate",
                "-f", format_id,
                "-j",
                "--no-progress",
                "-o", output_template,
                "--",
                @video.link
            )

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
        end

        @video.save if @video.changed?
    end

    # Find the preferred format code from the available formats
    def find_preferred_format
        output, status = Open3.capture2("yt-dlp", "--dump-json", "--quiet", "--", @video.link)
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
end
