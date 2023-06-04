require 'csv'

puts 'Starting the script...'

show_title = 'PNKHSE'
filename = 'mutant-pop.csv'

if File.exists?(filename)
  puts "Reading file: #{filename}..."
else
  puts "File: #{filename} does not exist!"
  exit
end

table = CSV.parse(File.read(filename), headers: true)

puts 'File read successfully!'

table.each do |row|
  if row['Title'][0..6] == 'PNKHSE:'
    puts "good"
    next
  elsif row['Title'][0..6] == 'PNKHSE '
    puts "Adding Colon to #{row['Title']}"
    row['Title'] = "PNKHSE: #{row['Title'][7..-1]}"
    puts "New title: #{row['Title']}"
  elsif row['Title']
    puts "adding title to: #{row['Title']}"
    row['Title'] = "#{show_title}: #{row['Title']}"
    puts "New title: #{row['Title']}"
  else
    puts "Title is nil for row: #{row.inspect}"
  end
end

new_filename = 'updated_' + filename
File.write(new_filename, table.to_csv)

puts 'File written successfully!'
