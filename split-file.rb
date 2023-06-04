require 'csv'
require 'date'

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

file_path = ARGV[0] || begin
  puts "Please enter the path to the CSV file:"
  gets.chomp
end

show_title = ARGV[1] || begin
  puts "Please enter the show title:"
  gets.chomp
end

split_csv(file_path, show_title)
