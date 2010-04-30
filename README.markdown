MiniFB - the simple miniature facebook library
==============================================

MiniFB is a small, lightweight Ruby library for interacting with the [Facebook API](http://wiki.developers.facebook.com/index.php/API).

Brought to you by: [![Appoxy](http://www.simpledeployr.com/images/global/appoxy-small.png)](http://www.appoxy.com)

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

For an overview of what this is all about, see http://developers.facebook.com/docs/api.

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

Posting Data to Facebook
------------------------

Also pretty simple:

    @id = {some ID of something in facebook}
    @type = {some type of post like comments, likes, feed} # required here
    @response_hash = MiniFB.post(@access_token, @id, :type=>@type)


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
        @fb_uid = cookies[FB_API_KEY + "_user"]
        @fb_session = cookies[FB_API_KEY + "_session_key"]
        puts "uid=#{@fb_uid}"
        puts "session=#{@fb_session}"
        
        if MiniFB.verify_connect_signature(FB_API_KEY, FB_SECRET, cookies)
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
