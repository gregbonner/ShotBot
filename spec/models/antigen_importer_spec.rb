require 'rails_helper'
require_relative '../support/antigen_xml'

RSpec.describe AntigenImporter, type: :model do
  describe '#create' do
    it 'takes no arguments to instantiate' do
      antigen_importer = AntigenImporter.new
      expect(antigen_importer.class.name).to eq('AntigenImporter')
      expect(antigen_importer.antigens).to eq([])
    end
  end
  
  describe '#xml_to_hash' do
    it 'takes an xml string and returns a hash' do
      xml_string = TestAntigen::ANTIGENSTRING
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash.class.name).to eq('Hash')
    end
    it 'has the first level xml tag as the top level key' do
      xml_string = '<testXML><levelOne><level2></level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash.has_key?('testXML')).to be_truthy
    end
    it 'uses key strings as lookups and not symbols' do
      xml_string = '<testXML><levelOne><level2></level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash['testXML']).to be_truthy
      expect(antigen_hash[:testXML]).to eq(nil)
    end
    it 'turns single tags into a key/value pair' do
      xml_string = '<testXML><levelOne><level2><something /></level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash['testXML']['levelOne']['level2'].class.name).to eq('Hash')
    end
    it 'turns multipe tags into an Array' do
      xml_string = '<testXML><levelOne><level2><something /></level2><level2><something /> \
                    </level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash['testXML']['levelOne']['level2'].class.name).to eq('Array')
    end
  end

  describe 'pulling data from the xml hash' do
    let(:antigen_importer) { AntigenImporter.new }
    let(:xml_string) { TestAntigen::ANTIGENSTRING } 
    let(:xml_hash) { antigen_importer.xml_to_hash(xml_string) } 

    describe '#get_cvx_for_antigen' do
      it 'takes an antigen xml and returns an array of the cvx codes' do
        expect(antigen_importer.get_cvx_for_antigen(xml_hash)).
          to eq([10, 110, 120, 130, 132, 146, 2, 89])
      end
    end
    
    describe '#find_or_create_all_vaccines' do
      it 'will pull all vaccines if already in the database' do
        cvx1, cvx2 = 10, 12
        vaccine  = Vaccine.create(cvx_code: 10)
        vaccine2 = Vaccine.create(cvx_code: 12)
        expect(antigen_importer.find_or_create_all_vaccines([10, 12])).
          to eq([vaccine, vaccine2])
      end
      it 'will create all vaccines if none are there' do
        cvx1, cvx2 = 10, 12
        expect(antigen_importer.find_or_create_all_vaccines([10, 12]).
          map { |vaccine| vaccine.cvx_code }).
          to eq([cvx1, cvx2])
      end
      it 'will create neccesary vaccines that are not in the database' do
        cvx1, cvx2 = 10, 12
        vaccine    = Vaccine.create(cvx_code: cvx1)
        expect(Vaccine.all.length).to eq(1)
        expect(antigen_importer.find_or_create_all_vaccines([10, 12]).
          map { |vaccine| vaccine.cvx_code }).
          to eq([cvx1, cvx2])
        expect(Vaccine.all.length).to eq(2)
      end
    end

    describe '#add_vaccines_to_antigen' do
      it 'takes an array of vaccines, antigen name and xml_hash' do
        vaccines = [FactoryGirl.create(:vaccine)]
        antigen  = FactoryGirl.create(:antigen)
        expect(antigen.vaccines).to eq([])
        antigen_importer.add_vaccines_to_antigen(antigen.name, vaccines, xml_hash)
        antigen.reload
        expect(antigen.vaccines).to eq(vaccines)
      end
      it 'will error if the antigen does not exist' do
        vaccines = [FactoryGirl.create(:vaccine)]
        expect {antigen_importer.add_vaccines_to_antigen(antigen.name, vaccines, xml_hash)}.
          to raise_exception
      end
      it 'adds the raw xml_hash to the antigen database object' do
        vaccines = [FactoryGirl.create(:vaccine)]
        antigen  = FactoryGirl.create(:antigen)
        expect(antigen.xml_hash).to eq(nil)
        antigen_importer.add_vaccines_to_antigen(antigen.name, vaccines, xml_hash)
        antigen.reload
        expect(antigen.xml_hash).to eq(xml_hash)
      end
    end

    describe '#import_antigen_xml_files' do
      it 'takes a directory of antigen xml files and imports them' do
        expect(Antigen.all.length).to eq(0)
        antigen_importer.import_antigen_xml_files('spec/support/xml')
        expect(Antigen.all.length).to eq(17)
        expect(Antigen.first.vaccines.length).to eq(18)
        expect(antigen_importer.antigens.length).to eq(17)
      end
    end

    describe '#parse_and_hash' do
      it 'takes a file path string and returns the hash of xml file' do
        expect(
          antigen_importer.parse_and_hash('spec/support/xml/AntigenSupportingData- Diphtheria.xml')
        ).to eq(XMLHash::SAMPLEDIPHTHERIA)
        expect(
          antigen_importer.parse_and_hash('spec/support/xml/AntigenSupportingData- Diphtheria.xml').
            class.name
        ).to eq('Hash')
      end
    end

    xdescribe '#create_antigen_series' do
      it 'takes an antigen_series_hash and returns an antigen_series' do
        antigen_series = antigen_importer.create_all_antigen_series(xml_hash)
        expect(antigen_series.first.class.name).to eq('AntigenSeries')
      end
    end

    xdescribe '#create_all_antigen_series' do
      it 'takes an antigen_xml_hash and returns an array of antigen_series' do
        antigen_series = antigen_importer.create_all_antigen_series(xml_hash)
        expect(antigen_series.first.class.name).to eq('AntigenSeries')
      end
    end

    xdescribe '#create_all_antigen_series' do
      # ensure it takes a hash and array
    end
    xdescribe '#create_antigen_series_doses' do

    end
    xdescribe '#create_antigen_series_dose_vaccines' do

    end
    xdescribe '#create_conditional_skips' do

    end
    
    describe '#create_conditional_skip_sets' do
      let(:single_set_conditional_skip_hash) do
        xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][2]['conditionalSkip']
      end
      let(:multiple_sets_conditional_skip_hash) do
        new_xml_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGDIPHTHERIA)
        new_xml_hash["antigenSupportingData"]["series"]["seriesDose"][0]['conditionalSkip']
      end
      let(:conditional_skip) { FactoryGirl.create(:conditional_skip) }

      it 'conditional_skip_hash:hash, conditional_skip:object => array of conditional_skip_sets' do
        sets = antigen_importer.create_conditional_skip_sets(
          multiple_sets_conditional_skip_hash,
          conditional_skip
        )
        expect(sets.first.class.name).to eq('ConditionalSkipSet')
        expect(sets.first.set_id).to eq(1)
        expect(sets.last.set_id).to eq(2)
        expect(sets.length).to eq(2)
      end
      it 'can take a conditional_skip hash with a hash of one set' do
        sets = antigen_importer.create_conditional_skip_sets(
          single_set_conditional_skip_hash,
          conditional_skip
        )
        expect(sets.length).to eq(1)
      end
      it 'takes an conditional_skip hash with an array with many sets' do
        sets = antigen_importer.create_conditional_skip_sets(
          multiple_sets_conditional_skip_hash,
          conditional_skip
        )
        expect(sets.length).to eq(2)
      end

    end


    describe '#create_conditional_skip_set_conditions' do
      let(:single_condition_set_hash) do
        new_xml_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGDIPHTHERIA)
        new_xml_hash["antigenSupportingData"]["series"]["seriesDose"][0]['conditionalSkip']["set"][0]
      end
      let(:multiple_condition_set_hash) do
        xml_hash["antigenSupportingData"]["series"][2]["seriesDose"][2]['conditionalSkip']["set"]
      end
      let(:conditional_skip_set) { FactoryGirl.create(:conditional_skip_set) }

      it 'conditional_skip_set_hash:hash, conditional_skip_set:object => array of conditions' do
        conditions = antigen_importer.create_conditional_skip_set_conditions(
          multiple_condition_set_hash,
          conditional_skip_set
        )
        expect(conditions.first.class.name).to eq('ConditionalSkipSetCondition')
        expect(conditions.first.condition_id).to eq(1)
        expect(conditions.last.condition_id).to eq(2)
        expect(conditions.length).to eq(2)
      end
      it 'can take a conditional_skip_set hash with a hash of one condition' do
        conditions = antigen_importer.create_conditional_skip_set_conditions(
          single_condition_set_hash,
          conditional_skip_set
        )
        expect(conditions.length).to eq(1)
      end
      it 'takes an conditional_skip_set hash with an array with many conditions' do
        conditions = antigen_importer.create_conditional_skip_set_conditions(
          single_condition_set_hash,
          conditional_skip_set
        )
        expect(conditions.length).to eq(2)
      end
    end
  end
end
