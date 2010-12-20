# Authorized application to which identities will be shared.
class App
  
  def self.find(url)
    Directory.new.find_app_by_url(url) do |entry|
      return new(entry)
    end
    return false
  end
  
  attr_reader :url
  
  def initialize(entry)
    @url = entry.labeledURI.first
  end
  
end