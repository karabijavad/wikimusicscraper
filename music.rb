require 'rubygems'
require 'mechanize'
require 'neography'
require 'yaml'
require 'uri'
require 'htmlentities'

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

def findBand(name)
  return Neography::Node.find("band_index", "name", name)
end

def findLabel(name)
  return Neography::Node.find("label_index", "name", name)
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

agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

def nextpage(n, url, agent, indentation)
  indentation = indentation + "-"
  begin
    page = agent.get url
  rescue Exception => e
    puts e
    return
  end

  page.parser.xpath("//th[. = 'Labels']/following-sibling::td/a").each do |el|
    label = el.xpath("text()")
    Neography::Relationship.create(:LABEL, n, getLabel(HTMLEntities.new.decode label))
  end

  page.parser.xpath("//th[. = 'Associated acts']/following-sibling::td/a").each do |act|
    if !act.xpath("@href").to_s.include? "/wiki/"
      return
    end
    next_act = act.xpath("text()").to_s.gsub(/[^0-9a-z ]/i, '')
    if findBand(HTMLEntities.new.decode next_act).nil?
      Neography::Relationship.create(:ASSOCIATED_ACT, n, getBand(HTMLEntities.new.decode next_act))
      puts "#{indentation}Creating act #{next_act}"
      nextpage(getBand(HTMLEntities.new.decode next_act), act.xpath("@href"), agent, indentation)
    else
      puts "#{indentation}Already have associated act: #{next_act}"
      Neography::Relationship.create(:ASSOCIATED_ACT, n, getBand(HTMLEntities.new.decode next_act))
    end
  end

  page.parser.xpath("//th[. = 'Members']/following-sibling::td/a").each do |act|
    if !act.xpath("@href").to_s.include? "/wiki/"
      return
    end
    next_act = act.xpath("text()").to_s.gsub(/[^0-9a-z ]/i, '')
    if findArtist(HTMLEntities.new.decode next_act).nil?
      Neography::Relationship.create(:MEMBER, n, getArtist(HTMLEntities.new.decode next_act))
      puts "Creating artist #{next_act}"
      nextpage(getArtist(HTMLEntities.new.decode next_act), act.xpath("@href"), agent, indentation)
    else
      puts "#{indentation}Already have artist: #{next_act}"
      Neography::Relationship.create(:MEMBER, n, getArtist(HTMLEntities.new.decode next_act))
    end
  end
end

nextpage(getBand(HTMLEntities.new.decode "Modest Mouse"), "http://en.wikipedia.org/wiki/Modest_mouse", agent, "-")
