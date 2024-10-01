class Account < ApplicationRecord
  include Joinable

  has_many :users, dependent: :destroy

  has_many :buckets, dependent: :destroy
  has_many :bubbles, through: :buckets

  has_many :tags, dependent: :destroy
end
