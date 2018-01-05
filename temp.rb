#!/usr/bin/ruby
require 'arduino_firmata'
require 'rest_client'
require 'json'

#Token from oauth scripts goes here
token = 'SECRETTOKEN'

@bear_h = { Authorization: "Bearer #{token}" }
@last_temp = -99

def getTemp(pin, arduino)
  value = arduino.analog_read 0
  v = value * 0.004882814
  c = (v - 0.5) * 100
  return c * (9.0/5.0) + 32.0
end

def minuteAvg(arduino)
  temps = []
  60.times do
    temp = getTemp(0, arduino)
    temps.push(temp)
    sleep(1)
  end
  average = temps.inject{ |sum, el| sum + el}.to_f / temps.size
  return average 
end

def fiveMinuteAvg(arduino)
  temps = []
  5.times do
    temp = minuteAvg(arduino)
    temps.push(temp)
    puts "1 Minute Average: #{temp}"
  end
  average = temps.inject{ |sum, el| sum + el}.to_f / temps.size
  return average
end

def getEndpointURI(headers)
  endpoints = JSON.parse(RestClient::Request.execute(method: :get, 
                      url: 'https://graph.api.smartthings.com/api/smartapps/endpoints', 
                      timeout: 10,
                      headers: headers))
  return endpoints[0]['uri']
end

def updateTemp(uri, headers, temp)
  temp_url = uri + "/update/#{temp}/F"
  return RestClient::Request.execute(method: :put,
                       url: temp_url,
                       timeout: 20,
                       headers: headers)
end

loop do
  begin
    puts "Opening Serial Interface....."
    arduino = ArduinoFirmata.connect '/dev/ttySAC0', :nonblock_io => true
    endpoint = getEndpointURI(@bear_h)

    3.times do |n|
      average = fiveMinuteAvg(arduino)
      averagei = average.to_i
      puts "5 Minute Average: #{average}"
      if (@last_temp != averagei) || n == 0
        puts "Updating SmartThings API - Last: #{@last_temp} Current: #{average}"
        updateTemp(endpoint, @bear_h, averagei)
        @last_temp = averagei
      else
        puts "Skipping Update - Last: #{@last_temp} Current: #{average}"
      end
    end
  rescue
    puts "Error Fetching Temperature or posting updates to SmartThings API."
  ensure
    arduino.close
  end
end
