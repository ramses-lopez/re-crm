class AddDetailsToContact < ActiveRecord::Migration
  def change
  	add_column :contacts, :event, :string
  	add_column :contacts, :property_type, :string
  	add_column :contacts, :property_location, :string
  	add_column :contacts, :amount, :string
  	add_column :contacts, :services, :string
  end
end
