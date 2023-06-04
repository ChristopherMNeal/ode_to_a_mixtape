#!/usr/bin/ruby

require 'open-uri'
require 'nokogiri'
require 'csv'
require 'date'
require 'fileutils'

def get_input_from_args_or_prompt(args, index, prompt, lower_case = false)
  puts "\n\n#{prompt}"
  puts args[index] if args[index]
  value = args[index] || gets.chomp.strip
  lower_case ? value.downcase : value
end

show_name_for_url = get_input_from_args_or_prompt(
  ARGV, 0, "Please enter the show's identifier from the URL..."
)

show_title = get_input_from_args_or_prompt(
  ARGV, 1, "Next, please enter the full name of the show..."
)

start_date_input = get_input_from_args_or_prompt(
  ARGV, 2, "Specify the date of the latest show or the number of shows ago to start..."
)

end_date_input = get_input_from_args_or_prompt(
  ARGV, 3, "Finally, specify the date of the earliest show or show number you'd like to go back to..."
)

download_shows = get_input_from_args_or_prompt(
  ARGV, 4, "Would you like to download the mp3 shows? Enter 'yes' or 'no'...", true
) == 'yes'

specific_show_title = get_input_from_args_or_prompt(
  ARGV, 5, "Specify the title of the show to download..."
).downcase if ARGV[5]

def format_filename(show_title)
  "#{show_title.gsub(' ', '_')}"
end

global_vars = {
  csv: nil,
  show_title: show_title,
  earliest_date: nil,
  latest_date: nil
}

def download_file(download_url, target_folder, filename)
  File.open("#{target_folder}/#{filename}", 'wb') do |fo|
    fo.write open(download_url).read
  end
end

def parse_user_date_input(start_date_input, end_date_input)
  if start_date_input.nil?
    user_input_start_date = Date.today
  elsif (shows = Integer(start_date_input) rescue nil)
    min_shows = shows
  else
    user_input_start_date = Date.strptime(start_date_input, '%m-%d-%Y')
  end

  if end_date_input.nil?
    user_input_end_date = nil
  elsif (shows = Integer(end_date_input) rescue nil)
    max_shows = shows
  else
    user_input_end_date = Date.strptime(end_date_input, '%m-%d-%Y')
  end

  [user_input_start_date, user_input_end_date, min_shows, max_shows]
end

def fetch_show_page(show_page_url)
  begin
    Nokogiri::HTML(open(show_page_url))
  rescue OpenURI::HTTPError => error
    puts "Error opening page #{show_page_url}: #{error}"
    nil
  end
end

def process_broadcast_date(broadcast, start_date, end_date, show_count, min_shows, global_vars)
  date = DateTime.strptime(broadcast.css('div.date').text, '%I:%M%p, %m-%d-%Y')
  if end_date && date < end_date
    return [nil, true]
  elsif min_shows && show_count <= min_shows
    return [nil, true]
  else
    if date
      global_vars[:earliest_date] = date if global_vars[:earliest_date].nil? || date < global_vars[:earliest_date]
      global_vars[:latest_date] = date if global_vars[:latest_date].nil? || date > global_vars[:latest_date]
    end
    return [date, false]
  end
end

def process_broadcast_tracks(broadcast_page, date, title, link, global_vars)
  tracks = broadcast_page.css('div.creek-playlist li.creek-track')
  show_lines = []

  tracks.each do |track|
    track_title = track.css('span.creek-track-title').text.strip
    track_artist = track.css('span.creek-track-artist').text.strip
    track_album = track.css('span.creek-track-album').text.strip
    show_lines << [date.strftime('%I:%M%p, %m-%d-%Y'), title, link, track_title, track_artist, track_album]
  end

  show_lines.each do |line|
    global_vars[:csv] << line
  end

  return global_vars
end

def process_broadcast_title(broadcast, base_url, show_title)
  link = base_url + broadcast.css('div.title a').attribute('href').value
  title = "#{show_title} - #{broadcast.css('div.title a').text}"
  [link, title]
end

def fetch_broadcast_page(link)
  begin
    Nokogiri::HTML(open(link))
  rescue OpenURI::HTTPError => error
    puts "Error opening page #{link}: #{error}"
    nil
  end
end

