MiniFB - the simple miniature facebook library
==============================================

MiniFB is a small, lightweight Ruby library for interacting with the [Facebook API](http://wiki.developers.facebook.com/index.php/API).

Installation
-------------

We're using gemcutter so be sure to have gemcutter as a source, then: 

    gem install mini_fb

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

        # And here you would create the user if it doesn't already exist, then redirect them to wherever you want.

    end


Photo Uploads
-------------

This is as simple as calling:

    @fb.call("photos.upload", "file_name"=>"<full path to file>")

The file_name parameter will be used as the file data.


Support
--------

Join our Discussion Group at: http://groups.google.com/group/mini_fb

