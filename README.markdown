MiniFB - the simple miniature facebook library
==============================================

MiniFB is a small, lightweight Ruby library for interacting with the [Facebook API](http://wiki.developers.facebook.com/index.php/API).

Brought to you by: [![Appoxy](https://lh5.googleusercontent.com/_-J9DSaseOX8/TX2Bq564w-I/AAAAAAAAxYU/xjeReyoxa8o/s800/appoxy-small%20%282%29.png)](http://www.appoxy.com)

Support
--------

Join our Discussion Group at: <http://groups.google.com/group/mini_fb>

Demo Rails Application
-------------------

There is a demo Rails app that uses mini_fb graph api at: [http://github.com/appoxy/mini_fb_demo](http://github.com/appoxy/mini_fb_demo)

Installation
-------------

    gem install mini_fb


Facebook Graph API
==================

For an overview of what this is all about, see <http://developers.facebook.com/docs/api>.

Authentication
--------------

Facebook now uses Oauth 2 for authentication, but don't worry, this part is easy.

    # Get your oauth url
    @oauth_url = MiniFB.oauth_url(FB_APP_ID, # your Facebook App ID (NOT API_KEY)
                                  "http://www.yoursite.com/sessions/create", # redirect url
                                  :scope=>MiniFB.scopes.join(",")) # This asks for all permissions
    # Have your users click on a link to @oauth_url
    .....
    # Then in your /sessions/create
    access_token_hash = MiniFB.oauth_access_token(FB_APP_ID, "http://www.yoursite.com/sessions/create", FB_SECRET, params[:code])
    @access_token = access_token_hash["access_token"]
    # TODO: This is where you'd want to store the token in your database
    # but for now, we'll just keep it in the cookie so we don't need a database
    cookies[:access_token] = @access_token

That's it. You now need to hold onto this access_token. We've put it in a cookie for now, but you probably
want to store it in your database or something.

Getting Data from Facebook
--------------------------

It's very simple:

    @id = {some ID of something in facebook} || "me"
    @type = {some facebook type like feed, friends, or photos} # (optional) nil will just return the object data directly
    @response_hash = MiniFB.get(@access_token, @id, :type=>@type)
    # @response_hash is a hash, but also allows object like syntax for instance, the following is true:
    @response_hash["user"] == @response_hash.user

See <http://developers.facebook.com/docs/api> for the available types.

Posting Data to Facebook
------------------------

Also pretty simple:

    @id = {some ID of something in facebook}
    @type = {some type of post like comments, likes, feed} # required here
    @response_hash = MiniFB.post(@access_token, @id, :type=>@type)

Searching Facebook
------------------

Equally simple:

    @query  = {the thing you want to search for - i.e. 'email@gmail.com', 'watermelon', 'John O'Callaghan'}
    @type   = {the resource you are searching - i.e. 'user', 'post', 'page', 'event', 'group', ...}
    @response_hash = MiniFB.search(@access_token, :q = @query, :type => @type)

See <http://developers.facebook.com/docs/api#search> for more information.
    
FQL
---

    my_query = "select uid,a,b,c from users where ...."
    @res = MiniFB.fql(@access_token, my_query)

Logging
-------

To enabled logging:

    MiniFB.enable_logging


Original Facebook API
=====================

This API will probably go away at some point, so you should use the Graph API above in most cases.


General Usage
-------------

The most general case is to use MiniFB.call method:

    user_hash = MiniFB.call(FB_API_KEY, FB_SECRET, "Users.getInfo", "session_key"=>@session_key, "uids"=>@uid, "fields"=>User.all_fields)

Which simply returns the parsed json response from Facebook.


Oauth 2.0 Authentication and Original Rest Api
-------------

You can use the Graph api Oauth 2.0 token with original api methods. BEWARE: This has only been tested against stream.publish at present.

    MiniFB.rest(@access_token, "rest.api.method", options)

eg:

    response = MiniFB.rest(@access_token, "stream.publish", :params => {
      :uid => @user_id, :target_id => @target_user_id,
      :message => "Hello other user!"
    })
    
and for file uploads, give the file's (usually an image) path as a string

    response = MiniFB.rest(@access_token, "events.create", :params => {
      :event_info => { :name => 'My super duper event', :start_date => '2010-03-20 15:30:00' }, 
      :file => "/path/to/file.jpg"
    })
    
all responses will be json. In the instance of 'bad json' methods, the response will formatted {'response': '#{bad_response_string}'}


Some Higher Level Objects for Common Uses
----------------------

Get a MiniFB::Session:

    @fb = MiniFB::Session.new(FB_API_KEY, FB_SECRET, @fb_session, @fb_uid)

Then it makes it a bit easier to use call for a particular user/session.

    response = @fb.call("stream.get")

With the session, you can then get the user information for the session/uid.

    user = @fb.user

Then get info from the user:

    first_name = user["first_name"]

Or profile photos:

    photos = user.profile_photos

Or if you want other photos, try:

    photos = @fb.photos("pids"=>[12343243,920382343,9208348])


Higher Level Objects with OAuth2
--------------------------------

Get a MiniFB::OAuthSession with a Spanish locale:

    @fb = MiniFB::OAuthSession.new(access_token, 'es_ES')

Using the session object to make requests:

    @fb.get('117199051648010')
    @fb.post('me', :type => :feed, :params => {
      :message => "This is me from MiniFB"
    })
    @fb.fql('SELECT id FROM object_url WHERE url="http://www.imdb.com/title/tt1250777/"')
    @fb.rest('notes.create', :params => {
      :title => "ToDo", :content => "Try MiniFB"
    })

Getting graph objects through the session:

    @fb.me
    @fb.me.name
    @fb.me.connections
    @fb.me.feed

    @ssp = @fb.graph_object('117199051648010')
    @ssp.mission
    @ssp.photos


Facebook Connect
----------------

This is actually very easy, first follow these instructions: http://wiki.developers.facebook.com/index.php/Connect/Setting_Up_Your_Site

Then add the following script to the page where you put the login button so it looks like this:

    <script>
        function facebook_onlogin(){
            document.location.href = "<%= url_for :action=>"fb_connect" %>";
        }
    </script>
    <fb:login-button onlogin="facebook_onlogin();"></fb:login-button>

Define an fb_connect method in your login/sessions controller like so:

     def fb_connect
        @fb_info = MiniFB.parse_cookie_information(FB_APP_ID, cookies) # some users may have to use their API rather than the app. ID.
        puts "uid=#{@fb_info['uid']}"
        puts "session=#{@fb_info['session_key']}"
        
        if MiniFB.verify_cookie_signature(FB_APP_ID, FB_SECRET, cookies)
          # And here you would create the user if it doesn't already exist, then redirect them to wherever you want.
        else
          # The cookies may have been modified as the signature does not match
        end

    end


Photo Uploads
-------------

This is as simple as calling:

    @fb.call("photos.upload", "filename"=>"<full path to file>")

The file_name parameter will be used as the file data.
