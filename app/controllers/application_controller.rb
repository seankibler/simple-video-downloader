class ApplicationController < ActionController::Base
  SECRET_CODE = ENV["SECRET_CODE"]

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def validate_secret_code
    if params[:secret_code] != SECRET_CODE
      redirect_to root_path, alert: "Invalid secret code"
    end
  end

  def authenticate_user!
    if current_user.blank?
      redirect_to new_session_path, notice: "Please login to view this page"
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
