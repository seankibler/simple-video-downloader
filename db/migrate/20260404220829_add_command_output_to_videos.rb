class AddCommandOutputToVideos < ActiveRecord::Migration[8.1]
  def change
    add_column :videos, :command_output, :jsonb
  end
end
