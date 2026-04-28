class SessionsController < ApplicationController
    SECRET_CODE = ENV["SECRET_CODE"]

    def new
    end

    def create
        user = User.find_by(username: params[:username])        

        if user.present? && params[:secret_code] == SECRET_CODE
            Rails.logger.debug "Login successful for user #{user.username}"
            session[:user_id] = user.id
            redirect_to root_path, notice: "Login successful"
        else
            Rails.logger.debug "APP SECRET CODE: #{SECRET_CODE}"
            Rails.logger.debug "PARAMS SECRET CODE: #{params[:secret_code]}"
            Rails.logger.debug "Login failed for user #{params[:username]} with secret code #{params[:secret_code]}"
            flash.now[:error] = "Invalid username or secret code"
            render :new
        end
    end

    def destroy
        session.delete(:user_id)
        redirect_to root_path, notice: "Logout successful"
    end

    private

    def session_params
        params.require(:session).permit(:username, :secret_code)
    end
end