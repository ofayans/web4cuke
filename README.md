The main filosophy behind this project is:
Separate the data from the logic as much as you possibly can. Have you had to
go through a tremendous ruby module with hundreds of methods which click
buttons, input text in form fields, randomly wait (probably, till the page is
loaded) and randomly take screenshots? Have you dreamed to have a way to store
test data in a separate simple text files and feed them to the cucumber? 
Or maybe you have hundreds of scenarios looking like this: 
``` 
 When I click the element ":id=>'click_me'"
 And I write "hello" in the form with ":id=>'topic'"
 And I write "Blahblahblah" in the form with ":id=>'body'"
 And I click the element ":id=>'submit'"
 Then the page shuold contain "Success"
```
And you sometimes ask yourselves "Is it a cucumber way to write scenarios like
this?" Well the answer is no. Probably, all you need is to write a couple of
steps instead:
```
 When I create a blogpost with:
  |title|body|
  |hello|Blahblahblah|
 Then the step should succeed
```
And have a simple yaml file describing the corresponding webpage, that would
look like this:
```
blogpost_create:
  pages:
    - 'blogpost_create_page'
blogpost_create_page:
  url: '/blogposts/new'
  expected_fields:
    title:
      type: 'textfield'
      selector:
        id: 'topic'
    body:
      type: 'textfield'
      selector:
        id: 'body'
  commit:
    selector:
      id: 'commit'
```
This library implements an abstraction layer between cucumber logic and Watir
webdriver. Using this library you no longer need to write the Watir-aware Ruby
code for low-level browser interaction. Instead you describe your pages and
actions to be performed in Web UI of your product in simple yaml-formatted
files. This approach allows you to separate the application data (html
properties of page elements) from test logic. 

How to use this? 

- Add `gem 'web4cuke'` to you Gemfile and run `bundle install`
- In your project in one of your lib/*.rb files add `require "web4cuke"` and inherit your own class from Web4Cuke one, like this:
```
class Web < Web4Cuke
  def initialize(options)
  super(options)
  # Add here some code specific to your project, like 
  # @@logged_in = false
end
```

- In your features/support/env.rb in Before hook instatiate your beautiful class:
```
  options = {
    :base_url => "http://base_url_of_your_project",
    :browser => :firefox, # or :chrome. Other browsers are not supported yet
    :rules_path => "path_to_the_folder_with_your_yaml_files",
    :logger => @logger # You need to pass an object that will do the logging for you. I believe you have it implemented. If not, please take a look in the examples/testproject folder.
  }
  @web = Web.new(options)

```
From now on you will have @web, an instance of Web4Cuke class with a bunch of convenient methods for high-level interactions with the browser, and, a browser running by default in the headless mode. For development and debugging purposes, however I recommend setting DEBUG_WEB environmental variable to *true* so that you will be presented with a visible browser window.