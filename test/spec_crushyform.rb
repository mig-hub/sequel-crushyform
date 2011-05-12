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
    errors[:title] << "is not good"
    errors[:title] << "smells like shit"
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
Author.create(:name=>'Jorge Luis',:surname=>'Borges')

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

require 'stash_magic'
class Attached < ::Sequel::Model
  plugin :schema
  set_schema do
    primary_key :id
    String :filename, :crushyform=>{:type=>:attachment}
    String :filesize, :crushyform=>{:type=>:none}
    String :filetype, :crushyform=>{:type=>:none}
    String :map, :crushyform=>{:type=>:attachment}
  end
  create_table unless table_exists?
  ::StashMagic.with_public_root ROOT+'/test'
end

# ========
# = Test =
# ========

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
  
  should 'know its crushyform version' do
    Haiku.crushyform_version.size.should==3
  end
  
  should 'have a correct default crushyid' do
    ShippingAddress.new.crushyid_for(:address_body).should=='new-ShippingAddress-address_body'
    ShippingAddress.first.crushyid_for(:address_body).should=='1-ShippingAddress-address_body'
  end
  
  should 'not mark texts as type :string, but :text' do
    Haiku.db_schema[:body][:type].should==:string
    Haiku.crushyform_schema[:body][:type].should==:text
  end
  
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
  
  should 'build correct dropdowns' do
    options = Author.to_dropdown(1)
    options.lines.count.should==3
    options.should.match(/<option[^>]+value='1'[^>]+selected>Bradbury<\/option>/)
    options = Author.to_dropdown
    options.should.not.match(/selected/)
  end
  
  should 'have custom wording for nil value for parent dropdowns' do
    options = Author.to_dropdown(1,"Pick an Author")
    options.should.match(/^<option value=''>Pick an Author<\/option>/)
  end
  
  should 'cache parent dropdowns' do
    Author.insert(:name=>'Matsuo', :surname=>'Basho') # insert or delete do not trigger hooks
    Author.to_dropdown(1).lines.count.should==3
    Author.reset_dropdown_cache
    Author.to_dropdown(1).lines.count.should==4
    Author.order(:id).last.delete
  end
  
  should 'have parent dropdown cache reseted when list is changed' do
    a = Author.create(:name=>'Yasunari', :surname=>'Kawabati')
    Author.to_dropdown(1).lines.count.should==4
    a.update(:surname=>'Kawabata')
    Author.to_dropdown(1).should.match(/Kawabata/)
    a.destroy
    Author.to_dropdown(1).lines.count.should==3
  end
  
  should 'have a generic entry point overridable for grabbing thumbnails' do
    Attached.new.respond_to?(:to_thumb).should==true
  end
  
  should 'have a thumbnail by default that use the content of column as path and invisible if path is broken' do
    a = Attached.new.to_thumb(:filename)
    a.should.match(/^<img.*\/>$/)
    a.should.match(/src='\?\d*'/)
    a.should.match(/onerror=\"this.style.display='none'\"/)
    a = Attached.new.set(:filename=>'/book.png').to_thumb(:filename)
    a.should.match(/^<img.*\/>$/)
    a.should.match(/src='\/book\.png\?\d*'/)
    a.should.match(/onerror=\"this.style.display='none'\"/)
  end
  
  should 'have a special thumbnail behavior adapted to StashMagic if that Gem is used on the specific field' do
    a = Attached.new.set(:map=>"{:type=>'image/png',:name=>'map.png',:size=>20}")
    b = Attached.new.set(:map=>"{:type=>'application/pdf',:name=>'map.pdf',:size=>20}")
    Attached.stash :map # I do it only here so that I could enter test values as a simple string
    field = a.to_thumb(:map)
    field.should.match(/^<img.*\/><br \/>$/)
    field.should.match(/src='\/stash\/Attached\/tmp\/map\.stash_thumb\.gif\?\d*'/)
    field.should.not.match(/onerror=\"this.style.display='none'\"/)
    # No preview if field is nil or not an image
    a.map = nil
    a.to_thumb(:map).should==''
    b.to_thumb(:map).should==''
  end
end

describe 'Crushyfield types' do
  
  should 'have a type that does nothing' do
    Attached.new.crushyinput(:filesize).should==''
  end
  
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
  
  should 'build parent field with a wrapped version of parent_model#to_dropdown' do
    Haiku.new.crushyinput(:author_id).should.match(/^<select.*>#{Regexp.escape Author.to_dropdown}<\/select>$/)
  end
  
  should 'display a preview with an attachment field whenever it is possible' do
    a = Attached.new.set(:filename=>'/book.png')
    a.crushyinput(:filename).should.match(/^#{Regexp.escape a.to_thumb(:filename)}<input type='file'.*\/>\n$/)
  end
  
  should 'have field wrapped with a correct label' do
    ShippingAddress.new.crushyfield(:address_body).should.match(/<label for='#{Regexp.escape ShippingAddress.new.crushyid_for(:address_body)}'>Address body<\/label>/)
    ShippingAddress.first.crushyfield(:address_body).should.match(/<label for='#{Regexp.escape ShippingAddress.first.crushyid_for(:address_body)}'>Address body<\/label>/)
    ShippingAddress.new.crushyfield(:address_body,{:name=>'Address Lines'}).should.match(/<label for='#{Regexp.escape ShippingAddress.new.crushyid_for(:address_body)}'>Address Lines<\/label>/)
  end
  
  should 'have errors reported for fields' do
    h = Haiku.new
    h.valid?.should==false
    h.crushyfield(:title).should.match(/<span class='crushyfield-error-list'> - is not good - smells like shit<\/span>/)
    h.crushyfield(:title).should.match(/^<p class='crushyfield crushyfield-error'/)
    h.crushyfield(:body).should.match(/<span class='crushyfield-error-list'><\/span>/)
    h.crushyfield(:body).should.match(/^<p class='crushyfield '/)
    # Not validated
    Haiku.new.crushyfield(:title).should.match(/<span class='crushyfield-error-list'><\/span>/)
    Haiku.new.crushyfield(:title).should.match(/^<p class='crushyfield '/)
  end
  
end

describe 'Crushyform' do
  
  should 'have a helper for creating the whole form with all current values (no per-field customization)' do
    form = Haiku.new.crushyform([:title,:body,:author_id], '/receive_haiku', 'POST')
    form.should.match(/action='\/receive_haiku'/)
    form.should.match(/method='POST'/)
    Haiku.new.crushyform([:title,:body,:author_id], '/receive_haiku').should==form # default to POST
    Haiku.new.crushyform(['title','body','author_id'], '/receive_haiku').should==form # turn keys into symbols
  end
  
  should 'have only fields not wrapped with a form tag if action is nil' do
    form = Haiku.new.crushyform([:title,:body,:author_id])
    form.should.not.match(/form/)
    form.should.not.match(/action/)
    form.should.not.match(/enctype/)
  end
  
  should 'use crushyform_schema keys by default for the list of field to put in the form' do
    form = Haiku.new.crushyform
    form.should.not==''
    Haiku.crushyform_schema.keys.each do |k|
      form.should.match(/#{Haiku.new.crushyid_for(k)}/)
    end
  end
  
end

::FileUtils.rm_rf(ROOT+'/test/stash') if F.exists?(ROOT+'/test/stash')
