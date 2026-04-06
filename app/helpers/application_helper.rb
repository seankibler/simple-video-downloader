module ApplicationHelper
    def current_user
        @current_user ||= User.find_by(id: session[:user_id])
    end

    def video_status_badge(status)
        case status
        when "pending"
            content_tag(:span, "Pending", class: "status pending")
        when "downloaded"
            content_tag(:span, "Downloaded", class: "status downloaded")
        when "failed"
            content_tag(:span, "Failed", class: "status failed")
        when "processing"
            content_tag(:span, "Processing", class: "status processing")
        else
            content_tag(:span, "Unknown", class: "status unknown")
        end
    end
end
