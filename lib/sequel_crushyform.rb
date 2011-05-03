module ::Sequel::Plugins::Crushyform
  
  module ClassMethods
    def crushyform_schema
      @crushyform_schema ||= default_crushyform_schema
    end
    def crushyform_schema=(h); @crushyform=h; end
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
  end
  
  module InstanceMethods
    def crushyfield(col, type=nil)
      col = col.to_sym
      type ||= self.class.crushyform_schema[col]
    end
  end
  
end