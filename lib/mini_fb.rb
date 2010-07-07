#MiniFB - the simple miniature facebook library
#MiniFB is a small, lightweight Ruby library for interacting with the Facebook API.
#
#Brought to you by: www.appoxy.com
#
#Support
#
#Join our Discussion Group at: http://groups.google.com/group/mini_fb
#
#Demo Rails Application
#
#There is a demo Rails app that uses mini_fb graph api at: http://github.com/appoxy/mini_fb_demo

require 'digest/md5'
require 'erb'
require 'json' unless defined? JSON
require 'rest_client'
require 'hashie'

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
        def initialize(error_code, error_msg)
            @code = error_code
            super("Facebook error #{error_code}: #{error_msg}")
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

    BAD_JSON_METHODS = ["users.getloggedinuser", "auth.promotesession", "users.hasapppermission",
                        "Auth.revokeExtendedPermission", "pages.isAdmin", "pages.isFan",
                        "stream.publish",
                        "dashboard.addNews", "dashboard.addGlobalNews", "dashboard.publishActivity",
                        "dashboard.incrementcount", "dashboard.setcount"
    ].collect { |x| x.downcase }

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
    def MiniFB.call(api_key, secret, method, kwargs)

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

        kwargs["sig"] = signature_for(kwargs, secret.value.call)

        fb_method = kwargs["method"].downcase
        if fb_method == "photos.upload"
            # Then we need a multipart post
            response = MiniFB.post_upload(file_name, kwargs)
        else

            begin
                response = Net::HTTP.post_form(URI.parse(FB_URL), post_params(kwargs))
            rescue SocketError => err
                # why are we catching this and throwing as different error?  hmmm..
                # raise IOError.new( "Cannot connect to the facebook server: " + err )
                raise err
            end
        end

        # Handle response
        return response.body if custom_format

        body = response.body

        puts 'response=' + body.inspect if @@logging
        begin
            data = JSON.parse(body)
            if data.include?("error_msg")
                raise FaceBookError.new(data["error_code"] || 1, data["error_msg"])
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
        Net::HTTP.start(uri.host) { |http| http.post uri.path, query, header }
    end

    # Returns true is signature is valid, false otherwise.
    def MiniFB.verify_signature(secret, arguments)
        signature = arguments.delete("fb_sig")
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
        if Digest::MD5.hexdigest(arg_string + secret) == signature
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
        Hash[*cookies["fbs_#{app_id}"].split('&').map { |v| v.gsub('"', '').split('=', 2) }.flatten]
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
        return signature == Digest::MD5.hexdigest(fb_keys.map { |k, v| "#{k}=#{v}" }.sort.join + secret)
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

    # Manages access_token and locale params for an OAuth connection
    class OAuthSession

        def initialize(access_token, locale="en_US")
            @access_token = access_token
            @locale = locale
        end

        def get(id, options={})
            MiniFB.get(@access_token, id, session_options(options))
        end

        def post(id, options={})
            MiniFB.post(@access_token, id, session_options(options))
        end

        def fql(fql_query, options={})
            MiniFB.fql(@access_token, fql_query, session_options(options))
        end

        def multifql(fql_queries, options={})
            MiniFB.multifql(@access_token, fql_queries, session_options(options))
        end

        def rest(api_method, options={})
            MiniFB.rest(@access_token, api_method, session_options(options))
        end
        
        # Returns a GraphObject for the given id
        def graph_object(id)
            MiniFB::GraphObject.new(self, id)
        end

        # Returns and caches a GraphObject for the user
        def me
            @me ||= graph_object('me')
        end

        private
            def session_options(options)
                (options[:params] ||= {})[:locale] ||= @locale
                options
            end
    end

    # Wraps a graph object for easily accessing its connections
    class GraphObject
        # Creates a GraphObject using an OAuthSession or access_token
        def initialize(session_or_token, id)
            @oauth_session = if session_or_token.is_a?(MiniFB::OAuthSession)
                session_or_token
            else
                MiniFB::OAuthSession.new(session_or_token)
            end
            @id = id
            @object = @oauth_session.get(id, :metadata => true)
            @connections_cache = {}
        end

        def inspect
            "<##{self.class.name} #{@object.inspect}>"
        end

        def connections
            @object.metadata.connections.keys
        end

