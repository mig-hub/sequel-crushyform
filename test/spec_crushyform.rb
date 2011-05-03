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
    Boolean :published, :default => true
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

