class Inventory::FoodMatcher
  STOPWORDS = %w[
    can bottle jar pack pkg bag box bin tub tube case carton roll
    oz lb pound pounds gram grams ml liter liters
    large small mini bulk variety
  ].to_set.freeze

  Suggestion = Data.define(:item, :food, :confidence)

  def initialize(family:)
    @family = family
    @indexed_foods = Mealie::Food.active.map { |f| [ f, tokenize(f.name) ] }
  end

  # Returns Suggestion structs for unmapped items that have a non-zero match.
  # Sorted by confidence descending so the user sees best guesses first.
  def suggestions_for_unmapped
    @family.inventory_items
           .where(mealie_food_id: nil)
           .alphabetically
           .filter_map { |item| best_suggestion(item) }
           .sort_by { |s| -s.confidence }
  end

  def best_suggestion(item)
    item_tokens = tokenize(item.name)
    return nil if item_tokens.empty?

    best_food, best_score = nil, 0
    @indexed_foods.each do |food, food_tokens|
      shared = (item_tokens & food_tokens).size
      next if shared <= best_score
      best_food, best_score = food, shared
    end

    return nil if best_score.zero?
    denom = [ item_tokens.size, @indexed_foods.find { |f, _| f == best_food }[1].size ].max
    Suggestion.new(item: item, food: best_food, confidence: best_score.to_f / denom)
  end

  private
    def tokenize(str)
      str.to_s.downcase.gsub(/[^a-z\s]/, " ").split.reject { |t| STOPWORDS.include?(t) || t.size < 2 }
    end
end
