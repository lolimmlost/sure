class Mealie::Recipe < ApplicationRecord
  self.table_name = "mealie_recipes"

  has_many :recipe_foods, -> { order(:id) },
           class_name: "Mealie::RecipeFood",
           foreign_key: :mealie_recipe_id,
           dependent: :destroy
  has_many :foods, through: :recipe_foods, source: :food

  scope :active, -> { where(deleted_at: nil) }

  validates :external_id, :slug, :name, presence: true
  validates :external_id, uniqueness: true
  validates :slug, uniqueness: true

  def active?
    deleted_at.nil?
  end

  def soft_delete!
    update!(deleted_at: Time.current) if active?
  end
end
