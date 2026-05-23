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

    best = @indexed_foods.filter_map do |food, food_tokens|
      shared = (item_tokens & food_tokens).size
      next if shared.zero?
      confidence = shared.to_f / [ item_tokens.size, food_tokens.size ].max
      [ confidence, food ]
    end.max_by { |confidence, _| confidence }

    return nil if best.nil?
    Suggestion.new(item: item, food: best[1], confidence: best[0])
  end

  private
    def tokenize(str)
      str.to_s.downcase.gsub(/[^a-z\s]/, " ").split.reject { |t| STOPWORDS.include?(t) || t.size < 2 }
    end
end
