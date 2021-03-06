# frozen_string_literal: true

module Europeana
  module Blacklight
    class Document
      ##
      # Methods for working with "LangMap" data types in API JSON responses
      # @see http://labs.europeana.eu/api/getting-started#datatypes
      module LangMaps
        # @see https://www.loc.gov/standards/iso639-2/php/code_changes.php
        DEPRECATED_ISO_LANG_CODES = %w(in iw jaw ji jw mo mol scc scr sh).freeze

        # Special keys API may return in a LangMap, not ISO codes
        # @todo Empty key acceptance is a workaround for malformed API data
        #   output; remove when fixed at source
        NON_ISO_LANG_CODES = ['def', ''].freeze

        # @todo Are three-letter language codes valid in EDM?
        def lang_map?(obj)
          return false unless obj.is_a?(Hash)
          obj.keys.map(&:to_s).all? { |key| known_lang_map_key?(key) }
        end

        def known_lang_map_key?(key)
          key = key.dup.downcase
          DEPRECATED_ISO_LANG_CODES.include?(key) ||
            NON_ISO_LANG_CODES.include?(key) ||
            !ISO_639.find(key.split('-').first).nil?
        end

        def localize_lang_map(lang_map)
          if lang_map.is_a?(Array)
            return lang_map.map { |l| localize_lang_map(l) }
          end

          return lang_map unless lang_map?(lang_map)

          lang_map_value(lang_map, ::I18n.locale.to_s) ||
            lang_map_value(lang_map, ::I18n.default_locale.to_s) ||
            lang_map.values
        end

        def lang_map_value(lang_map, locale)
          keys = salient_lang_map_keys(lang_map, locale)
          return nil unless keys.present?
          keys.map { |k| lang_map[k] }.flatten.uniq
        end

        def dereferenced_lang_map_value(value)
          return nil if value.nil?

          if value.is_a?(Array)
            return value.map { |v| dereferenced_lang_map_value(v) }
          end

          return value unless value.is_a?(String)

          concept = root.fetch('concepts', []).detect { |c| c[:about] == value }
          if concept.present? && concept.key?(:prefLabel)
            localize_lang_map(concept[:prefLabel])
          else
            return value
          end
        end

        protected

        def salient_lang_map_keys(lang_map, locale)
          iso_code = locale.split('-').first
          iso_locale = ISO_639.find(iso_code)

          # Favour exact matches
          keys = lang_map.keys.select do |k|
            [locale, iso_locale.alpha2, iso_locale.alpha3].include?(k)
          end.flatten.compact
          return keys unless keys.blank?

          # Any sub-code will do
          lang_map.keys.select do |k|
            k.start_with?("#{iso_code}-")
          end.flatten.compact
        end
      end
    end
  end
end
