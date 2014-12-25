class CreateConfirmableAsset < ActiveRecord::Migration
  def self.up
    create_table :confirmable_assets do |t|
      t.string :name, limit: 32
      t.string :asset, limit: 36

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :confirmable_assets
  end
end
