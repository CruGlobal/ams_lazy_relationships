# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # Lazy loads (has_one/has_many/has_many_through/belongs_to) ActiveRecord
    # associations for ActiveRecord models
    class Association
      # @param model_class_name [String] The name of AR class for which the
      #   associations are loaded. E.g. When loading comment.blog_post
      #   it'd be "BlogPost".
      # @param association_name [Symbol] The name of association being loaded
      #   E.g. When loading comment.blog_post it'd be :blog_post
      def initialize(model_class_name, association_name)
        @model_class_name = model_class_name
        @association_name = association_name
      end

      # Lazy loads and yields the data when evaluating
      # @param record [Object] an object for which we're loading the data
      # @param block [Proc] a block to execute when data is evaluated.
      #  Loaded data is yielded as a block argument.
      def load(record, &block)
        BatchLoader.for(record).batch(key: batch_key, replace_methods: false) do |records, loader|
          data = load_data(records, loader)

          block&.call(data)
        end
      end

      private

      attr_reader :model_class_name, :association_name

      def load_data(records, loader)
        ::ActiveRecord::Associations::Preloader.new.preload(
          records_to_preload(records), association_name
        )

        data = []
        records.each do |r|
          value = r.public_send(association_name)
          data << value
          loader.call(r, value)
        end

        data = data.flatten.compact.uniq
      end

      def batch_key
        "#{model_class_name}/#{association_name}"
      end

      def records_to_preload(records)
        # It may happen that same record comes here twice (e.g. wrapped
        # in a decorator and non-wrapped). In this case Associations::Preloader
        # stores duplicated records in has_many relationships for some reason.
        # Calling uniq(&:id) solves the problem.ss
        records.uniq(&:id).reject do |r|
          r.association(association_name).loaded?
        end
      end
    end
  end
end
