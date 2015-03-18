# Copyright 2015 Red Hat, Inc. and/or its affiliates.
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'watir-webdriver'
require 'headless'

class Web4Cucumber
  def positive_checkpoint_lookup(checkpoints, result, options=nil)
    # checkpoints should be a hash
    checkpoints.each_pair { |key, value|
      if options
        begin
          value[:selector].each_pair do |how, what|
            options.keys.each do |optkey|
              if what.match Regexp.new("<#{optkey.to_s}>")
                what.gsub!("<#{optkey.to_s}>", options[optkey])
              end
            end
          end
        rescue NoMethodError
          raise "Please provide :selector: keyword in your checkpoint"
        end
      else
        @@logger.info "No options provided to checkpoint lookup"
      end
      if value.has_key? :sleep
        sleep value[:sleep]
      end
      secs = 0
      if value.has_key? :type
        myhash = {
          :a => @@b.a(value[:selector]),
          :text => @@b.element(value[:selector]),
          :input => @@b.input(value[:selector]),
          :select => @@b.select(value[:selector])
        }
        element = myhash[value[:type].to_sym]
      else 
        element = @@b.element(value[:selector])
      end
      until element.exists? or secs == 10 do
        sleep 1
        secs +=1
      end
      unless element.exists?
        @@logger.warn "#{key} with #{value[:selector]} can not found in #{@@b.url}"
        result[:failed_positive_checkpoints] << value[:selector] 
        result[:result] = false
      end
    }
    return result
  end

  def negative_checkpoint_lookup(checkpoints, result, options=nil)
    # checkpoints should be a hash
    sleep 7
    checkpoints.each_pair { |key, value|
      if options
        value[:selector].each_pair do |how, what|
          options.keys.each do |optkey|
            if what.match Regexp.new("<#{optkey.to_s}>")
              what.gsub!("<#{optkey.to_s}>", options[optkey])
            end
          end
        end
      else
        @@logger.info "No options provided to checkpoint lookup"
      end
      if @@b.element(value[:selector]).exists?
        @@logger.warn("#{key} with #{value} should not be display on the #{@@b.url}")
        result[:result] = false
        result[:failed_negative_checkpoints] << value[:selector]
      end
    }
    return result
  end

  def screenshot_save
    FileUtils.mkdir_p("screenshots")
    screenshot = File.join("screenshots", "error.png")
    @@b.driver.save_screenshot(screenshot)
    File::open("screenshots/output.html", 'w') {
      |f| f.puts(@@b.html) 
    }
  end

  
  def check_iframe(page_rules)
    if page_rules.has_key? :iframe
      return @@b.iframe(page_rules[:iframe][:selector])
    else
      return @@b
    end
  end

  def wait_for_element(element, may_absent)
    if @counter == 20
      screenshot_save
      unless may_absent # Sometimes not finding an element is OK, by design
        @result[:failed_positive_checkpoints] << element
        raise "Failed to find the #{element.to_s} element"
      end
    end
    sleep 1
    @counter += 1
  end

  def run_action(key, options)
    @result = {:result=>true, :failed_positive_checkpoints=>[], :failed_negative_checkpoints=>[], :errors => []}
    @@rules.freeze
    rules = Marshal.load(Marshal.dump(@@rules))
    action_rules = rules[key.to_sym]
    # loop over all pages...
    unless action_rules[:pages]
      @@logger.warn("No pages defined in the #{key} action")
    end
    action_rules[:pages].each { |page|
      # sometimes you need to stop the execution at some point to test whether
      # partial form data gets into the database, for example. In this case you
      # can provide :stop_at key with the name of the page for a value and the
      # action will be aborted once it gets into this page
      if options.has_key?(:stop_at) and options[:stop_at] == page
        @result[:result] = false
        @result[:errors] << "Execution stopped at page #{page}"
        return @result
      end
      # sometimes also it is pretty handy to be able to stick the debugger at
      # some point to have a human control over the webdriver instance. Then
      # in the same way stick the :debug_at keyword with the page name as a value 
      # into the options hash. The webdriver is available via @@b clas variable
      page_rules = rules[page.to_sym]
      unless page_rules
        @@logger.warn("The page #{page} not found in #{key} yaml file, maybe you have wrong yaml format...")
      end
      if page_rules.has_key? :url
        options.keys.each do |key|
          if page_rules[:url].match Regexp.new("<#{key.to_s}>")
            page_rules[:url].gsub!("<#{key.to_s}>", options[key])
          end
        end
      elsif page_rules.has_key? :base_url
        options.keys.each do |key|
          if page_rules[:base_url].match Regexp.new("<#{key.to_s}>")
            page_rules[:base_url].gsub!("<#{key.to_s}>", options[key])
          end
        end
      else
        @@logger.warn("#{page} has no url, trying default base_url")
      end
      if page_rules.has_key?(:url) or page_rules.has_key?(:base_url) or options.has_key?(:base_url)
        if options.has_key? :base_url
          url = options[:base_url]
        elsif page_rules.has_key? :base_url
          url = page_rules[:base_url]
        else
          # extract the host part from the current url. Makes it more flexible
          # than to use fixed @@base_url
          url = @@b.url.match(/(https?:\/\/.*?\/)/).captures[0]
        end
        if page_rules[:url].match /^\:\d+/
          if url.match /\:\d+/
            url.gsub!(/\:\d+\//, "")
          else
            url.gsub!(/\/$/, "")
          end
        end
        if page_rules[:url]
          url = url + page_rules[:url]
        end
        @@b.goto url
      end
      if page_rules.has_key? :sleep
        sleep page_rules[:sleep]
      end
      driver = check_iframe(page_rules) # substitute browser operating with main html 
      if options.has_key?(:debug_at) and options[:stop_at] == page
        require "byebug"
        byebug
      end
      # with the one operating with internal iframe
      unless page_rules[:expected_fields]
        @@logger.warn("No expected fields in #{page} page")
      end
      if page_rules.has_key? :expected_fields
        page_rules[:expected_fields].each_pair { |name, prop|
          # Beginning of page fields
          possible_elements = {
            # There could be more than one element with the same
            # properties and only one would be visible. As an example:
            # try adding more than one member to the same domain
            'select' => driver.select_lists(prop[:selector]),
            'checkbox' => driver.checkboxes(prop[:selector]),
            'radio' => driver.radios(prop[:selector]),
            'text_field' => driver.text_fields(prop[:selector]),
            'textfield' => driver.text_fields(prop[:selector]),
            'text_area' => driver.textareas(prop[:selector]),
            'textarea' => driver.textareas(prop[:selector]),
            'filefield' => driver.file_fields(prop[:selector]),
            'file_field' => driver.file_fields(prop[:selector]),
            'a' => driver.as(prop[:selector]),
            'element' => driver.elements(prop[:selector]) 
          }
          if prop.has_key?(:type) and not possible_elements.keys.include? prop[:type]
            @@logger.error("Unsupported element #{prop[:type]} for cucushift, so type error?")
          end
          result ||= true
          @counter = 0
          prop[:type] ||= 'element' # default to 'element' unless declared explicitly
          if prop[:type] == 'alert'
            begin
              @@b.alert.wait_until_present(3)
              @@b.alert.ok
            rescue Watir::Wait::TimeoutError => e
              @result[:result] = false
              @result[:errors] << "e.message"
            end
          end
          options.each do |key,value|
            if value.is_a? String and prop[:selector].values[0].match Regexp.new("<#{key.to_s}>")
              prop[:selector].values[0].gsub!("<#{key.to_s}>", options[key])
            end
          end
          elements = possible_elements[prop[:type]]
          element = nil
          elements.each do |elem|
            if elem.visible?
              element = elem
            end
          end
          if (options.has_key? name and options[name]) or prop.has_key? :def_value
            options.keys.each do |key|
              if prop[:selector].values[0].match Regexp.new("<#{key.to_s}>")
                prop[:selector].values[0].gsub!("<#{key.to_s}>", options[key])
              end
            end
            if prop[:selector].values[0].size == 0
              tmphash = prop[:selector].clone
              # if no default value provided, put the value from options
              tmphash.each_pair do |key, value|
                prop[:selector][key] = options[name.to_sym]
              end
            end
            if not element
              if not prop[:may_absent]
                @result[:result] = false
                @result[:errors] << "Unable to find element #{name.to_s} by the following #{prop[:selector].keys[0].to_s}: #{prop[:selector].values[0]}"
              end
            else
              until element.exists? do
                begin
                  wait_for_element(prop[:selector], prop[:may_absent])
                rescue Exception => e
                  result = false
                  break
                end
              end
              if result # continue if nothing failed
                begin
                  if prop[:type] == 'select'
                    if options[name.to_sym]
                      driver.select_list(prop[:selector]).select_value options[name.to_sym].to_s
                    elsif prop[:def_value]
                      driver.select_list(prop[:selector]).select_value prop[:def_value]
                    else
                      @@logger.error("Please, provide a value for this element: #{prop}")
                    end
                  elsif ['filefield', 'file-field', 'file_field'].include? prop[:type]
                    element.set options[name]
                  elsif ['checkbox', 'radio', 'a', 'element'].include? prop[:type]
                    element.click
                  elsif ['textfield', 'text_field', 'text_area', 'textarea'].include? prop[:type]
                    element.clear
                    if options.has_key? name.to_sym
                      options[name.to_sym].each_char do |c|
                        element.append c
                      end
                    elsif prop.has_key? :def_value
                      element.send_keys prop[:def_value]
                    else
                      @@logger.error("Please provide the value for this element: #{prop}")
                    end
                  end
                rescue => e
                  screenshot_save
                  @result[:result] = false
                  @result[:errors] << e.message
                end
              end
            end
          end
        } # End of page fields
      end
      # each form ends with commit button
      if page_rules.has_key? :checkpoints
        @result = positive_checkpoint_lookup(page_rules[:checkpoints], @result)
      else
        @@logger.info "No positive checkpoints defined..."
      end
      if page_rules.has_key? :negative_checkpoints
        @result = negative_checkpoint_lookup(page_rules[:negative_checkpoints], @result)
      else
        @@logger.info "No negative checkpoints defined..."
      end
      unless page_rules[:links]
        @@logger.warn("No links defined in the #{page} page")
      end
      if page_rules.has_key? :links
        page_rules[:links].each_pair do |key, value|
          @@b.a(value[:selector]).click
          if value.has_key? :checkpoints
            @result = positive_checkpoint_lookup(value[:checkpoints], @result)
          end
          @@b.back
        end
      end
      if page_rules.has_key? :commit
        if page_rules[:commit].has_key?(:selector)
          options.keys.each do |optkey|
            if page_rules[:commit][:selector].values[0].include? "<#{optkey}>"
              page_rules[:commit][:selector].values[0].gsub!("<#{optkey}>", options[optkey])
            end
          end
          myhash = {
            :input => @@b.input(page_rules[:commit][:selector]),
            :a => @@b.a(page_rules[:commit][:selector]),
            :button => @@b.button(page_rules[:commit][:selector])
          }
          begin
            if page_rules[:commit].has_key? :type
              button = myhash[page_rules[:commit][:type].to_sym]
            else
              button = @@b.element(page_rules[:commit][:selector])
            end
            begin
              button.exists?
            rescue Watir::Exception::MissingWayOfFindingObjectException
              button = @@b.input(page_rules[:commit][:selector])
            end
            if options[:scroll] or page_rules[:commit][:scroll]
              @@b.execute_script('arguments[0].scrollIntoView();', button)
              sleep 1 # This scroll sometimes takes up to a second
            end
            button.click
          rescue Exception => e
            @result[:result]=false
            @result[:error_message] = e.message
            screenshot_save
          end
        elsif page_rules[:commit].has_key?(:type) and page_rules[:commit][:type] == 'alert'
          @@b.alert.ok
        else
          raise "Please provide selector for #{page} page commit"
        end
      else
        @@logger.warn("No commit defined in the #{page} page")
      end
    } # end of pages
    if action_rules.has_key? :final_checkpoints
      @result = positive_checkpoint_lookup(action_rules[:final_checkpoints], @result, options=options)
    end
    if action_rules.has_key? :negative_final_checkpoints
      @result = negative_checkpoint_lookup(action_rules[:negative_final_checkpoints], @result, options=options)
    end
    unless @result[:failed_positive_checkpoints].empty? and @result[:failed_negative_checkpoints].empty?
      @result[:result] = false
    end
    return @result
  end

  def web_to_load(options)
    #returns an array of yaml files
    if options.has_key? :version
      return Dir.glob(File.join(options[:rules_path], options[:version], "*"))
    else
      return Dir.glob(File.join(options[:rules_path], "*"))
    end
  end

  def initialize(options)
    # Let's make sure, that we get all necessary options in the proper format
    obligatory_options = [:base_url, :rules_path, :logger]
    # :logger should be a Logger class instance with at least the following
    # methods implemented, taking a string as an argument: 
    # - info
    # - warn
    # - error
    unless options.is_a? Hash
      raise "Please provide a hash of options. Valid option keys are: :base_url, :browser, rules_path and :version
      The initialize method needs to know at least the base_url you want to test against and the :rules_path - path
      to the folder where you store your yaml files with action descriptions. Other keys are optional"
    end
    if options.keys & obligatory_options == obligatory_options
      @@base_url = options[:base_url]
      @@rules_path = options[:rules_path]
      @@logger = options[:logger]
    else
      raise "Please provide #{obligatory_options.join(', ')} in the passed options"
    end
    if options.has_key? :browser
      browser = options[:browser].to_sym
    else
      browser = :firefox
    end
    # OK, now all info from the options is processed, let's rock-n-roll!
    unless ENV.has_key? "DEBUG_WEB"
      @@headless = Headless.new 
      @@headless.start
    end
    file_names = web_to_load(options)
    @@rules = {}
    file_names.each do |filename|
      tmphash = YAML.load_file(filename)
      tmphash.each_pair do |key, value|
        if @@rules[key]
          raise "Duplicate entries detected in yaml file #{filename}: #{key}"
        else
          @@rules[key] = value
        end
      end
    end
    firefox_profile = Selenium::WebDriver::Firefox::Profile.new
    chrome_profile = Selenium::WebDriver::Remote::Capabilities.chrome()
    if ENV.has_key? "http_proxy"
      proxy = ENV["http_proxy"].scan(/[\w\.\d\_\-]+\:\d+/)[0] # to get rid of the heading "http://" that breaks the profile
      firefox_profile.proxy = chrome_profile.proxy = Selenium::WebDriver::Proxy.new({:http => proxy, :ssl => proxy})
      firefox_profile['network.proxy.no_proxies_on'] = "localhost, 127.0.0.1"
      ENV['no_proxy'] = '127.0.0.1'
    end
    client = Selenium::WebDriver::Remote::Http::Default.new
    client.timeout = 180
    if browser == :firefox
      @@b = Watir::Browser.new browser, :profile => firefox_profile, :http_client=>client
    elsif browser == :chrome
      @@b = Watir::Browser.new browser, desired_capabilities: chrome_profile
    else
      raise "Not implemented yet"
    end
#      @@b.window.resize_to(1920, 1080)
    @@b.goto @@base_url
  end

  def goto(params) # params should be a hash
    if params[:relative]
      # if provided relative url and current url contain port nuumbers - take
      # the explicitly provided one
      if params[:url].match /^:\d+/ 
        base_url.gsub!(/\/$/, "")
      end
      @@b.goto base_url + params[:url]
    else
      @@b.goto params[:url]
    end
    hash = {:result => true, :response => @@b.html}
  end

  def get_url
    return @@b.url
  end
    
  def cookie_option(cookies,opt = nil)
    @result = {:result => true, :failed_positive_checkpoints => nil,:message => nil}
    @cookies= @@b.cookies
    if opt == 'show'  
      return @cookies.to_a
    end
    if opt == 'select'
      new_cookies = []        
      cookies.each do |cookie|
        if @cookies[cookie[:name].to_sym]
          cookie[:value] = @cookies[cookie[:name].to_sym][:value]
          new_cookies << cookie
        else
          @result[:result]=false
          @result[:falied_negative_checkpoints] =[cookie]
          return @result
        end
      end  
      return new_cookies
    end 
    if opt == 'delete_all'
      unless @cookies.clear
        @result[:result]=false
        @result[:falied_negative_checkpoints] =[cookie]
      end
    end
    cookies.each do |cookie|
      if opt == 'add'
        if @cookies.add cookie[:name],cookie[:value]      
          @result[:result]=true
        else
          @result[:result]=false
          @result[:falied_negative_checkpoints] = [cookie]
        end
      end
      if opt == 'delete'
        unless @cookies.delete cookie[:name]
          @result[:result]=false
          @result[:falied_negative_checkpoints] = [cookie]
        end
      end
    end               
    return @result    
  end 

  def check_elements(elements, negate=nil, click=nil)
    # elements should be an array of hashes, for example:
    # [{:a=>{:class=>"block"}}, {:a=>{:href=>"/products"}}, {:a=>{:text=>"Log In"}}]
    @counter = 0
    @result = {:result=>true,
               :failed_positive_checkpoints => [],
               :failed_negative_checkpoints => [], 
               :errors => []}
    elements.each do |element|
      myhash = {
        :a=>@@b.a(element.values[0]),
        :textfield=>@@b.text_field(element.values[0]),
        :filefield=>@@b.file_field(element.values[0]),
        :input=>@@b.input(element.values[0]),
        :element=>@@b.element(element.values[0]),
        :pre=>@@b.element(element.values[0]),
        :select=>@@b.select(element.values[0]),
        :option=>@@b.element(element.values[0])
      }
      if negate
        if myhash[element.keys[0]].exists? and myhash[element.keys[0]].visible?
          @result[:result] = false
          @result[:failed_negative_checkpoints] << [element]
          # must be an array for consistency
        end
      else
        unless myhash[element.keys[0]].exists?
          screenshot_save
          @result[:result] = false
          @result[:failed_positive_checkpoints] << element
        end
        if click
          begin
            myhash[element.keys[0]].click
          rescue => e
            screenshot_save
            @result[:result] = false
            @result[:failed_positive_checkpoints] << element
            @result[:errors] << e.message
          end
        end
      end
    end
    return @result
  end

  def element_click(element)
    check_elements([element], negate = nil, click=true)
  end

  def value_select(element_selector, value)
    result = {
      :result => true,
      :failed_positive_checkpoints => [],
      :errors => []
    }
    until @@b.select_list(element_selector).exists? do
      begin
        wait_for_element(element_selector)
      rescue => e
        result[:result] = false
        result[:failed_positive_checkpoints] << element_selector
        result[:errors] << e.message
        break
      end
    end
    @@b.select_list(element_selector).select_value(value)
    return result
  end

  def finalize
    @@b.close
    @@headless.destroy if defined?(@@headless)
  end

  def is_element_present?(how, what)
    return @@b.element(how=>what).exists?
  end

  def browser_title_contains?(string)
    if @@b.title.match(string)
      return true
    else
      return false
    end
  end

  def dropdown_value(selector)
    if not element.match(/\:\w+\=\>[\'\"]\S+[\"\']/)
      raise "Please pass the element string in the form :selector=>\"value\""
    end
    result = {:result => true,
              :failed_positive_checkpoints => [],
              :errors => [], 
              :value => nil}
    begin
      result[:value] = @@b.select_list(selector).value
    rescue => e
      screenshot_save
      result[:result] = false
      result[:failed_positive_checkpoints] << selector
      result[:errors] << e.message
    end
  end

  def select_value(element, value)
    if not element.match(/\:\w+\=\>[\'\"]\S+[\"\']/)
      raise "Please pass the element string in the form :selector=>\"value\""
    end
    result = {:result => true, :errors => []}
    unless @@b.select_list(element).exists?
      result[:result] = false
      result[:errors] << "Unable to find element with #{element.keys[0].to_s} #{element.values[0]}" 
    else
      begin
        @@b.select_list(element).select_value(value)
      rescue => e
        screenshot_save
        result[:result] = false
        result[:errors] << e.message
      end
    end
    return result
  end

  def element_text(selector)
    if not element.match(/\:\w+\=\>[\'\"]\S+[\"\']/)
      raise "Please pass the element string in the form :selector=>\"value\""
    end
    result = {:result => true,
              :errors => [],
              :failed_positive_checkpoints => []}
    begin 
      result[:text] = @@b.element(selector).text
    rescue => e
      screenshot_save
      result[:result] = false
      result[:failed_positive_checkpoints] << selector
      result[:errors] << e.message
    end
    return result
  end

  def refresh_page
    @@b.refresh
  end

  def send_keys(element, text)
    if not element.match(/\:\w+\=\>[\'\"]\S+[\"\']/)
      raise "Please pass the element string in the form :selector=>\"value\""
    end
    result = {:result=>true,
              :failed_positive_checkpoints => [],
              :errors => []
    }
    begin
      @@b.text_field(element).clear
      @@b.text_field(element).send_keys text
    rescue => e
      result[:result] = false
      result[:failed_positive_checkpoints] << element
      result[:errors] << e.message
    end
  end

  def check_textfield_content(selector)
    result = {:result => true,
              :failed_positive_checkpoints => [],
              :errors => []
    }
    begin
      result[:text] = @@b.text_field(selector).value
    rescue => e
      screenshot_save
      result[:result] = false
      result[:failed_positive_checkpoints] << selector
      result[:errors] << e.message
    end
    return result
  end

  def page_html
    return @@b.html
  end

  def rules
    return @@rules
  end

  def action_rules(action)
    return @@rules[action.to_sym]
  end
end
