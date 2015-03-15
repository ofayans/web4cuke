Given /^I am logged in to OpenShift web console$/ do
  options = {}
  options[:login] = ENV["OPENSHIFT_USER"]
  options[:password] = ENV["OPENSHIFT_PASSWORD"]
  @result = @web.login(options)
  expect(@result[:result]).to be_true, "Failed to log in"
end

Then /^the url should contain "(.*?)"$/ do |urlpart|
  url = @web.get_url
  expect(url.include?(urlpart)).to be_true, "Failed to find #{urlpart} in page url"
  
end

When /^I run my beautiful action with:$/ do |table|
  options = {}
  table.rows.each do |row|
    options[row[0].to_sym] = row[1]
  end
  @result = @web.run_action(:our_test_action, options)
end


