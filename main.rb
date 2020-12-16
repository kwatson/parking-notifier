require 'rubygems'
require 'bundler/setup'

require 'erb'
require 'http'
require 'oj'
require 'postmark'

DB_FILE = File.expand_path('./db.json', File.dirname(__FILE__))

##
# Simple DB
db = Oj.load(File.read(DB_FILE))


%w(FROM_EMAIL DATES POSTMARK_API TO_EMAIL SUBJECT).each do |i|
  if ENV[i].nil?
    raise "Missing Environmental Variable #{i}"
  end
end

##
# ENV Vars
REQUESTED_DATES = ENV['DATES'].split(',') # 1/30/2021,2/15/2021
SKIP_PAID = ENV['SKIP_PAID'] # boolean

FROM_EMAIL = ENV['FROM_EMAIL']
TO_EMAIL = ENV['TO_EMAIL']
SUBJECT = ENV['SUBJECT']
POSTMARK_API = ENV['POSTMARK_API']

dates = []
REQUESTED_DATES.each do |i|
  d = i.split('/')
  dates << Date.new(d[2].to_i,d[0].to_i,d[1].to_i).to_s
end
##
# Setup Email
client = Postmark::ApiClient.new(POSTMARK_API)

parking_url = "https://api.parkwhiz.com/v4/venues/478498/events/\?fields\=%3Adefault%2Csite_url%2Cavailability%2Cvenue%3Atimezone\&q\=%20starting_after%3A2020-12-15T00%3A00%3A00-08%3A00\&sort\=start_time\&zoom\=pw%3Avenue"
data = HTTP.get(parking_url)

json_data = Oj.load(data.body)

@results = []

json_data.each do |i|
  qty = i.dig('availability', 'available').to_i
  if qty > 0
    the_date = Time.parse(i['start_time']).to_date
    next unless dates.include? the_date    
    if db.include?(the_date.to_s)
      puts "Already alerted on date #{the_date}, skipping..."
      next
    end
    item = {
      id: i['id'],
      date: the_date.to_s,
      total_available: qty,
      locations: []
    }

    detail_url = "https://api.parkwhiz.com/v4/quotes/?capabilities=capture_plate%3Aalways&fields=%3Adefault%2Cquote%3A%3Adefault%2Cquote%3Ashuttle_times%2Clocation%3A%3Adefault%2Clocation%3Atimezone%2Clocation%3Asite_url%2Clocation%3Arating_summary%2Clocation%3Adescription%2Clocation%3Adirections%2Clocation%3Adisplay_seller_logo%2Clocation%3Acountry&q=search_type%3Atransient%20venue_id%3A478498%20event_id%3A#{i['id']}&returns=offstreet&zoom=pw%3Alocation"

    detail_body = HTTP.get(detail_url)
    details = Oj.load(detail_body.body)
    
    details.each do |detail|
      next if detail['purchase_options'].empty?
      avail = detail['purchase_options'][0].dig('space_availability', 'spaces_remaining')
      status = detail['purchase_options'][0].dig('space_availability', 'status')
      avail = "-" if status == 'available' && avail.nil?
      price = detail['purchase_options'][0].dig('price', 'USD').to_f
      next if SKIP_PAID && price > 0.0
      item[:locations] << {
        name: detail.dig('_embedded', 'pw:location', 'name'),
        status: detail['purchase_options'][0].dig('space_availability', 'status'),
        limited_qty: avail.nil? ? 0 : avail,
        price: price
      } 
    end

    unless item[:locations].empty?
      @results << item
    end
    
  end
end

if @results.empty?
  puts "No results found"
else
  puts "Found #{@results.count}, sending alert to #{TO_EMAIL}"
  client.deliver(
    from: FROM_EMAIL,
    to: TO_EMAIL,
    subject: SUBJECT,
    html_body: ERB.new(File.read('email.html.erb')).result,
    track_opens: false
  )
  @results.each do |i|
    db << i[:date]
  end
  File.open(DB_FILE, 'w') do |file|
    file.puts db.to_json
  end
end