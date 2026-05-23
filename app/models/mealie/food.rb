class Mealie::Food < ApplicationRecord
  self.table_name = "mealie_foods"

  has_many :recipe_foods, class_name: "Mealie::RecipeFood", foreign_key: :mealie_food_id, dependent: :nullify
  has_many :recipes, through: :recipe_foods

  scope :active, -> { where(deleted_at: nil) }

  validates :external_id, :name, presence: true
  validates :external_id, uniqueness: true

  def active?
    deleted_at.nil?
  end

  def soft_delete!
    update!(deleted_at: Time.current) if active?
  end
end
