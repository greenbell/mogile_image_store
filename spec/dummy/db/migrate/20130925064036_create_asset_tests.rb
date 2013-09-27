class CreateAssetTests < ActiveRecord::Migration
  def self.up
    create_table :asset_tests do |t|
      t.string :name, :limit => 32
      t.string :asset, :limit => 32

      t.timestamps
    end
  end

  def self.down
    drop_table :asset_tests
  end
end