#        undef :id, :type

        def methods
            super + @object.keys.include?(key) + connections.include?(key)
        end

        def respond_to?(method)
            @object.keys.include?(key) || connections.include?(key) || super
        end

        def keys
            @object.keys
        end

        def [](key)
            @object[key]
        end

        def method_missing(method, *args, &block)
            key = method.to_s
            if @object.keys.include?(key)
                @object[key]
            elsif @connections_cache.has_key?(key)
                @connections_cache[key]
            elsif connections.include?(key)
                @connections_cache[key] = @oauth_session.get(@id, :type => key)
            else
                super
            end
        end
    end

    def self.graph_base
        "https://graph.facebook.com/"
    end

    # options:
    #   - scope: comma separated list of extends permissions. see http://developers.facebook.com/docs/authentication/permissions
    def self.oauth_url(app_id, redirect_uri, options={})
        oauth_url = "#{graph_base}oauth/authorize"
        oauth_url << "?client_id=#{app_id}"
        oauth_url << "&redirect_uri=#{URI.escape(redirect_uri)}"
#        oauth_url << "&scope=#{options[:scope]}" if options[:scope]
        oauth_url << ("&" + options.map { |k, v| "%s=%s" % [k, v] }.join('&')) unless options.empty?
        oauth_url
    end

    # returns a hash with one value being 'access_token', the other being 'expires'
    def self.oauth_access_token(app_id, redirect_uri, secret, code)
        oauth_url = "#{graph_base}oauth/access_token"
        oauth_url << "?client_id=#{app_id}"
        oauth_url << "&redirect_uri=#{URI.escape(redirect_uri)}"
        oauth_url << "&client_secret=#{secret}"
        oauth_url << "&code=#{URI.escape(code)}"
        resp = RestClient.get oauth_url
        puts 'resp=' + resp.body.to_s if @@logging
        params = {}
        params_array = resp.split("&")
        params_array.each do |p|
            ps = p.split("=")
            params[ps[0]] = ps[1]
        end
        return params
    end

    # Gets data from the Facebook Graph API
    # options:
    #   - type: eg: feed, home, etc
    #   - metadata: to include metadata in response. true/false
    #   - params: Any additional parameters you would like to submit
    def self.get(access_token, id, options={})
        url = "#{graph_base}#{id}"
        url << "/#{options[:type]}" if options[:type]
        params = options[:params] || {}
        params["access_token"] = "#{(access_token)}"
        params["metadata"] = "1" if options[:metadata]
        options[:params] = params
        return fetch(url, options)
    end

    # Posts data to the Facebook Graph API
    # options:
    #   - type: eg: feed, home, etc
    #   - metadata: to include metadata in response. true/false
    #   - params: Any additional parameters you would like to submit
    def self.post(access_token, id, options={})
        url = "#{graph_base}#{id}"
        url << "/#{options[:type]}" if options[:type]
        options.delete(:type)
        params = options[:params] || {}
        options.each do |key, value|
            if value.kind_of?(File)
                params[key] = value
            else
                params[key] = "#{value}"
            end
        end
        params["access_token"] = "#{(access_token)}"
        params["metadata"] = "1" if options[:metadata]
        options[:params] = params
        options[:method] = :post
        return fetch(url, options)

    end

    # Executes an FQL query
    def self.fql(access_token, fql_query, options={})
        url = "https://api.facebook.com/method/fql.query"
        params = options[:params] || {}
        params["access_token"] = "#{(access_token)}"
        params["metadata"] = "1" if options[:metadata]
        params["query"] = fql_query
        params["format"] = "JSON"
        options[:params] = params
        return fetch(url, options)
    end

    # Executes multiple FQL queries
    # Example:
    #
    # MiniFB.multifql(access_token, { :statuses => "SELECT status_id, message FROM status WHERE uid = 12345",
    #                                 :privacy => "SELECT object_id, description FROM privacy WHERE object_id IN (SELECT status_id FROM #statuses)" })
    def self.multifql(access_token, fql_queries, options={})
      url = "https://api.facebook.com/method/fql.multiquery"
      params = options[:params] || {}
      params["access_token"] = "#{(access_token)}"
      params["metadata"] = "1" if options[:metadata]
      params["queries"] = JSON[fql_queries]
      params[:format] = "JSON"
      options[:params] = params
      return fetch(url, options)
    end
    
    # Uses new Oauth 2 authentication against old Facebook REST API
     # options:
    #   - params: Any additional parameters you would like to submit
    def self.rest(access_token, api_method, options={})
        url = "https://api.facebook.com/method/#{api_method}"
        params = options[:params] || {}
        params[:access_token] = access_token
        params[:format] = "JSON"
        options[:params] = params
        return fetch(url, options)
    end


    def self.fetch(url, options={})

        begin
            if options[:method] == :post
                puts 'url_post=' + url if @@logging
                resp = RestClient.post url, options[:params]
            else
                if options[:params] && options[:params].size > 0
                    url += '?' + options[:params].map { |k, v| URI.escape("%s=%s" % [k, v]) }.join('&')
                end
                puts 'url_get=' + url if @@logging
                resp = RestClient.get url
            end

            puts 'resp=' + resp.to_s if @@logging

            begin
                res_hash = JSON.parse(resp.to_s)
            rescue
                # quick fix for things like stream.publish that don't return json
                res_hash = JSON.parse("{\"response\": #{resp.to_s}}")
            end

            if res_hash.is_a? Array # fql  return this
                res_hash.collect! { |x| Hashie::Mash.new(x) }
            else
                res_hash = Hashie::Mash.new(res_hash)
            end

            if res_hash.include?("error_msg")
                raise FaceBookError.new(res_hash["error_code"] || 1, res_hash["error_msg"])
            end

            return res_hash
        rescue RestClient::Exception => ex
            puts ex.http_code.to_s
            puts 'ex.http_body=' + ex.http_body if @@logging
            res_hash = JSON.parse(ex.http_body) # probably should ensure it has a good response
            raise MiniFB::FaceBookError.new(ex.http_code, "#{res_hash["error"]["type"]}: #{res_hash["error"]["message"]}")
        end

    end

    # Returns all available scopes.
    def self.scopes
        scopes = %w{
            about_me activities birthday education_history events groups
            hometown interests likes location notes online_presence
            photo_video_tags photos relationships religion_politics
            status videos website work_history
        }
        scopes.map! do |scope|
            ["user_#{scope}", "friends_#{scope}"]
        end.flatten!

        scopes += %w{
          read_insights read_stream read_mailbox read_friendlists read_requests
          email ads_management xmpp_login
          publish_stream create_event rsvp_event sms offline_access
        }
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
    def MiniFB.validate(secret, arguments)

        signature = arguments.delete("fb_sig")
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
        if Digest::MD5.hexdigest(arg_string + secret) != signature
            unsigned # Hash is incorrect, return only unsigned fields.
        else
            unsigned.merge signed
        end
    end

    class FaceBookSecret
        # Simple container that stores a secret value.
        # Proc cannot be dumped or introspected by normal tools.
        attr_reader :value

        def initialize(value)
            @value = Proc.new { value }
        end
    end

    private
    def self.post_params(params)
        post_params = {}
        params.each do |k, v|
            k = k.to_s unless k.is_a?(String)
            if Array === v || Hash === v
                post_params[k] = JSON.dump(v)
            else
                post_params[k] = v
            end
        end
        post_params
    end

    def self.signature_for(params, secret)
        params.delete_if { |k, v| v.nil? }
        raw_string = params.inject([]) do |collection, pair|
            collection << pair.map { |x|
                Array === x ? JSON.dump(x) : x
            }.join("=")
            collection
        end.sort.join
        Digest::MD5.hexdigest([raw_string, secret].join)
    end
end
