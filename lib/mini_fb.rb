require 'digest/md5'
require 'erb'
require 'json' unless defined? JSON

module MiniFB

    # Global constants
    FB_URL = "http://api.facebook.com/restserver.php"
    FB_API_VERSION = "1.0"

    @@logging = false

    def self.enable_logging
        @@logging = true
    end

    def self.disable_logging
        @@logging = false
    end

    class FaceBookError < StandardError
        attr_accessor :code
        # Error that happens during a facebook call.
        def initialize( error_code, error_msg )
            @code = error_code
            super("Facebook error #{error_code}: #{error_msg}" )
        end
    end

    class Session
        attr_accessor :api_key, :secret_key, :session_key, :uid


        def initialize(api_key, secret_key, session_key, uid)
            @api_key = api_key
            @secret_key = FaceBookSecret.new secret_key
            @session_key = session_key
            @uid = uid
        end

        # returns current user
        def user
            return @user unless @user.nil?
            @user = User.new(MiniFB.call(@api_key, @secret_key, "Users.getInfo", "session_key"=>@session_key, "uids"=>@uid, "fields"=>User.all_fields)[0], self)
            @user
        end

        def photos
            Photos.new(self)
        end


        def call(method, params={})
            return MiniFB.call(api_key, secret_key, method, params.update("session_key"=>session_key))
        end


    end
    class User
        FIELDS = [:uid, :status, :political, :pic_small, :name, :quotes, :is_app_user, :tv, :profile_update_time, :meeting_sex, :hs_info, :timezone, :relationship_status, :hometown_location, :about_me, :wall_count, :significant_other_id, :pic_big, :music, :work_history, :sex, :religion, :notes_count, :activities, :pic_square, :movies, :has_added_app, :education_history, :birthday, :birthday_date, :first_name, :meeting_for, :last_name, :interests, :current_location, :pic, :books, :affiliations, :locale, :profile_url, :proxied_email, :email, :email_hashes, :allowed_restrictions, :pic_with_logo, :pic_big_with_logo, :pic_small_with_logo, :pic_square_with_logo]
        STANDARD_FIELDS = [:uid, :first_name, :last_name, :name, :timezone, :birthday, :sex, :affiliations, :locale, :profile_url, :proxied_email, :email]

        def self.all_fields
            FIELDS.join(",")
        end

        def self.standard_fields
            STANDARD_FIELDS.join(",")
        end

        def initialize(fb_hash, session)
            @fb_hash = fb_hash
            @session = session
        end

        def [](key)
            @fb_hash[key]
        end

        def uid
            return self["uid"]
        end

        def profile_photos
            @session.photos.get("uid"=>uid, "aid"=>profile_pic_album_id)
        end

        def profile_pic_album_id
            merge_aid(-3, uid)
        end

        def merge_aid(aid, uid)
            uid = uid.to_i
            ret = (uid << 32) + (aid & 0xFFFFFFFF)
