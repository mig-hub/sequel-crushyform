require 'rubygems'
require 'bacon'
Bacon.summary_on_exit

F = ::File
D = ::Dir
ROOT = F.dirname(__FILE__)+'/..'
$:.unshift(ROOT+'/lib')

require 'sequel'
::Sequel::Model.plugin :crushyform
DB = ::Sequel.sqlite

class Haiku < ::Sequel::Model
  plugin :schema
  set_schema do
    primary_key :id
    String :title, :crushyform=>{:type=>:custom}
    text :body
    Boolean :published
    foreign_key :author_id, :authors
  end
  create_table unless table_exists?
  many_to_one :author
  one_to_many :reviews
  def validate
    
  end
end

class Author < ::Sequel::Model
  plugin :schema
  set_schema do
    primary_key :id
    String :name
    String :surname
  end
  create_table unless table_exists?
  one_to_many :haikus
end
Author.create(:name=>'Ray',:surname=>'Bradbury')

DB.create_table :reviews do
  primary_key :id
  String :title
  text :body
  Integer :rate
  foreign_key :haiku_id, :haikus
end
class Review < ::Sequel::Model
  many_to_one :haiku
end

class TestDateTime < ::Sequel::Model
  plugin :schema
  set_schema do
    primary_key :id
    Date :birth
    time :meeting
    DateTime :when
    DateTime :created_at
    DateTime :updated_at
  end
  create_table unless table_exists?
end

class ShippingAddress < ::Sequel::Model
  plugin :schema
  set_schema do
    primary_key :id
    text :address_body
    String :postcode
    String :city
  end
  create_table unless table_exists?
end
ShippingAddress.create(:address_body=>"3 Mulholland Drive\n\rFlat C", :postcode=>'90210', :city=>'Richville')

describe 'Crushyform when schema plugin is not used' do
  
  should 'have a correct default crushyform_schema' do
    Review.default_crushyform_schema.should=={
      :id       => {:type=>:integer},
      :title    => {:type=>:string},
      :body     => {:type=>:text},
      :rate     => {:type=>:integer},
      :haiku_id => {:type=>:parent}
    }
  end
  
  should 'build the default crushyform_schema on the first query' do
    Review.respond_to?(:schema).should==false
    Review.crushyform_schema.should==Review.default_crushyform_schema
  end
  
  should 'have an updatable crushyform_schema' do
    Review.crushyform_schema[:body][:type] = :custom
    Review.crushyform_schema.should.not==Review.default_crushyform_schema
    Review.crushyform_schema[:body][:type] = :text
  end
  
end

describe 'Crushyform when schema plugin is used' do
  
  should 'use schema declaration for building the default crushyform_schema' do
    Haiku.default_crushyform_schema.should=={
      :id         => {:type=>:integer},
      :title      => {:type=>:custom},
      :body       => {:type=>:text},
      :published  => {:type=>:boolean},
      :author_id  => {:type=>:parent}
    }
  end
  
end

describe 'Crushyform miscellaneous helpers' do
  should 'guess label columns using a list of common column names' do
    Haiku.label_column.should==:title
    Author.label_column.should==:surname # Respect order of search
  end
  should 'set Model::label_column' do
    TestDateTime.label_column.should==nil
    TestDateTime.label_column = :birth
    TestDateTime.label_column.should==:birth
    TestDateTime.label_column = nil
  end
  should 'have a shortcut for dataset only with columns relevant for building a dropdown' do
    a = Author.label_dataset.first
    a.surname.should=='Bradbury'
    a.name.should==nil
  end
  should 'have a label based on Model::label_column' do
    Author.first.to_label.should=='Bradbury'
  end
  should 'Have a fallback label when label_column is nil' do
    ShippingAddress.first.to_label.should=="ShippingAddress 1"
  end
  should 'avoid line breaks if label column is a multiline field' do
    ShippingAddress.label_column = :address_body
    ShippingAddress.first.to_label.should=="3 Mulholland Drive  Flat C"
  end
end

