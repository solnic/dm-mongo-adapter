module DataMapper
  module Mongo
    module Model
      include Migrations::Model

      private

      # @api private
      def const_missing(name)
        if name == :Serial
          DataMapper::Mongo::Property::ObjectId
        elsif DataMapper::Mongo::Property.const_defined?(name)
          DataMapper::Mongo::Property.const_get(name)
        else
          super
        end
      end
    end # Model
  end # Mongo
end # DataMapper
