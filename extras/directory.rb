module Directory
  
  @@connection_params = { :base => 'dc=meet,dc=mit,dc=edu' }
  
  def self.connect_with(connection_params)
    @@connection_params.merge!(connection_params)
  end
  
  def self.new(connection_params = {})
    return Net::LDAP.new(@@connection_params.merge(connection_params)).extend Search
  end
  
  module Search
    def find_user_by_uid(uid, &block)
      search(:base => "ou=users,#{base}", :filter => Net::LDAP::Filter.eq('uid', "#{uid}"), &block)
    end
    
    def find_groups_by_member_uid(uid, &block)
      search(:base => "ou=groups,#{base}", :filter => Net::LDAP::Filter.eq('memberUid', "#{uid}"), &block)
    end
    
    def find_app_by_url(url, &block)
      search(:base => "ou=apps,#{base}", :filter => Net::LDAP::Filter.eq('labeledURI', "#{url}"), &block)
    end
  end
  
end
