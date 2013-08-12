require 'rubygems'
require 'mechanize'
require 'neography'
require 'yaml'

@neo = Neography::Rest.new

#hack to create the indexes
new_node = Neography::Node.create("name" => "sun")
new_node.add_to_index("artist_index", "name", "sun")
new_node.add_to_index("band_index", "name", "sun")
new_node.add_to_index("label_index", "name", "sun")
new_node.add_to_index("album_index", "name", "sun")
#clean slate
@neo.execute_query "START r=rel(*) DELETE r;"
@neo.execute_query "START n=node(*) DELETE n;"

def findArtist(name)
  return Neography::Node.find("artist_index", "name", name)
end

def getArtist(name)
  n = Neography::Node.find("artist_index", "name", name)
  if n.nil?
    n = Neography::Node.create("name" => name)
    n.add_to_index("artist_index", "name", name)
  end
  return n
end

def getBand(name)
  n = Neography::Node.find("band_index", "name", name)
  if n.nil?
    n = Neography::Node.create("name" => name)
    n.add_to_index("band_index", "name", name)
    @neo.set_label(n.neo_id, "Band")
  end
  return n
end

def getLabel(name)
  n = Neography::Node.find("label_index", "name", name)
  if n.nil?
    n = Neography::Node.create("name" => name)
    n.add_to_index("label_index", "name", name)
    @neo.set_label(n.neo_id, "Label")
  end
  return n
end

def getAlbum(name)
  n = Neography::Node.find("album_index", "name", name)
  if n.nil?
    n = Neography::Node.create("name" => name)
    n.add_to_index("album_index", "name", name)
    @neo.set_label(n.neo_id, "Album")
  end
  return n
end

def put_artist_in_band(a, b)
  Neography::Relationship.create(:MEMBER_OF, a, b)
end
def put_band_on_album(b, a)
  Neography::Relationship.create(:MADE_ALBUM, b, a)
end
def put_label_on_album(l, a)
  Neography::Relationship.create(:RELEASED_ALBUM, l, a)
end

# data = YAML.load_file('data.yaml')

# if data["artists"].kind_of?(Array)
#   data["artists"].each do |artist|
#     a = getArtist artist["name"]
#   end
# end

# if data["bands"].kind_of?(Array)
#   data["bands"].each do |band|
#     b = getBand band["name"]
#     band["members"].each do |member|
#       a = getArtist member
#       put_artist_in_band a, b
#     end
#   end
# end

# if data["labels"].kind_of?(Array)
#   data["labels"].each do |label|
#     l = getLabel label["name"]
#   end
# end

# if data["albums"].kind_of?(Array)
#   data["albums"].each do |album|
#     a = getAlbum album["name"]
#     b = getBand album["band"]
#     l = getLabel album["label"]
#     put_band_on_album b, a
#     put_label_on_album l, a
#   end
# end


agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

def nextpage(n, url, agent)
  begin
    page = agent.get url
  rescue
    return
  end
  page.parser.xpath("//th[. = 'Associated acts']/following-sibling::td/a").each do |act|
    next_artist = act.xpath("text()").to_s.gsub(/[^0-9a-z ]/i, '')
    if findArtist(next_artist).nil?
      Neography::Relationship.create(:ASSOCIATED_ACT, n, getArtist(next_artist))
      nextpage(getArtist(next_artist), act.xpath("@href"), agent)
    end
  end
end

nextpage(Neography::Node.create("name" => "root"), "http://en.wikipedia.org/wiki/Misfits_(band)", agent)