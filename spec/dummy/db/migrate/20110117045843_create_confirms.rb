class CreateConfirms < ActiveRecord::Migration
  def self.up
    create_table :confirms do |t|
      t.string :name
      t.string :image, limit: 36

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :confirms
  end
end
