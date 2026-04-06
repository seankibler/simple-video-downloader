class UsersController < ApplicationController
    before_action :validate_secret_code, only: [:create]

    def new
        @user = User.new
    end

    def create
        @user = User.new(user_params)
        if @user.save
            redirect_to root_path, notice: "User created successfully"
        else
            render :new
        end
    end

    private

    def user_params
        params.require(:user).permit(:username, :secret_code)
    end
end