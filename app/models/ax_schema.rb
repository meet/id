# OpenID Attribute Exchange URIs.
module AXSchema
  
  USERNAME = 'http://axschema.org/namePerson/friendly'
  GROUPS = 'http://id.meet.mit.edu/schema/groups'
  GROUPS_CSV = 'http://id.meet.mit.edu/schema/groups-csv'
  
  MAP = {
    USERNAME => proc { |u| u.username },
    GROUPS => proc { |u| u.groups.map { |g| g.groupname } },
    GROUPS_CSV => proc { |u| u.groups.map { |g| g.groupname } .join(',') }
  }
  
end
