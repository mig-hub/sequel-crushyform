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
          "<input type='%s' name='%s' value='%s' id='%s' class='%s' />\n" % [o[:input_type]||'text', o[:input_name], o[:input_value], m.crushyid_for(c), o[:input_class]]
        end,
        :boolean => proc do |m,c,o|
          crushid = m.crushyid_for(c)
          s = ['checked', nil]
          s.reverse! unless o[:input_value]
          out = "<span class='%s'>"
          out += "<input type='radio' name='%s' value='true' id='%s' %s /> <label for='%s'>Yes</label> "
          out += "<input type='radio' name='%s' value='false' id='%s-no' %s /> <label for='%s-no'>No</label>"
          out += "</span>\n"
          out % [o[:input_class], o[:input_name], crushid, s[0], crushid, o[:input_name], crushid, s[1], crushid]
        end,
        :text => proc do |m,c,o|
          "<textarea name='%s' id='%s' class='%s'>%s</textarea>\n" % [o[:input_name], m.crushyid_for(c), o[:input_class], o[:input_value]]
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
      o = self.class.crushyform_schema[col].dup.update(o)
      o[:input_name] ||= "model[#{col}]"
      o[:input_value] = o[:input_value].nil? ? self.__send__(col) : o[:input_value]
      o[:input_value] = html_escape(o[:input_value]) if (o[:input_value].is_a?(String) && o[:html_escape]!=false)
      crushyform_type = self.class.crushyform_types.has_key?(o[:type]) ? self.class.crushyform_types[o[:type]] : self.class.crushyform_types[:string]
      crushyform_type.call(self,col,o)
    end
    # Stolen from ERB
    def html_escape(s)
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
    # This ID is used to have a unique for the input field.
    #
    #   Format: <id>-<class>-<column>
    #
    # If you plan to have more than one form for a new entry in the same page
    # you'll have to override this method because for records without an id
    # have just 'new' as a prefix
    def crushyid_for(col); "%s-%s-%s" % [id||'new',self.class.name,col]; end
  end
  
end