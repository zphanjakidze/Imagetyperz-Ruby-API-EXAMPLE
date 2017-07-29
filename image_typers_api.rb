# Imagetypers API
require 'net/http'
require 'base64'

# endpoints
# -------------------------------------------------------------------------------------------
ROOT_DOMAIN = 'captchatypers.com'
CAPTCHA_ENDPOINT = '/Forms/UploadFileAndGetTextNEW.ashx'
RECAPTCHA_SUBMIT_ENDPOINT = '/captchaapi/UploadRecaptchaV1.ashx'
RECAPTCHA_RETRIEVE_ENDPOINT = '/captchaapi/GetRecaptchaText.ashx'
BALANCE_ENDPOINT = '/Forms/RequestBalance.ashx'
BAD_IMAGE_ENDPOINT = '/Forms/SetBadImage.ashx'

# user agent used in requests
# ---------------------------
USER_AGENT = 'pythonAPI1.0'

# captcha class
class Captcha
  def initialize(response)
    parse_response response   # parse response
  end
  def parse_response(response)
    s = response.split('|')
    if s.length < 2
      raise "cannot parse response from server: #{response}"
    end
    # at this point, we have the right length, save it to obj

    @_captcha_id = s[0]
    s.shift(1)
    @_text = s.join('|')
  end

  def captcha_id
    @_captcha_id
  end

  def text
    @_text
  end
end

# recaptcha class
class Recaptcha
  def initialize(captcha_id)
    @_captcha_id = captcha_id
  end

  def set_response(response)
    @_response = response
  end
  def response
    @_response
  end
  def captcha_id
    @_captcha_id
  end
end

# Imagetypers API class
class ImageTypersAPI
  def initialize(username, password, timeout)
    @_username = username
    @_password = password
    @_timeout = timeout.to_i
    @_ref_id = 0
    @_headers = {"User-Agent" => USER_AGENT}
  end

  # solve normal captcha
  def solve_captcha(image_path, case_sensitive)
    if not File.file?(image_path)   # check if image exists
      raise "image file does not exist: #{image_path}"
    end

    # read data from file and encode to b64
    data = IO.binread(image_path) # read file
    b64data = Base64.encode64(data)   # to b64

    data = {
        "file" => b64data,
        "action" => "UPLOADCAPTCHA",
        "username" => @_username,
        "password" => @_password,
        "chkCase" => case_sensitive ? '1' : '2',
        "refid" => @_ref_id
    }

    # make request
    http = Net::HTTP.new(ROOT_DOMAIN, 80)
    req = Net::HTTP::Post.new(CAPTCHA_ENDPOINT, @_headers)
    res = http.request(req, URI.encode_www_form(data))
    response_text = res.body    # get response body
    # replace uploading file ... happens when it's sent as b64
    response_text = response_text.sub! 'Uploading file...', ''

    # check if error
    if response_text.include?("ERROR:")
      response_err = response_text.split('ERROR:')[1].strip()   # get only the
      @_error = response_err
      raise @_error
    end

    c = Captcha.new response_text   # create new captcha instance
    @_captcha = c               # save it to this obj
    return c.text
  end

  # get accounts balance
  def account_balance
    data = {
        "action" => "REQUESTBALANCE",
        "username" => @_username,
        "password" => @_password,
        "submit" => "Submit"
    }

    # make request
    http = Net::HTTP.new(ROOT_DOMAIN, 80)
    req = Net::HTTP::Post.new(BALANCE_ENDPOINT, @_headers)
    res = http.request(req, URI.encode_www_form(data))
    response_text = res.body    # get response body

    # check if error
    if response_text.include?("ERROR:")
      response_err = response_text.split('ERROR:')[1].strip()   # get only the
      @_error = response_err
      raise @_error
    end

    return "$#{response_text}"    # all good, return
  end

  # submit recaptcha to server for completion
  def submit_recaptcha(page_url, sitekey)
    # params
    data = {
        "action" => "UPLOADCAPTCHA",
        "username" => @_username,
        "password" => @_password,
        "pageurl" => page_url,
        "googlekey" => sitekey,
        "refid" => @_ref_id
    }

    # if proxy was set, add it to request
    if @_proxy
      data['proxy'] = @_proxy['proxy']
      data['proxy_type'] = @_proxy['proxy_type']
    end

    # make request
    http = Net::HTTP.new(ROOT_DOMAIN, 80)
    req = Net::HTTP::Post.new(RECAPTCHA_SUBMIT_ENDPOINT, @_headers)
    res = http.request(req, URI.encode_www_form(data))
    response_text = res.body    # get response body

    # check if error
    if response_text.include?("ERROR:")
      response_err = response_text.split('ERROR:')[1].strip()   # get only the
      @_error = response_err
      raise @_error
    end

    @_recaptcha = Recaptcha.new response_text   # init recaptcha obj
    return @_recaptcha.captcha_id     # return id
  end

  # retrieve recaptcha response using id
  def retrieve_recaptcha(captcha_id)
    # params
    data = {
        "action" => "GETTEXT",
        "username" => @_username,
        "password" => @_password,
        "captchaid" => captcha_id,
        "refid" => @_ref_id
    }

    # make request
    http = Net::HTTP.new(ROOT_DOMAIN, 80)
    req = Net::HTTP::Post.new(RECAPTCHA_RETRIEVE_ENDPOINT, @_headers)
    res = http.request(req, URI.encode_www_form(data))
    response_text = res.body    # get response body

    # check if error
    if response_text.include?("ERROR:")
      response_err = response_text.split('ERROR:')[1].strip()   # get only the
      @_error = response_err
      raise @_error
    end

    @_recaptcha.set_response response_text    # set response to recaptcha obj
    return @_recaptcha.response   # return response
  end

  # tells if recaptcha is still in progress
  def in_progress(captcha_id)
    begin
      retrieve_recaptcha captcha_id     # try to retrieve it
      return false      # no error, it's done
    rescue => details
      if details.message.include? 'NOT_DECODED'
        return true
      end

      raise   # re-raise if different error
    end
  end

  # set captcha bad
  def set_captcha_bad(captcha_id)
    data = {
        "action" => "SETBADIMAGE",
        "username" => @_username,
        "password" => @_password,
        "imageid" => captcha_id.to_s,
        "submit" => "Submissssst"
    }

    # make request
    http = Net::HTTP.new(ROOT_DOMAIN, 80)
    req = Net::HTTP::Post.new(BAD_IMAGE_ENDPOINT, @_headers)
    res = http.request(req, URI.encode_www_form(data))
    response_text = res.body    # get response body

    # check if error
    if response_text.include?("ERROR:")
      response_err = response_text.split('ERROR:')[1].strip()   # get only the
      @_error = response_err
      raise @_error
    end

    return response_text    # all good, return
  end

  # set recaptcha proxy
  def set_recaptcha_proxy(proxy, proxy_type)
    @_proxy = {
        "proxy" => proxy,
        "proxy_type" => proxy_type
    }
  end

  # set ref id
  def set_ref_id(ref_id)
    @_ref_id = ref_id.to_s
  end

  # captcha text
  def captcha_text
    if @_captcha
      return @_captcha.text
    else
      return ''
    end
  end

  # captcha id
  def captcha_id
    if @_captcha
      return @_captcha.captcha_id
    else
      return ''
    end
  end

  # recaptcha id
  def recaptcha_id
    if @_recaptcha
      return @_recaptcha.captcha_id
    else
      return ''
    end
  end

  # recaptcha response
  def recaptcha_response
    if @_recaptcha
      return @_recaptcha.response
    else
      return ''
    end
  end

  # error
  def error
    @_error
  end
end

