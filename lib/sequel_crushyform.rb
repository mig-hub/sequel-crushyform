module ::Sequel::Plugins::Crushyform
  
  module ClassMethods
    # Schema
    def crushyform_schema
      @crushyform_schema ||= default_crushyform_schema
    end
    def crushyform_schema=(h); @crushyform_schema=h; end
    def default_crushyform_schema
      out = {}
      db_schema.each do |k,v|
        out[k] = if v[:db_type]=='text'
          {:type=>:text}
        else
          {:type=>v[:type]}
        end
      end
      @schema.columns.each{|c|out[c[:name]]=out[c[:name]].update(c[:crushyform]) if c.has_key?(:crushyform)} if respond_to?(:schema)
      association_reflections.each{|k,v|out[v[:key]]={:type=>:parent} if v[:type]==:many_to_one}
      out
    end
    # Types
    def crushyform_types
      @crushyform_types ||= {
        :string => proc do |m,c,o|
        end,
        :boolean => proc do |m,c,o|
        end,
        :text => proc do |m,c,o|
        end
      }
    end
    def crushyform_types=(h); @crushyform_types=h; end
  end
  
  module InstanceMethods
    def crushyfield(col, opts={})
      col = col.to_sym
      opts = self.class.crushyform_schema[col].update(opts)
      func = self.class.crushyform_types.has_key?(opts[:type]) ? self.class.crushyform_types(opts[:type]) : self.class.crushyform_types(:string)
      func.call(self,col,opts)
    end
  end
  
end