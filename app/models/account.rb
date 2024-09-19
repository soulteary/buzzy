class Account < ApplicationRecord
  include Joinable

  has_many :users, dependent: :destroy

  has_many :projects, dependent: :destroy
  has_many :bubbles, through: :projects
end