def prepare_download_folder(show_title, date)
  download_folder = "#{show_title.gsub(' ', '_')}_#{date.strftime('%m-%d-%Y')}"
  FileUtils.mkdir_p(download_folder) unless File.exist?(download_folder)
  download_folder
end

def process_broadcast_mp3_links(broadcast_page, download_folder)
  broadcast_page.css('a.player').each do |mp3_link|
    mp3_url = mp3_link['href']
    mp3_filename = mp3_link.text.strip
    download_file(mp3_url, download_folder, mp3_filename)
  end
end

def check_max_shows(show_count, max_shows)
  max_shows && show_count >= max_shows
end

def next_page_available?(show_page)
  !show_page.css('div.pagination-container div.pagination-inner span.next a').empty?
end

def split_csv(file_path, show_title)
  csv = CSV.read(file_path, headers: true)
  grouped = csv.group_by { |row| row['Title'] }

  buffer = []
  counter = 1
  grouped.each_with_index do |(show, rows), index|
    if (buffer.size + rows.size) > 500
      write_to_csv(buffer, counter, show_title)
      buffer = rows
      counter += 1
    else
      buffer += rows
    end
  end
  write_to_csv(buffer, counter, show_title) unless buffer.empty?
end

def write_to_csv(rows, counter, show_title)
  first_date = parse_date(rows.first['Date'])
  last_date = parse_date(rows.last['Date'])
  filename = "#{show_title.gsub(' ', '_')}_#{last_date}_to_#{first_date}.csv"

  CSV.open(filename, 'w') do |csv_object|
    csv_object << rows.first.headers
    rows.each do |row|
      csv_object << row
    end
  end
end

def parse_date(date_string)
  if date_string
    if date_string.include?(",")
      time, date = date_string.split(",")
      Date.strptime(date.strip, "%m-%d-%Y").strftime("%Y-%m-%d")
    else
      Date.strptime(date_string.strip, "%m-%d-%Y").strftime("%Y-%m-%d")
    end
  else
    "0000-00-00"
  end
end

start_date, end_date, min_shows, max_shows = parse_user_date_input(start_date_input, end_date_input)

global_vars[:base_filename] = format_filename(global_vars[:show_title])
global_vars[:csv] = CSV.open("#{global_vars[:base_filename]}.csv", "wb")
global_vars[:csv] << ["Date", "Title", "Link", "Track", "Artist", "Album"]

page_number = 1
reached_target_date = false
show_count = 0

loop do
  base_url = "https://xray.fm"
  show_page_url = "#{base_url}/programs/#{show_name_for_url}/page:#{page_number}?url=shows%2F#{show_name_for_url}"

  show_page = fetch_show_page(show_page_url)
  break unless show_page

  puts "Loaded page #{page_number}"

  broadcasts = show_page.css('div.broadcasts-container div.broadcast')
  broadcasts.each do |broadcast|
    show_count += 1
  
    date, skip_show = process_broadcast_date(broadcast, start_date, end_date, show_count, min_shows, global_vars)

    if skip_show
      puts "Skipping show #{show_count}"
      next
    end
  
    link, title = process_broadcast_title(broadcast, base_url, show_title)
    
    # Skip the show if the title does not match the specified title
    show_prefix = "#{show_title.downcase} - "
    title_without_prefix = title.downcase.gsub(show_prefix, '')
    if specific_show_title && title_without_prefix != specific_show_title
      puts "Skipping show: #{title}"
      next
    end
      
    puts "Processing: #{date.strftime('%I:%M%p, %m-%d-%Y')} - #{title}"  

    broadcast_page = fetch_broadcast_page(link)
    next unless broadcast_page

    if download_shows
      download_folder = prepare_download_folder(show_title, date)
      process_broadcast_mp3_links(broadcast_page, download_folder)
    end

    global_vars = process_broadcast_tracks(broadcast_page, date, title, link, global_vars)

    reached_target_date = check_max_shows(show_count, max_shows)
    break if reached_target_date
  end

  break if reached_target_date || !next_page_available?(show_page)

  page_number += 1
end

global_vars[:csv].close

puts "Splitting the CSV..."
split_csv("#{global_vars[:base_filename]}.csv", global_vars[:show_title])

puts "Done!"
