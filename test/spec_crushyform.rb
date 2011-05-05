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
  end
  create_table unless table_exists?
  one_to_many :haikus
end

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

describe 'Crushyfield types' do
  should 'escape html by default on text fields' do
    Haiku.new.crushyinput(:title, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should=="<input type='text' name='model[title]' value='&lt;ScRipT &gt;alert('test');&lt;/ScRipT &gt;' id='new-Haiku-title' class='' />\n"
    Haiku.new.crushyinput(:body, {:input_value=>"<ScRipT >alert('test');</ScRipT >"}).should=="<textarea name='model[body]' id='new-Haiku-body' class=''>&lt;ScRipT &gt;alert('test');&lt;/ScRipT &gt;</textarea>\n"
  end
  should 'not escape html on text field if specified' do
    Haiku.new.crushyinput(:title, {:input_value=>"<ScRipT >alert('test');</ScRipT >", :html_escape => false}).should=="<input type='text' name='model[title]' value='<ScRipT >alert('test');</ScRipT >' id='new-Haiku-title' class='' />\n"
    Haiku.new.crushyinput(:body, {:input_value=>"<ScRipT >alert('test');</ScRipT >", :html_escape => false}).should=="<textarea name='model[body]' id='new-Haiku-body' class=''><ScRipT >alert('test');</ScRipT ></textarea>\n"
  end
  should 'not keep one-shot vars like :input_value in the crushyform_schema' do
    Haiku.crushyform_schema[:title][:input_value].should==nil
  end
  should 'be able to turn the :string input into other similar types like password or hidden' do
    Haiku.new.crushyinput(:title, {:input_type=>'password'}).should=="<input type='password' name='model[title]' value='' id='new-Haiku-title' class='' />\n"
  end
  should 'set booleans correctly' do
    Haiku.new.published.should==nil
    Haiku.new.crushyinput(:published).should=="<span class=''><input type='radio' name='model[published]' value='true' id='new-Haiku-published'  /> <label for='new-Haiku-published'>Yes</label> <input type='radio' name='model[published]' value='false' id='new-Haiku-published-no' checked /> <label for='new-Haiku-published-no'>No</label></span>\n"
    Haiku.new.crushyinput(:published,{:input_value=>true}).should=="<span class=''><input type='radio' name='model[published]' value='true' id='new-Haiku-published' checked /> <label for='new-Haiku-published'>Yes</label> <input type='radio' name='model[published]' value='false' id='new-Haiku-published-no'  /> <label for='new-Haiku-published-no'>No</label></span>\n"
    Haiku.new.crushyinput(:published,{:input_value=>false}).should=="<span class=''><input type='radio' name='model[published]' value='true' id='new-Haiku-published'  /> <label for='new-Haiku-published'>Yes</label> <input type='radio' name='model[published]' value='false' id='new-Haiku-published-no' checked /> <label for='new-Haiku-published-no'>No</label></span>\n"
  end
end

