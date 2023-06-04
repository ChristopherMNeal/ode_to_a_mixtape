require 'csv'
require 'date'

# I should change this to generate all weeks in a year so I don't have to do it every week!
# Maybe just add a feature `if ARGV[1] == 'all'`...

# Check for the correct number of arguments
unless ARGV.size == 3 || ARGV[1] == 'all'
  puts 'Usage: ruby playlist_week.rb <path_to_csv> <month_number> <week_number>'
  exit
end

csv_path = ARGV[0]
month_number = ARGV[1].to_i
week_number = ARGV[2].to_i

# Read the input CSV
input_csv = CSV.read(csv_path, headers: true)

# Function to get the week number of a date in its month
def week_of_month(date)
  first_day_of_month = Date.new(date.year, date.month, 1)
  ((date - first_day_of_month) / 7).to_i + 1
end

# Filter songs based on month and week
selected_songs = input_csv.select do |row|
  # Parse the date and extract the month and week
  date = DateTime.strptime(row['Date'], '%I:%M%p, %m-%d-%Y')

  # Handle 5-week months by merging the 5th week into the 4th week
  week = week_of_month(date)
  week = 4 if week == 5

  date.month == month_number && week == week_number
end

# Write the filtered songs to a new CSV
original_playlist_name = csv_path.split('/').last.gsub('.csv', '').gsub(' ', '_')
output_filename = "#{original_playlist_name}_from_month_#{month_number}_week_#{week_number}.csv"
CSV.open(output_filename, 'wb') do |csv|
  csv << input_csv.headers
  selected_songs.each do |song|
    csv << song
  end
end

# puts "Filtered songs written to #{output_filename}"
# puts 'Would you like to open https://www.tunemymusic.com/ ?'
# $stdout.flush
#
# response = gets.chomp.downcase
system('open https://www.tunemymusic.com/') # if %w[y yes].include?(response)
