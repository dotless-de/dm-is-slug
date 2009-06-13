module DataMapper
  module Is
    module Slug
      class InvalidSlugSource < Exception
      end

      DEFAULT_SLUG_SIZE = 50

      DEFAULT_SLUG_OPTIONS = {
        :permanent_slug => true
      }

      # @param [String] str A string to escape for use as a slug
      # @return [String] an URL-safe string
      def self.escape(str)
        s = Iconv.conv('ascii//translit//IGNORE', 'utf-8', str)
        s.gsub!(/\W+/, ' ')
        s.strip!
        s.downcase!
        s.gsub!(/\ +/, '-')
        s
      end

      ##
      # Methods that should be included in DataMapper::Model.
      # Normally this should just be your generator, so that the namespace
      # does not get cluttered. ClassMethods and InstanceMethods gets added
      # in the specific resources when you fire is :slug
      ##

      # Defines a +slug+ property on your model with the same size as your
      # source property. This property is Unicode escaped, and treated so as
      # to be fit for use in URLs.
      #
      # ==== Example
      # Suppose your source attribute was the following string: "Hot deals on
      # Boxing Day". This string would be escaped to "hot-deals-on-boxing-day".
      #
      # Non-ASCII characters are attempted to be converted to their nearest
      # approximate.
      #
      # ==== Parameters
      # +permanent_slug+::
      #   Permanent slugs are not changed even if the source property has
      # +source+::
      #   The property on the model to use as the source of the generated slug,
      #   or an instance method defined in the model, the method must return
      #   a string or nil.
      # +size+::
      #   The length of the +slug+ property
      #
      # @param [Hash] provide options in a Hash. See *Parameters* for details
      def is_slug(options)
        extend  DataMapper::Is::Slug::ClassMethods
        include DataMapper::Is::Slug::InstanceMethods

        @slug_options = DEFAULT_SLUG_OPTIONS.merge(options)
        raise InvalidSlugSource('You must specify a :source to generate slug.') unless slug_source

        slug_options[:size] ||= get_slug_size
        property(:slug, String, :size => slug_options[:size], :unique => true) unless slug_property
        if method_defined?(:valid?)
          before :valid?, :generate_slug
        else
          before :slug, :generate_slug
        end
      end

      module ClassMethods
        attr_reader :slug_options

        def permanent_slug?
          slug_options[:permanent_slug]
        end

        def slug_source
          slug_options[:source] ? slug_options[:source].to_sym : nil
        end

        def slug_source_property
          detect_slug_property_by_name(slug_source)
        end

        def slug_property
          detect_slug_property_by_name(:slug)
        end

        private

        def detect_slug_property_by_name(name)
          properties.detect do |p|
            p.name == name && p.type == String
          end
        end

        def get_slug_size
          slug_source_property && slug_source_property.size || DataMapper::Is::Slug::DEFAULT_SLUG_SIZE
        end
      end # ClassMethods

      module InstanceMethods
        def to_param
          [slug]
        end

        def permanent_slug?
          self.class.permanent_slug?
        end

        def slug_source
          self.class.slug_source
        end

        def slug_source_property
          self.class.slug_source_property
        end

        def slug_property
          self.class.slug_property
        end

        def slug_source_value
          self.send(slug_source)
        end

        # The slug is not stale if
        # 1. the slug is permanent, and slug column has something valid in it
        # 2. the slug source value is nil or empty
        def stale_slug?
          !((permanent_slug? && slug && !slug.empty?) || (slug_source_value.nil? || slug_source_value.empty?))
        end

        private

        def generate_slug
          return unless self.class.respond_to?(:slug_options) && self.class.slug_options
          raise InvalidSlugSource('Invalid slug source.') unless slug_source_property || self.respond_to?(slug_source)
          return unless stale_slug?
          attribute_set :slug, unique_slug
        end

        def unique_slug
          old_slug = self.slug
          max_length = self.class.send(:get_slug_size)
          base_slug = ::DataMapper::Is::Slug.escape(slug_source_value)[0, max_length]
          i = 1
          new_slug = base_slug

          if old_slug != new_slug
            lambda do
              dupe = self.class.first(:slug => new_slug)
              if dupe && dupe != self
                i = i + 1
                slug_length = max_length - i.to_s.length - 1
                new_slug = "#{base_slug[0, slug_length]}-#{i}"
                redo
              end
            end.call
            new_slug
          else
            old_slug
          end
        end
      end # InstanceMethods
    end # Slug
  end # Is
end # DataMapper