describe 'Crushyfield types' do
  should 'escape html by default on text fields' do
    Haiku.new.crushyinput(:title, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should.match(/&lt;ScRipT &gt;alert\('test'\);&lt;\/ScRipT &gt;/)
    Haiku.new.crushyinput(:body, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should.match(/&lt;ScRipT &gt;alert\('test'\);&lt;\/ScRipT &gt;/)
    TestDateTime.new.crushyinput(:birth, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should.match(/&lt;ScRipT &gt;alert\('test'\);&lt;\/ScRipT &gt;/)
    TestDateTime.new.crushyinput(:meeting, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should.match(/&lt;ScRipT &gt;alert\('test'\);&lt;\/ScRipT &gt;/)
    TestDateTime.new.crushyinput(:when, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should.match(/&lt;ScRipT &gt;alert\('test'\);&lt;\/ScRipT &gt;/)
  end
  should 'not escape html on text field if specified' do
    Haiku.new.crushyinput(:title, {:input_value=>"<ScRipT >alert('test');</ScRipT >", :html_escape => false}).should.should.match(/<ScRipT >alert\('test'\);<\/ScRipT >/)
    Haiku.new.crushyinput(:body, {:input_value=>"<ScRipT >alert('test');</ScRipT >", :html_escape => false}).should.should.match(/<ScRipT >alert\('test'\);<\/ScRipT >/)
  end
  should 'not keep one-shot vars like :input_value in the crushyform_schema' do
    Haiku.crushyform_schema[:title][:input_value].should==nil
  end
  should 'be able to turn the :string input into other similar types like password or hidden' do
    Haiku.new.crushyinput(:title, {:input_type=>'password'}).should.match(/type='password'/)
  end
  should 'set booleans correctly' do
    Haiku.new.published.should==nil
    Haiku.new.crushyinput(:published).should.match(/<input[^>]+value='false'[^>]+checked \/>/)
    Haiku.new.crushyinput(:published,{:input_value=>true}).should.match(/<input[^>]+value='true'[^>]+checked \/>/)
    Haiku.new.crushyinput(:published,{:input_value=>false}).should.match(/<input[^>]+value='false'[^>]+checked \/>/)
  end
  should 'have :required option which is a text representing requirement and defaulting to blank' do
    Review.new.crushyinput(:title).should.not.match(/#{Regexp.escape Review.crushyfield_required}/)
    Review.new.crushyinput(:title,{:required=>" required"}).should.match(/required/)
  end
  should 'use the default requirement text when :required option is true instead of a string' do
    Review.new.crushyinput(:title,{:required=>true}).should.match(/#{Regexp.escape Review.crushyfield_required}/)
  end
  should 'format date/time/datetime correctly' do
    TestDateTime.new.db_schema[:meeting][:type].should== :time # Check that the correct type is used for following tests (see README)
    TestDateTime.new.crushyinput(:birth).should.match(/value=''/)
    TestDateTime.new.crushyinput(:birth,{:input_value=>::Time.now}).should.match(/value='\d{4}-\d{1,2}-\d{1,2}'/)
    TestDateTime.new.crushyinput(:meeting).should.match(/value=''/)
    TestDateTime.new.crushyinput(:meeting,{:input_value=>::Time.now}).should.match(/value='\d{1,2}:\d{1,2}:\d{1,2}'/)
    TestDateTime.new.crushyinput(:when).should.match(/value=''/)
    TestDateTime.new.crushyinput(:when,{:input_value=>::Time.now}).should.match(/value='\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{1,2}:\d{1,2}'/)
  end
  should 'add format instructions for date/time/datetime after :required bit' do
    TestDateTime.new.crushyinput(:birth,{:required=>true}).should.match(/#{Regexp.escape Review.crushyfield_required} Format: yyyy-mm-dd/)
    TestDateTime.new.crushyinput(:meeting,{:required=>true}).should.match(/#{Regexp.escape Review.crushyfield_required} Format: hh:mm:ss/)
    TestDateTime.new.crushyinput(:when,{:required=>true}).should.match(/#{Regexp.escape Review.crushyfield_required} Format: yyyy-mm-dd hh:mm:ss/)
  end
end

