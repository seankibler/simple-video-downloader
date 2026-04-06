class CreateVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :videos do |t|
      t.string :link
      t.string :file

      t.timestamps
    end
  end
end
