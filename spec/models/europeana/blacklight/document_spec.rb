# frozen_string_literal: true

require 'spec_helper'
require 'i18n'

RSpec.describe Europeana::Blacklight::Document do
  subject { described_class.new(edm) }
  before do
    ::I18n.available_locales = %i(en fr es)
  end

  let(:edm) do
    {
      id: '/abc/123',
      type: 'IMAGE',
      title: %w(title1 title2),
      proxies: [
        {
          about: '/proxy/provider/abc/123',
          dcType: {
            def: ['Image'],
            en: ['Picture']
          },
          dcSubject: {
            def: %w(music art)
          },
          dcDescription: {
            en: ['object desc']
          }
        }
      ],
      aggregations: [
        {
          webResources: [
            {
              dctermsCreated: 1900
            },
            {
              dctermsCreated: 1950
            }
          ]
        }
      ],
      europeanaAggregation: {
        edmPreview: 'http://www.example.com/abc/123.jpg'
      },
      europeanaCompleteness: 5
    }
  end

  describe '.model_name' do
    subject { described_class.model_name.to_s }
    it { is_expected.to eq('Document') }
  end

  describe '#lang_map?' do
    context 'when not a Hash' do
      it 'returns false' do
        [nil, 0, 1, 'xyz', Array].each do |arg|
          expect(subject.lang_map?(arg)).to eq(false)
        end
      end
    end

    context 'when a Hash' do
      context 'when full EDM' do
        it 'returns false' do
          expect(subject.lang_map?(edm)).to eq(false)
        end
      end
      context 'when a record relation' do
        it 'returns false' do
          expect(subject.lang_map?(edm[:proxies].first)).to eq(false)
        end
      end
    end
  end

  describe '#provider_id' do
    it 'returns first part of ID' do
      expect(subject.provider_id).to eq('abc')
    end
  end

  describe '#record_id' do
    it 'returns second part of ID' do
      expect(subject.record_id).to eq('123')
    end
  end

  describe '#to_param' do
    it 'joins provider ID and record ID with /' do
      expect(described_class.new(edm).to_param).to eq('abc/123')
    end
  end

  describe '#has?' do
    context 'with unnested key' do
      context 'when key is present' do
        subject { described_class.new(edm).has?('title') }
        it { is_expected.to eq(true) }
      end

      context 'when key is absent' do
        subject { described_class.new(edm).has?('missing') }
        it { is_expected.to eq(false) }
      end
    end

    context 'with nested key' do
      context 'when key is present' do
        subject { described_class.new(edm).has?('proxies.about') }
        it { is_expected.to eq(true) }
      end

      context 'when key is absent' do
        subject { described_class.new(edm).has?('foo.bar') }
        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#[]' do
    it 'handles unnested keys' do
      expect(subject['type']).to eq('IMAGE')
    end

    it 'returns nil for fields on relations' do
      expect(subject['proxies.about']).to be_nil
      expect(subject['aggregations.webResources.dctermsCreated']).to be_nil
    end

    context 'when value is singular' do
      it 'is returned untouched' do
        expect(subject['europeanaCompleteness']).to eq(5)
      end
    end

    context 'when value is array' do
      it 'returns array of values' do
        expect(subject['title']).to eq(%w(title1 title2))
      end
    end

    context 'when value is absent' do
      it 'does not raise an error' do
        expect { subject['absent.key'] }.not_to raise_error
      end
      it 'returns nil' do
        expect(subject['absent.key']).to be_nil
      end
    end
  end

  describe '#fetch' do
    context 'when key is to relation' do
      it 'handles 2-level keys' do
        expect(subject.fetch('proxies.about')).to eq(['/proxy/provider/abc/123'])
      end

      it 'handles 3-level keys' do
        expect(subject.fetch('aggregations.webResources.dctermsCreated')).to eq([1900, 1950])
      end
    end

    context 'when value is hash' do
      context 'when hash is lang map' do
        context 'with key for current locale' do
          before do
            ::I18n.locale = :en
          end
          it 'returns current locale value' do
            expect(subject.fetch('proxies.dcType')).to eq(['Picture'])
          end
        end
        context 'with key for default locale' do
          before do
            ::I18n.locale = :fr
            ::I18n.default_locale = :en
          end
          it 'returns default locale value' do
            expect(subject.fetch('proxies.dcType')).to eq(['Picture'])
          end
        end
        context 'with key "def"' do
          before do
            ::I18n.locale = :fr
            ::I18n.default_locale = :es
          end
          it 'returns all values' do
            expect(subject.fetch('proxies.dcType')).to eq(%w(Image Picture))
          end
        end
        context 'without current locale or "def" keys' do
          before do
            ::I18n.locale = :es
          end
          it 'returns array of all values' do
            expect(subject.fetch('proxies.dcDescription')).to eq(['object desc'])
          end
        end
      end

      context 'when hash is not lang map' do
        it 'returns all objects' do
          expect(subject.fetch('aggregations.webResources').size).to eq(2)
        end
        it 'returns full relation objects' do
          expect(subject.fetch('aggregations.webResources').first).to be_a(described_class)
        end
        it 'preserves object fields' do
          expect(subject.fetch('aggregations.webResources').first).to have_key(:dctermsCreated)
        end
      end
    end
  end

  describe '#persisted?' do
    subject { described_class.new(edm).persisted? }
    it { is_expected.to be true }
  end

  describe '#public?' do
    subject { described_class.new(edm).public?(nil) }
    it { is_expected.to be true }
  end

  describe '#private?' do
    subject { described_class.new(edm).private?(nil) }
    it { is_expected.to be false }
  end
end
