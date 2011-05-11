CRUSHYFORM
----------

options:
- :type is the crushyform type that is used for the field (default is :string)
- :input_name is the name used for the input tag (default is model[columnname])
- :input_value is the input value used for the input tag
- :input_type is the input type used for the input tag (default is text when applicable)
- :input_class is the class value used for the input tag
- :html_escape has to be set to false if you do not want the value to be escaped (default is true)
- :required text that says that the field is required (default is just blank)
A ready-made value for that field is also available if you put `true` instead of a text. It is an asterisk with span class `crushyfield_required`

TYPES OF FIELD
--------------

- :string is the default one so it is used when the field is :string type or anyone that is not in the list like :integer for instance
- :none returns a blank string
- :boolean
- :text
- :date is in the format YYYY-MM-DD because it is accepted by sequel setters as-is
- :time is in the format HH:MM:SS because it is accepted by sequel setters as-is
- :datetime is in the format YYYY-MM-DD HH:MM:SS because it is accepted by sequel setters as-is
- :parent is a dropdown list to chose from
- :attachment is for attachments saved on the file system. It tries to be customizable enough to adapt to many attachment solutions

NOTE ABOUT TIME FIELDS
----------------------

If you want to use a proper time field (just time with no date), don't forget to declare it all lowercase in your schema.
Otherwise it will use the Time ruby class which is a time including the date:

  set_schema do
    primary_key :id
    Time :opening_hour   # type is :datetime
    time :opening_hour   # type is :time
  end
