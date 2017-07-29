# Imagetypers API test
load 'image_typers_api.rb'

def test_api
  username = "user name here"
  password = "password here"

  i = ImageTypersAPI.new(username, password,123)

  # check account balance
  # ---------------------------------------------------
  balance = i.account_balance          # get balance
  puts "Account balance: #{balance}"   # print balance

  # solve normal captcha
  # ---------------------------------------------------
  puts "Waiting for captcha to be solved ..."
  # ---------------------------------------------------
  captcha_text = i.solve_captcha('captcha.jpg', false)    # solve regular captcha
  puts "Captcha text: #{captcha_text}"    # print text gathered

  # recaptcha
  # ---------------------------------------------------
  # submit to server and get the id
  recaptcha_id = i.submit_recaptcha 'page url here','key code here'
  puts "Waiting for recaptcha to be solved ..."
  while i.in_progress recaptcha_id  # while it's still in progress
    sleep 10    # sleep for 10 seconds
  end

  # get the response and print it
  recaptcha_response = i.retrieve_recaptcha recaptcha_id    # retrieve response
  puts "Recaptcha response: #{recaptcha_response}"

  # Other examples
  # ---------------------------------------------------
  #puts i.captcha_id
  #puts i.captcha_text
  #puts i.recaptcha_id
  #puts i.recaptcha_response
  #i.set_ref_id 2    # set reference id
  #i.set_recaptcha_proxy'123.45.67.78:8080','HTTP'
  #print i.set_captcha_bad'123'    # set captcha bad

end

def main
  begin
    test_api()
  rescue => details
    puts "[!] Error occured: #{details}"
  end
end

main
