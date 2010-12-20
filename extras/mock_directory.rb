class Directory
  
  User = Struct.new(:uid)
  Group = Struct.new(:cn)
  App = Struct.new(:labeledURI)
  
  @@mocks = Hash.new({})
  
  def self.mock(method, arg, value)
    @@mocks[method] = @@mocks[method].merge({ arg => value })
  end
  
  def self.empty
    @@mocks.clear
  end
  
  def self.mock_user(username, groups)
    mock(:find_user_by_uid, username, User.new([ username ]))
    mock(:find_groups_by_member_uid, username, groups.map { |group| Group.new([ group ]) })
  end
  
  def self.mock_app(url)
    mock(:find_app_by_url, url, App.new([ url ]))
  end
  
  def method_missing(method, arg)
    value = @@mocks[method][arg]
    return nil unless value
    
    if block_given?
      if value.is_a? Array
        value.each { |entry| yield entry }
      else
        yield value
      end
    end
    return value
  end
  
end
