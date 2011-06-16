We tried to make it as modular as possible but with sensible default values.

I am also aware that this documentation is new and might lack some crucial information
but feel free to drop me a line if you have any question.

HOW TO INSTALL ?
----------------

Crushyform is a Ruby Gem so you can install it with:

    sudo gem install sequel-crushyform

HOW TO USE ? (THE BASICS)
-------------------------

Crushyform is also a Sequel plugin so you can add the crushyform methods to all your models with:

    ::Sequel::Model.plugin :crushyform

Or you can just add it to one model that way:

    class BlogPost < ::Sequel::Model
      plugin :crushyform
      # More useful code from you
    end

Once you have it, that is when the magic begins.
You already can have a form for it:

    BlogPost.new.crushyform # Returns a nice form

This will return a form for your new model. Without any effort.  
If you try with an existing entry, it works as well (wow!).  
If you try with an entry that is not valid, error messages are incorporated (even more wow!).

Obviously you have a bit more control on that.
To start with, this method have arguments which are:

- List of columns (all of them by default)
- Action URL (when nil, which is the default option, the fields are not wrapped in a form tag)
- HTTP Method (POST by default)

So you can do that:

    BlogPost.new.crushyform( [:title,:body], "/new_blog", "GET" ) # Returns a nice form

Which will return a form (wrapped this time) with only the 2 fields :title and :body.
Options give the action URL and method.

Now say you want to have all the default options, but you want a wrapping form tag, you can do that:

    BlogPost.new.crushyform( model.crushyform_schema.keys, "/new_blog" ) # Returns a nice form (a crushy form to be precise)

You have to put the default value `model.crushyform_schema.keys` because in the order of priority, the list of columns is more important

This is due to the fact that in a real case scenario we are more likely to use the version without a wrapping form tag.
Mainly because we want to add some other hidden inputs like a destination, a method override in order to generate a PUT request or a pseudo XHR value.

Another reason might be that you want to add other fields to the tag. 
The default tag is pretty basic and is always considered multipart/form-data for simplicity.

THE CRUSHYFIELDS
----------------

As mentioned before, the form more like a way to gather all the field we're interested to have in a form.
Which means you can have more control than that.
You can have just one field at a time.
In order to do that, you have 2 methods:

- Model#crushyinput(column,options) which only gives you the input tag for the field
- Model#crushyfield(column,options) which does the same but wrapped in a paragraph tag with a label and an error list

Regarding the options, you have plenty of them.
We'll see later how we can set all of them in the crushyform schema but they all can be overriden when requesting the input tag.
Here is the list of schema-related options:

- :type is the crushyform type that is used for the field (default is :string)
- :input_name is the name used for the input tag (default is model[columnname])
- :input_value is the input value used for the input tag
- :input_type is the input type used for the input tag (default is text when applicable)
- :input_class is the class value used for the input tag
- :html_escape has to be set to false if you do not want the value to be escaped (default is true)
- :required text that says that the field is required (default is just blank). A ready-made value for that field is also available if you put `true` instead of a text. It is an asterisk with span class `crushyfield_required`

As you can see, a lot of things can be overriden at the last level.
There is another option just for Model#crushyfield that is called :name.
This is basically the name of the field in the label tag.
By default, this is the name of the column in a human readable way, which means
there are no underscore signs and foreign keys like :author_id will have the name: Author.

Here is an example:

    BlogPost[4].crushyfield( :title , { :name => "Enter Title", :required => true })

This will give you a full field for the column :title with a label saying "Enter Title" and an asterisk that says the field is required.
As mentioned before the :required can be the text to put, but for consistency, it is recommanded to wrap it in the same span with the class crushyfield-required.
So if you want to simply write required:

    <span class='crushyfield-required'> required</span>

But really this is good only if the text is different for that specific field.
You usually want to override the class method Model::crushyfield_required.
The default implementation is:

    def self.crushyfield_required
      "<span class='crushyfield-required'> *</span>"
    end

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
- :attachment is for attachments (who guessed?).

As you can see date/time/datetime field is a text input with a format specified on the side.
We used to deal with it differently in the past, but nowadays this is the kind of field that is better to keep basic and offer a better interface with javascript.
Better to give it a special :input_class through the options and make it a nice javascript date picker 
instead of trying to complicate something that is gonna be ugly at the end anyway.

Regarding the :attachment type, it should be able to work with any kind of system. 
We made it simple and customizable enough to adapt to many attachment solutions.
A called it :attachment because I never really use blobs, but it might be used with blobs as well.
Once again because it is very basic.

This is typically the kind of field that cannot really be guessed by crushyform.
So you have to declare it as an :attachment.
We see how it is done in the following chapter.

CRUSHYFORM SCHEMA
-----------------

So now some people might think that this is weird that you have to put the options each time you ask for a field.
Well, the good news is that you don't.
Most of the options on Model#crushyfield are just for specific cases where you want to override/force something.
Instead you have a crushyform_schema:

    BlogPost.crushyform_schema
    # returns something like:
    # {
    #   :title => { :type => :string },
    #   :body => { :type => :text },
    #   :created_on => { :type => :date },
    #   :picture => { :type => :string }
    # }

As you can see, it is already filled for you with the bare minimum.
Unfortunately the picture is a string, but a string that is really an image URL.
You can fix that with:

    BlogPost.crushyform_schema[:picture].update({ :type => :attachment })

Alright now when you ask for the form or just the :picture field, it is gonna be an file upload field.
But you also want the :title to be displayed as a mandatory field:

    BlogPost.crushyform_schema[:title].update({ :required => true })

You get the idea.

But there is even a better way if you use the :schema plugin at the same time.
You can add an option called :crushyform for each column.
For instance, in order to do the same thing as before:

    class BlogPost < ::Sequel::Model
      plugin :schema
      plugin :crushyform
      set_schema do
		    primary_key :id
		    String :title, :crushyform => {:required => true}
		    text :body
		    Date :created_on
		    String :picture, :crushyform => {:type => :attachment}
		  end
		  create_table unless table_exists?
		end

NOTE ABOUT TIME FIELDS
----------------------

If you want to use a proper time field (just time with no date), don't forget to declare it all lowercase in your schema.
Otherwise it will use the Time ruby class which is a time including the date:

  set_schema do
    primary_key :id
    Time :opening_hour   # type is :datetime
    time :opening_hour   # type is :time
  end

CSS CLASSES
-----------

- crushyfield-required is the class for the default required flag
- crushyfield is used on the wrapping paragraph tag of every fields
- crushyfield-error is used on the wrapping paragraph tag of a field containing errors
- crushyfield-error-list is on the span that wraps the list of errors (is just a span, not an html list though)

WHAT IS ALSO USEFULL OUTSIDE OF CRUSHYFORM ?
--------------------------------------------