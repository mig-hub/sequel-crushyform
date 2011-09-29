module ::Sequel::Plugins::Crushyform
  
  module ClassMethods
    def crushyform_version; [0,1,4]; end
    # Schema
    def crushyform_schema
      @crushyform_schema ||= default_crushyform_schema
    end
    def default_crushyform_schema
      out = {}
      db_schema.each do |k,v|
        out[k] = if respond_to?(:schema) && (@schema.columns.find{|c|c[:name]==k}||{:type=>nil})[:type]==:text
          {:type=>:text} # Using :schema plugin is the safest
        elsif [:sqlite,:mysql].include?(@db.database_type) && v[:db_type]=='text'
          {:type=>:text} # Without :schema plugin Postgres uses text even for strings
        else
          {:type=>v[:type]}
        end
      end
      association_reflections.each{|k,v|out[v[:key]]={:type=>:parent} if v[:type]==:many_to_one}
      @schema.columns.each{|c|out[c[:name]]=out[c[:name]].update(c[:crushyform]) if c.has_key?(:crushyform)} if respond_to?(:schema)
      out
    end
    # Types
    def crushyform_types
      @crushyform_types ||= {
        :none => proc{''},
        :string => proc do |m,c,o|
          "<input type='%s' name='%s' value=\"%s\" id='%s' class='%s' %s />%s\n" % [o[:input_type]||'text', o[:input_name], o[:input_value], m.crushyid_for(c), o[:input_class], o[:required]&&'required', o[:required]]
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
          "<textarea name='%s' id='%s' class='%s' %s>%s</textarea>%s\n" % [o[:input_name], m.crushyid_for(c), o[:input_class], o[:required]&&'required', o[:input_value], o[:required]]
        end,
        :date => proc do |m,c,o|
          o[:input_value] = o[:input_value].strftime("%Y-%m-%d") if o[:input_value].is_a?(Sequel.datetime_class)
          o[:required] = "%s Format: yyyy-mm-dd" % [o[:required]]
          crushyform_types[:string].call(m,c,o)
        end,
        :time => proc do |m,c,o|
          o[:input_value] = o[:input_value].strftime("%T") if o[:input_value].is_a?(Sequel.datetime_class)
          o[:required] = "%s Format: hh:mm:ss" % [o[:required]]
          crushyform_types[:string].call(m,c,o)
        end,
        :datetime => proc do |m,c,o|
          o[:input_value] = o[:input_value].strftime("%Y-%m-%d %T") if o[:input_value].is_a?(Sequel.datetime_class)
          o[:required] = "%s Format: yyyy-mm-dd hh:mm:ss" % [o[:required]]
          crushyform_types[:string].call(m,c,o)
        end,
        :parent => proc do |m,c,o|
          parent_class = association_reflection(c.to_s.sub(/_id$/,'').to_sym).associated_class
          option_list = parent_class.to_dropdown(o[:input_value])
          "<select name='%s' id='%s' class='%s'>%s</select>\n" % [o[:input_name], m.crushyid_for(c), o[:input_class], option_list]
        end,
        :attachment => proc do |m,c,o|
          "%s<input type='file' name='%s' id='%s' class='%s' />%s\n" % [m.to_thumb(c), o[:input_name], m.crushyid_for(c), o[:input_class], o[:required]]
        end,
        :select => proc do |m,c,o|
          out = "<select name='%s' id='%s' class='%s'>\n" % [o[:input_name], m.crushyid_for(c), o[:input_class]]
          o[:select_options] = m.__send__(o[:select_options]) unless o[:select_options].kind_of?(Array)
          if o[:select_options].kind_of?(Array)
            o[:select_options].each do |op|
              key,val = op.kind_of?(Array) ? [op[0],op[1]] : [op,op]
              selected = 'selected' if val==o[:input_value]
              out << "<option value='%s' %s>%s</option>\n" % [val,selected,key]
            end
          end
          out << "</select>%s\n" % [o[:required]]
        end
      }
    end
    # What represents a required field
    # Can be overriden
    def crushyfield_required; "<span class='crushyfield-required'> *</span>"; end
    # Stolen from ERB
    def html_escape(s)
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
    # Cache dropdown options for children classes to use  
    # Meant to be reseted each time an entry is created, updated or destroyed  
    # So it is only rebuild once required after the list has changed  
    # Maintaining an array and not rebuilding it all might be faster  
    # But it will not happen much so that it is fairly acceptable  
    def to_dropdown(selection=nil, nil_name='** UNDEFINED **')
      dropdown_cache.inject("<option value=''>#{nil_name}</option>\n") do |out, row|
        selected = 'selected' if row[0]==selection
        "%s%s%s%s" % [out, row[1], selected, row[2]]
      end
    end
    def dropdown_cache
      @dropdown_cache ||= label_dataset.inject([]) do |out,row|
        out.push([row.id, "<option value='#{row.id}' ", ">#{row.to_label}</option>\n"])
      end
    end
    def reset_dropdown_cache; @dropdown_cache = nil; end
    # Generic column names for label
    LABEL_COLUMNS = [:title, :label, :fullname, :full_name, :surname, :lastname, :last_name, :name, :firstname, :first_name, :login, :caption, :reference, :file_name, :body]
    # Column used as a label
    def label_column; @label_column ||= LABEL_COLUMNS.find{|c|columns.include?(c)}; end
    def label_column=(n); @label_column=n; end
    # Dataset selecting only columns used for building names
    def label_dataset; select(:id, label_column); end
    # Human readable name
    def human_name; self.name.gsub(/([A-Z]+)([A-Z][a-z])/,'\1 \2').gsub(/([a-z\d])([A-Z])/,'\1 \2'); end
  end
  
  module InstanceMethods
    def crushyform(columns=model.crushyform_schema.keys, action=nil, meth='POST')
      columns.delete(:id)
      fields = columns.inject(""){|out,c|out+crushyfield(c.to_sym)}
      enctype = fields.match(/type='file'/) ? "enctype='multipart/form-data'" : ''
      action.nil? ? fields : "<form action='%s' method='%s' %s>%s</form>\n" % [action, meth, enctype, fields]
    end
    # crushyfield is crushyinput but with label+error
    def crushyfield(col, o={})
      return '' if (o[:type]==:none || model.crushyform_schema[col][:type]==:none)
      field_name = o[:name] || model.crushyform_schema[col][:name] || col.to_s.sub(/_id$/, '').tr('_', ' ').capitalize
      error_list = errors.on(col).map{|e|" - #{e}"} if !errors.on(col).nil?
      "<p class='crushyfield %s'><label for='%s'>%s</label><span class='crushyfield-error-list'>%s</span><br />\n%s</p>\n" % [error_list&&'crushyfield-error', crushyid_for(col), field_name, error_list, crushyinput(col, o)]
    end
    def crushyinput(col, o={})
      o = model.crushyform_schema[col].dup.update(o)
      o[:input_name] ||= "model[#{col}]"
      o[:input_value] = o[:input_value].nil? ? self.__send__(col) : o[:input_value]
      o[:input_value] = model.html_escape(o[:input_value]) if (o[:input_value].is_a?(String) && o[:html_escape]!=false)
      o[:required] = o[:required]==true ? model.crushyfield_required : o[:required]
      crushyform_type = model.crushyform_types[o[:type]] || model.crushyform_types[:string]
      crushyform_type.call(self,col,o)
    end
    # This ID is used to have a unique reference for the input field.
    #
    #   Format: <id>-<class>-<column>
    #
    # If you plan to have more than one form for a new entry in the same page
    # you'll have to override this method because records without an id
    # have just 'new' as a prefix.
    # Which means there could be a colision.
    def crushyid_for(col); "%s-%s-%s" % [id||'new',self.class.name,col]; end
    # Used to determine a humanly readable representation of the entry on one line of text
    def to_label; model.label_column.nil?||self.new? ? [self.new? ? 'New' : nil, model.human_name, id].compact!.join(' ') : self.__send__(model.label_column).to_s.tr("\n\r", ' '); end
    # Provide a thumbnail for the column
    def to_thumb(c)
      current = self.__send__(c)
      if model.respond_to?(:stash_reflection) && model.stash_reflection.key?(c)
        !current.nil? && current[:type][/^image\//] ? "<img src='#{file_url(c, 'stash_thumb.gif')}?#{::Time.now.to_i.to_s}' /><br />\n" : ''
      else
        "<img src='#{current}?#{::Time.now.to_i.to_s}' width='100' onerror=\"this.style.display='none'\" />\n"
      end
    end
    # Reset dropdowns on hooks
    def after_save; model.reset_dropdown_cache; super; end
    def after_destroy; model.reset_dropdown_cache; super; end
  end
  
end
