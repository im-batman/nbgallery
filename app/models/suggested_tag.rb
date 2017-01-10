# Model for suggested tags ("you might like notebooks tagged with...")
class SuggestedTag < ActiveRecord::Base
  belongs_to :user

  include ExtendableModel

  class << self
    def compute_all
      User.find_each do |user|
        compute_for(user)
      end
    end

    def compute_for(user)
      # Get suggestions from helper methods
      suggestors = methods.select {|m| m.to_s.start_with?('suggest_tags_')}
      suggested = suggestors
        .map {|suggestor| send(suggestor, user)}
        .reduce(&:+)
        .map {|tag| SuggestedTag.new(user_id: user.id, tag: tag)}

      # Import into database
      SuggestedTag.transaction do
        SuggestedTag.where(user_id: user).delete_all # no callbacks
        SuggestedTag.import(suggested)
      end
    end

    # Suggest tags that are on notebooks suggested for the user
    def suggest_tags_from_suggested_notebooks(user)
      Set.new(
        SuggestedNotebook
          .joins('JOIN tags on tags.notebook_id = suggested_notebooks.notebook_id')
          .where(user_id: user.id)
          .pluck(:tag)
      )
    end
  end
end
