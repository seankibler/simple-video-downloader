class AddStatusToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :status, :integer
  end
end
