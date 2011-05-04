module ::Sequel::Plugins::Crushyform
  
  module ClassMethods
    # Schema
    def crushyform_schema
      @crushyform_schema ||= default_crushyform_schema
    end
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
          "<input type='%s' name='%s' value='%s' class='%s' />\n" % [o[:input_type]||'text', o[:input_name], o[:input_value], o[:input_class]]
        end,
        :boolean => proc do |m,c,o|
        end,
        :text => proc do |m,c,o|
        end
      }
    end
  end
  
  module InstanceMethods
    # crushyfield is crushyinput but with label+error
    def crushyfield(col, o={})
      crushyinput(col, opts)
    end
    def crushyinput(col, o={})
      o = self.class.crushyform_schema[col].update(o)
      o[:input_name] ||= "model[#{col}]"
      o[:input_value] ||= self.__send__(col)
      o[:input_value] = html_escape(o[:input_value]) unless o[:html_escape]==false
      crushyform_type = self.class.crushyform_types.has_key?(o[:type]) ? self.class.crushyform_types[o[:type]] : self.class.crushyform_types[:string]
      crushyform_type.call(self,col,o)
    end
    # Stolen from ERB
    def html_escape(s)
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
  end
  
end