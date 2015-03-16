Given /^I am logged in to OpenShift web console$/ do
  options = {}
  options[:login] = ENV["OPENSHIFT_LOGIN"]
  options[:password] = ENV["OPENSHIFT_PASSWORD"]
  @result = @web.login(options)
  expect(@result[:result]).to be_true, "Failed to log in"
end

Then /^the url should contain "(.*?)"$/ do |urlpart|
  url = @web.get_url
  expect(url.include?(urlpart)).to be_true, "Failed to find #{urlpart} in page url"
  
end
