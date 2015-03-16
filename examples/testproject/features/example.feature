Feature: example.feature
  # We expect that you have an account at https://www.openshift.com/
  # And that you have two environmental variables containing your 
  # Openshift login and password: $OPENSHIFT_LOGIN and $OPENSHIFT_PASSWORD
  Scenario: Login to Openshift web console
    Given I am logged in to OpenShift web console
    Then the url should contain "app/account"