#            puts 'merge_aid=' + ret.inspect
            return ret
        end
    end

    class Photos

        def initialize(session)
            @session = session
        end

        def get(params)
            pids = params["pids"]
            if !pids.nil? && pids.is_a?(Array)
                pids = pids.join(",")
                params["pids"] = pids
            end
            @session.call("photos.get", params)
        end
    end

    BAD_JSON_METHODS = ["users.getloggedinuser", "auth.promotesession", "users.hasapppermission", "Auth.revokeExtendedPermission", "pages.isAdmin"].collect { |x| x.downcase }

    # Call facebook server with a method request. Most keyword arguments
    # are passed directly to the server with a few exceptions.
    # The 'sig' value will always be computed automatically.
    # The 'v' version will be supplied automatically if needed.
    # The 'call_id' defaults to True, which will generate a valid
    # number. Otherwise it should be a valid number or False to disable.

    # The default return is a parsed json object.
    # Unless the 'format' and/or 'callback' arguments are given,
    # in which case the raw text of the reply is returned. The string
    # will always be returned, even during errors.

    # If an error occurs, a FacebookError exception will be raised
    # with the proper code and message.

    # The secret argument should be an instance of FacebookSecret
    # to hide value from simple introspection.
    def MiniFB.call( api_key, secret, method, kwargs )

        puts 'kwargs=' + kwargs.inspect if @@logging

        if secret.is_a? String
            secret = FaceBookSecret.new(secret)
        end

        # Prepare arguments for call
        call_id = kwargs.fetch("call_id", true)
        if call_id == true
            kwargs["call_id"] = Time.now.tv_sec.to_s
        else
            kwargs.delete("call_id")
        end

        custom_format = kwargs.include?("format") || kwargs.include?("callback")
        kwargs["format"] ||= "JSON"
        kwargs["v"] ||= FB_API_VERSION
        kwargs["api_key"]||= api_key
        kwargs["method"] ||= method

        file_name = kwargs.delete("filename")

        # Hash with secret
        arg_string = String.new
        # todo: convert symbols to strings, symbols break the next line
        kwargs.sort.each { |kv| arg_string << kv[0] << "=" << kv[1].to_s }
        kwargs["sig"] = Digest::MD5.hexdigest( arg_string + secret.value.call )

        fb_method = kwargs["method"].downcase
        if fb_method == "photos.upload"
            # Then we need a multipart post
            response = MiniFB.post_upload(file_name, kwargs)
        else

            begin
                response = Net::HTTP.post_form( URI.parse(FB_URL), kwargs )
            rescue SocketError => err
                # why are we catching this and throwing as different error?  hmmm..
