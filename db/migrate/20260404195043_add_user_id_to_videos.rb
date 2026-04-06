class AddUserIdToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :user_id, :integer
  end
end
