require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'


def clean_zipcode(zipcode)
  zipcode = zipcode.to_s.rjust(5, '0')[0..4]
end

def validate_phone_number(phone_number)
  phone_number = phone_number.gsub /[^0-9]/, ''

  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number = phone_number[1..-1]
  else
    phone_number = nil
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
                              address: zipcode,
                              levels: 'country',
                              roles: ['legislatorUpperBody', 'legislatorLowerBody']).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter, output_folder)
  output_file_path = "./#{output_folder}/thanks_#{id}.html"
  File.open(output_file_path, 'w') { |file| file.puts form_letter }
end

def best_times_to_target(registration_hours)
  peak_registrations = registration_hours.values.max

  registration_hours.select do |hour, registrations|
    registrations == peak_registrations
  end.keys.join(', ')
end

def best_days_to_target(registration_days)
  peak_registrations = registration_days.values.max

  day_numbers = registration_days.select do |day, registrations|
    registrations == peak_registrations
  end.keys

  day_numbers.map do |number|
    Date::DAYNAMES[number]
  end.join(', ')
end

puts "EventManager Initialized!"

file = './event_attendees.csv'
contents = CSV.open file, headers: true, header_converters: :symbol

template_letter = File.open('./form_letter.erb', 'r') { |file| file.read }
erb_template = ERB.new template_letter

output_folder = 'form_letters'
Dir.mkdir output_folder unless Dir.exists? output_folder

registration_hours = Hash.new(0)
registration_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = validate_phone_number row[:homephone]

  registration_date = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')
  registration_hours[registration_date.hour] += 1
  registration_days[registration_date.wday] += 1

  zipcode = clean_zipcode row[:zipcode]
  legislators = legislators_by_zipcode zipcode

  form_letter = erb_template.result binding

  save_thank_you_letter id, form_letter, output_folder
end
puts "Form letters created in the \"#{output_folder}\" directory"
puts "Best times to target ads are at: #{best_times_to_target registration_hours}"
puts "People signed up the most on: #{best_days_to_target registration_days}"
