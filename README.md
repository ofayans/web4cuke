### Introduction
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

### How to use this? 

- Add `gem 'web4cucumber'` to you Gemfile and run `bundle install`
- In your project in one of your lib/*.rb files add `require "web4cucumber"` and inherit your own class from Web4Cucumber one, like this:
```
class Web < Web4Cucumber
  def initialize(options)
  super(options)
  # Add here some code specific to your project, like 
  # @@logged_in = false
end
```

- In your features/support/env.rb in Before hook instantiate your beautiful class:
```
  options = {
    :base_url => "http://base_url_of_your_project",
    :browser => :firefox, # or :chrome. Other browsers are not supported yet
    :rules_path => "path_to_the_folder_with_your_yaml_files",
    :logger => @logger 
    # You need to pass an object that will do the logging for you. I believe you have it implemented.
    # If not, please take a look at the examples/testproject/lib/logger.rb.
  }
  @web = Web.new(options)

```
From now on you will have @web, an instance of Web4Cucumber class with a bunch of convenient methods for high-level interactions with the browser, and, a browser running by default in the headless mode. For development and debugging purposes, however I recommend setting DEBUG_WEB environmental variable to *true* so that you will be presented with a visible browser window.

- Once this preparation is done, let's try to understand how to write yaml files. The key concept Web4Cucumber is built around is an *action*. 
Action is any set of user actions you want to automate, it could be web search, form submissions, data upload etc. An action is described in a yaml file with the following structure:

```
our_test_action:
  pages:
    - 'first_page'
    - 'second_page'
  final_checkpoints:
    alert_success:
      selector:
        text: 'You have successfully performed whatever you intended'

first_page:
  url: '/some_relative_path/testme'
  expected_fields:
     field_one_on_page_one:
       type: textfield
       selector:
         id: 'i-am-field-1'
     field_two_on_page_one:
       type: textfield
       selector:
         class: 'generic-field-2-class'
  checkpoints:
    sometext:
      selector:
        text: 'I am text one on page one'
    someothertext:
      selector:
        text: 'I am text two on page one'
  commit:
    selector:
      text: 'Click me'

second_page:
  sleep 2 # wait 2 seconds till the page is loaded
  expected_fields:
    field_one_on_page_two:
      type: filefield
      selector:
        id: 'upload-something'
    field_two_on_page_two:
      type: textfield
      selector:
        xpath '//*[@id="fancy_something"]/span'
      def_value: 'If you dont pass :field_two_on_page_two value, this text will go there'
  checkpoints:
    sometext:
      selector:
        text: 'I am text one on page two'
    someothertext:
      selector:
        text: 'I am text two on page two'
  negative_checkpoints:
    error_message:
      selector:
        text: 'I am a critical error message! Wish you never see me on this page!'
  commit:
    scroll: true 
    # sometimes the element you need is outside the area of the virtual viewport
    # so webdriver is unable to interact with it. Use this keyword to execute a simple 
    # javascript *scroll_into_view* function
    selector:
      text: 'Click me too'
``` 
If you take a closer look at this yaml structure, you'll notice that it describes two web pages. The first one is accessed through relative url "/some_relative_path/testme" that is being appended to your project's base_url (used during Web initialization).
The second page is accessed by clicking the "Click me" button on the first page. The yaml file describes 2 textfields on first page and one textfield and one filefield on the second page. It also describes checkpoints - elements whose presence will be asserted during the action execution. We can provide default values for textfields right inside the yaml with the *def_value* keyword. Now the most interesting question: how do we use that?

- The whole workflow would look like this. You would create your step:

```
When I run my beautiful action with:
  |option                |value           |
  |field_one_on_page_one |some text       |
  |field_two_on_page_one | some other text|
  |field_one_on_page_two | lib/files/myfile| 
  # We remember that field_one_on_page_two is a filefield
  # And we leave default value for second field on the page two.
```
Then you would write your step definition:
```
When /^I run my beautiful action with:$/ do |table|
  options = {}
  table.rows.each do |row|
    options[row[0].to_sym] = row[1]
  end
  @result = @web.run_action(:our_test_action, options)
end
```
As you can see, field_names declared in the yaml files, like *field_one_on_page_one* are used as keys in the hash, passed to the *@web.run_action* method as the second parameter. First parameter being the name of the action also declared in the yaml file.
If you then inspect the @result object then ideally you would get something like this:
```
pp @result
{:result=>true,
 :failed_positive_checkpoints=>[],
 :failed_negative_checkpoints=>[],
 :errors=>[]}

```
If something went wrong and the webdriver was unable to find some checkpoints or other fields described in the yaml file, then the @result[:result] would be changed to *false* and @result[:failed_positive_checkpoints] array will be populated with the elements that were not found, @result[:failed_negative_checkpoints] - with elements you described in *negative_checkpoints* and @result[:errors] - with exception messages. Also, a *screenshots* folder will be created in your working directory, containing browser screenshot of the page that caught an error.

### Yaml file structure
Now we have to master yaml file creation in details.
The structure of yaml files supported by Web4Cucumber library is quite flexible. You could store page descriptions separately from action descriptions, or you could store all your actions in one files, only make sure each action has a precide list of corresponding pages in exactly the same order that they appear during action execution. Besides list of pages only one keyword is supported under an action:
*final_checkpoints*. This is a list of elements whose presence we expect once the action is finished.

The key part of an *action* is a *page*. The following keywords can be used under the page description:
1. expected_fields 
2. checkpoints
3. negative_checkpoints
4. links
5. base_url
6. url
7. sleep
8. commit

- *expected_fields* is a section where field descriptions go. Field structure will be discussed in more details later.
- *checkpoints*, as was mentioned above, is a list of named web elements you expect to be present on a web page.
- *negative_checkpoints*  similarly a list of named elements you do not expect on a page.
- *links* Is a list of links on a page that need to be checked in a web crawler kind of way. For each link you specify the selector by which the link can be accessed and a number of checkpoints (web elements) you wish to check on a page accesible via that particular link. A typycal link section of a page would look like this:
```
  :links:
    :getstarted:
      :selector:
        :text: "Get Started"
      :checkpoints:
        :getstarted:
          :selector:
            :text: "Getting Started"
    :securitypolicy:
      :selector:
        :text: "Security Policy"
      :checkpoints:
        :securityinformation:
          :selector:
            :text: "Security Information"
```
In this example webdriver would click first on a link with test "Get Started", check that the page has an element with text "Get Started", then get back, click on the link with text "Security Policy", check that the page has an element with text "Security Information", then again get back.  
- *base_url* - needed when you need to perform some action on a third-party software (for integration cases for example)
- *url* - a relative url path of the page (base_url for your project is passed to the Web4Cucumber class during instance initialization)
You can have a variable part of relative url, embraced between angle brackets. For example, if you have "/blog/<blogtype>/new" url in your yaml file and then pass {:blogtype=>'public'} in your options to the @web.run_action method, the webdriver will access the /blog/public/new relative url. 
- *sleep* - a sleep interval in seconds, how long to wait before doing anything on this page: useful for slow loading pages
- *commit* - well this is a commit button - the one you normally click to submit a form. The only tricky part about commit comes when the page presents you with a javascript popup. In this case the commit section would look like this:
```
commit:
  type: alert
```
that's it!

The last thing needed to be mentioned is the structure of the *field* itself. The *field* is mapped to a key in *options* passed to the @web.run_action method through it's name. That means, you pass a text to the particular textfield in the following way:
1. Describe the field in the yaml file
```
expected_fields:
  login:
    type: 'textfield'
    selector:
      id: 'user-login'
```
2. pass the value:

```@web.run_action(:some_action_name, {:login=>'username@example.com', <...other_options_go_here...>})```
That's it.
Different elemet types get treated differently by webdriver, textfields can not be clicked the way buttons do, so you need to provide element type. The following types are supported:
- select - a dropdown list. You need to pass the element value
- checkbox - self-explanatory
- radio - same here
- textfield - you can provide a text that will be inputted in this textfield
- textarea - self-explanatory
- filefield - provide a full path to the file you would upload here
- a  -link
- element any element that can be simply clicked. No need to provide the type in this case, it will be implied by default.

### Tips and tricks

1. Sometimes a web element may or may not be present on a page depending on the
   user workflow. Say, depending on whether a user is freshly registered or
   not, he may be presented with the checkbox to accept license agreement. If
   you describe this element in the page and it will not be there, an action
   will fail although it really passes. To make it pass, then, you need to mark
   an element optional. This is done through *may_absent* keyword, like this:
   ```
   expected_fields:
     field_one:
       type: textfield
       selector: 
         id: 'i-always-exist'
    field_two:
      type: checkbox
      selector:
        id 'i-am-optional'
      may_absent: true

   ```

2. Sometimes you need a way to stop the action execution at some point to
   perform some unusual actions, like clicking "Cancel" button or anything
   else. This is possible through passing *:stop_at* key with the name of the
   page as a value in options passed to the *run_action* method. Imagine you
   have an action that involves accessing three pages and you want to stop at
   the last page to click some unusual button:

   ```
   my_beautiful_action:
     expected_pages:
       - 'page_one'
       - 'page_two'
       - 'page_three'
   ```
   Then in you step definition construct the option hash like this:
   ```
   options = {
     :some_field => 'value'
     :some_other_field => 'other_value'
     :stop_at => :third_page
     }
     @result = @web.run_action(:my_beautiful_action, options)
   ```
   then in the next step you can explicitly access whatever element you like on
   the third page of your action

3. Similarly, sometimes you need a way to stop the execution and drop into a
   ruby shell to try some low-level interaction with the webdriver. Well, this
   is easily achieved, just pass 
   ```
   :debug_at => :page_three
   ```
   in the options and yo will be dropped into a shell right after page three is
   loaded in the browser window.
