module MiniFB
    require 'digest/md5'
    require 'erb'
    require 'json/pure'

    # Global constants
    FB_URL = "http://api.facebook.com/restserver.php"
    FB_API_VERSION = "1.0"

    @@logging = false

    def enable_logging
        @@logging = true
    end
    def disable_logging
        @@logging = false
    end

    class FaceBookError < StandardError
        # Error that happens during a facebook call.
        def initialize( error_code, error_msg )
            raise StandardError.new( "Facebook error #{error_code}: #{error_msg}" )
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
        FIELDS = [:uid, :status, :political, :pic_small, :name, :quotes, :is_app_user, :tv, :profile_update_time, :meeting_sex, :hs_info, :timezone, :relationship_status, :hometown_location, :about_me, :wall_count, :significant_other_id, :pic_big, :music, :work_history, :sex, :religion, :notes_count, :activities, :pic_square, :movies, :has_added_app, :education_history, :birthday, :birthday_date, :first_name, :meeting_for, :last_name, :interests, :current_location, :pic, :books, :affiliations, :locale, :profile_url, :proxied_email, :email_hashes, :allowed_restrictions, :pic_with_logo, :pic_big_with_logo, :pic_small_with_logo, :pic_square_with_logo]
        STANDARD_FIELDS = [:uid, :first_name, :last_name, :name, :timezone, :birthday, :sex, :affiliations, :locale, :profile_url, :proxied_email]

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

        puts 'kwargs=' + kwargs.inspect

        # Prepare arguments for call
        call_id = kwargs.fetch("call_id", true)
        if call_id == true then
            kwargs["call_id"] = Time.now.tv_sec.to_s
        else
            kwargs.delete("call_id")
        end

        custom_format = kwargs.include?("format") or kwargs.include?("callback")
        kwargs["format"] ||= "JSON"
        kwargs["v"] ||= FB_API_VERSION
        kwargs["api_key"]||= api_key
        kwargs["method"] ||= method

        # Hash with secret
        arg_string = String.new
        kwargs.sort.each { |kv| arg_string << kv[0] << "=" << kv[1].to_s }
        kwargs["sig"] = Digest::MD5.hexdigest( arg_string + secret.value.call )

        # Call website with POST request
        begin
            response = Net::HTTP.post_form( URI.parse(FB_URL), kwargs )
        rescue SocketError => err
            raise IOError.new( "Cannot connect to the facebook server: " + err )
        end

        # Handle response
        return response.body if custom_format

        data = JSON.parse( response.body )
        puts 'response=' + data.inspect if @@logging
        if data.include?( "error_msg" ) then
            raise FaceBookError.new( data["error_code"] || 1, data["error_msg"] )
        end
        return data
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
        if Digest::MD5.hexdigest( arg_string + secret ) != signature then
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
