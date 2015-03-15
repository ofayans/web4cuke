Feature: example.feature
  # We expect that you have an account at https://www.openshift.com/
  # And that you have two environmental variables containing your 
  # Openshift login and password: $OPENSHIFT_LOGIN and $OPENSHIFT_PASSWORD
  Scenario: Login to Openshift web console
    Given I am logged in to OpenShift web console
    Then the url should contain "app/account"
    When I run my beautiful action with:
      |option                |value            |
      |field_one_on_page_one |some text          |
      |field_two_on_page_one | some other text|
      |field_one_on_page_two| lib/files/myfile      |
