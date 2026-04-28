class UsersController < ApplicationController
    before_action :validate_secret_code, only: [:create]

    def new
        @user = User.new
    end

    def create
        @user = User.new(user_params)
        if @user.save
            session[:user_id] = @user.id
            redirect_to videos_path, notice: "Welcome to the app #{@user.username}! You can now start downloading videos."
        else
            render :new
        end
    end

    private

    def user_params
        params.require(:user).permit(:username)
    end
end