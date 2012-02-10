# OpenID Attribute Exchange URIs.
module AXSchema
  
  USERNAME = 'http://axschema.org/namePerson/friendly'
  FIRST_NAME = 'http://axschema.org/namePerson/first'
  LAST_NAME = 'http://axschema.org/namePerson/last'
  FULL_NAME = 'http://id.meet.mit.edu/schema/name-full'
  GROUPS = 'http://id.meet.mit.edu/schema/groups'
  GROUPS_CSV = 'http://id.meet.mit.edu/schema/groups-csv'
  
  MAP = {
    USERNAME => proc { |u| u.username },
    FIRST_NAME => proc { |u| u.first_name },
    LAST_NAME => proc { |u| u.last_name },
    FULL_NAME => proc { |u| u.name },
    GROUPS => proc { |u| u.groups.map { |g| g.groupname } },
    GROUPS_CSV => proc { |u| u.groups.map { |g| g.groupname } .join(',') }
  }
  
end
