# User.
class User
  
  def self.find(username)
    directory = Directory.new
    directory.find_user_by_uid(username) do |entry|
      return new(directory, entry)
    end
    return false
  end
  
  attr_reader :username, :groups
  
  def initialize(directory, entry)
    @username = entry.uid.first
    @groups = directory.find_groups_by_member_uid(username).map do |entry|
      entry.cn.first
    end
  end
  
end
