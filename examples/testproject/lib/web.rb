require "web4cucumber"

class Web < Web4Cucumber
  def initialize(options)
    super(options)
    @@logged_in = false
  end

  def login(options)
    unless options.keys == [:login, :password]
      raise "Please povide both :login and :password options"
    end
    result = run_action(:login, options)
    if result[:result] == true
      @@logged_in = true
    end
    return result
  end
end
