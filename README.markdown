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

With the session, you can then get the user information for the session/uid.

    user = @fb.user

Then get info from the user:

    first_name = user["first_name"]

Or profile photos:

    photos = user.profile_photos

Or if you want other photos, try:

    photos = @fb.photos("pids"=>[12343243,920382343,9208348])