#                raise IOError.new( "Cannot connect to the facebook server: " + err )
                raise err
            end
        end


        # Handle response
        return response.body if custom_format


        body = response.body

        puts 'response=' + body.inspect if @@logging
        begin
            data = JSON.parse( body )
            if data.include?( "error_msg" )
                raise FaceBookError.new( data["error_code"] || 1, data["error_msg"] )
            end

        rescue JSON::ParserError => ex
            if BAD_JSON_METHODS.include?(fb_method) # Little hack because this response isn't valid JSON
                if body == "0" || body == "false"
                    return false
                end
                return body
            else
                raise ex
            end
        end
        return data
    end

     def MiniFB.post_upload(filename, kwargs)
      content = File.open(filename, 'rb') { |f| f.read }
      boundary = Digest::MD5.hexdigest(content)
      header = {'Content-type' => "multipart/form-data, boundary=#{boundary}"}

      # Build query
      query = ''
      kwargs.each { |a, v|
        query <<
          "--#{boundary}\r\n" <<
          "Content-Disposition: form-data; name=\"#{a}\"\r\n\r\n" <<
          "#{v}\r\n"
      }
      query <<
        "--#{boundary}\r\n" <<
        "Content-Disposition: form-data; filename=\"#{File.basename(filename)}\"\r\n" <<
        "Content-Transfer-Encoding: binary\r\n" <<
        "Content-Type: image/jpeg\r\n\r\n" <<
        content <<
        "\r\n" <<
        "--#{boundary}--"

      # Call Facebook with POST multipart/form-data request
      uri = URI.parse(FB_URL)
      Net::HTTP.start(uri.host) {|http| http.post uri.path, query, header}
    end

    # Returns true is signature is valid, false otherwise.
    def MiniFB.verify_signature( secret, arguments )
        signature = arguments.delete( "fb_sig" )
        return false if signature.nil?

        unsigned = Hash.new
        signed = Hash.new

        arguments.each do |k, v|
            if k =~ /^fb_sig_(.*)/ then
                signed[$1] = v
            else
                unsigned[k] = v
            end
        end

        arg_string = String.new
        signed.sort.each { |kv| arg_string << kv[0] << "=" << kv[1] }
        if Digest::MD5.hexdigest( arg_string + secret ) == signature
            return true
        end
        return false
    end
    
    # Parses cookies in order to extract the facebook cookie and parse it into a useable hash
    #
    # options:
    # * app_id - the connect applications app_id (some users may find they have to use their facebook API key)
    # * secret - the connect application secret
    # * cookies - the cookies given by facebook - it is ok to just pass all of the cookies, the method will do the filtering for you.
    def MiniFB.parse_cookie_information(app_id, cookies)
      return nil if cookies["fbs_#{app_id}"].nil?
      Hash[*cookies["fbs_#{app_id}"].split('&').map{|v| v.gsub('"', '').split('=', 2) }.flatten]
    end
    
    # Validates that the cookies sent by the user are those that were set by facebook. Since your
    # secret is only known by you and facebook it is used to sign all of the cookies set.
    #
    # options:
    # * app_id - the connect applications app_id (some users may find they have to use their facebook API key)
    # * secret - the connect application secret
    # * cookies - the cookies given by facebook - it is ok to just pass all of the cookies, the method will do the filtering for you.
    def MiniFB.verify_cookie_signature(app_id, secret, cookies)
      fb_keys = MiniFB.parse_cookie_information(app_id, cookies)
      return false if fb_keys.nil?
      
      signature = fb_keys.delete('sig')
      return signature == Digest::MD5.hexdigest(fb_keys.map{|k,v| "#{k}=#{v}"}.sort.join + secret)
    end
    
    # <b>DEPRECATED:</b> Please use <tt>verify_cookie_signature</tt> instead.
    def MiniFB.verify_connect_signature(api_key, secret, cookies)
      warn "DEPRECATION WARNING: 'verify_connect_signature' has been renamed to 'verify_cookie_signature' as Facebook no longer calls this 'connect'"
      MiniFB.verify_cookie_signature(api_key, secret, cookies)
    end

    # Returns the login/add app url for your application.
    #
    # options:
    #    - :next => a relative next page to go to. relative to your facebook connect url or if :canvas is true, then relative to facebook app url
    #    - :canvas => true/false - to say whether this is a canvas app or not
    def self.login_url(api_key, options={})
        login_url = "http://api.facebook.com/login.php?api_key=#{api_key}"
        login_url << "&next=#{options[:next]}" if options[:next]
        login_url << "&canvas" if options[:canvas]
        login_url
    end

    # This function expects arguments as a hash, so
    # it is agnostic to different POST handling variants in ruby.
    #
    # Validate the arguments received from facebook. This is usually
    # sent for the iframe in Facebook's canvas. It is not necessary
    # to use this on the auth_token and uid passed to callbacks like
    # post-add and post-remove.
#
    # The arguments must be a mapping of to string keys and values
    # or a string of http request data.
#
    # If the data is invalid or not signed properly, an empty
    # dictionary is returned.
#
    # The secret argument should be an instance of FacebookSecret
    # to hide value from simple introspection.
#
    # DEPRECATED, use verify_signature instead
    def MiniFB.validate( secret, arguments )

        signature = arguments.delete( "fb_sig" )
        return arguments if signature.nil?

        unsigned = Hash.new
        signed = Hash.new

        arguments.each do |k, v|
            if k =~ /^fb_sig_(.*)/ then
                signed[$1] = v
            else
                unsigned[k] = v
            end
        end

        arg_string = String.new
        signed.sort.each { |kv| arg_string << kv[0] << "=" << kv[1] }
        if Digest::MD5.hexdigest( arg_string + secret ) != signature
            unsigned # Hash is incorrect, return only unsigned fields.
        else
            unsigned.merge signed
        end
    end

    class FaceBookSecret
        # Simple container that stores a secret value.
        # Proc cannot be dumped or introspected by normal tools.
        attr_reader :value

        def initialize( value )
            @value = Proc.new { value }
        end
    end
end
