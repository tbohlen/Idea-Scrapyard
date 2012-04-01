# add a the string trim method if it does not exist
if typeof(String.prototype.trim) is "undefined"
    String.prototype.trim = () ->
        String(this).replace(/^\s+|\s+$/g, '')

##############################################################################
############################## Reusable Methods ##############################
##############################################################################

getBaseURL = () ->
    pathArray = window.location.pathname.split( '/' );
    return pathArray[2] or "";

showPage = (data) ->
    # we know this user and so we should show the home page of the app
    window.location.href = data
        
###
Show the error modal
###
showErrorModal = () ->
    $("#errorModal").modal("show")

###
Timeout to call if facebook does not respond the our loginStatus call on page load.

Redirects to the landing page and is only used by index
###
window.syFacebookTimeoutCallback = () ->
    showPage('/landing/')

window.syLogoutCallback = (response) ->
    $.post('/account/logout/', userLogoutCallback)
    
userLogoutCallback = (response) ->
    if response
        showPage('/landing/')
    else
        showErrorModal()

##############################################################################
############################### Facebook calls ###############################
##############################################################################

window.syLoginStatusCallback = (response) ->
    window.clearTimeout(window.syFacebookTimeoutID)
    if (not response?) or response.error? or (not response.authResponse?)
        showPage("/landing/")
    else
        # logged in and connected user, someone you know
        $.getJSON("http://graph.facebook.com/" + response.authResponse.userID, {accessToken : response.authResponse.accessToken}, userInfoCallback)
        
userInfoCallback = (response) ->
    if (not response?) or (response.error?) or (not response.authResponse?)
        showPage("/landing/")
    else
        $.post('/account/recognize/', {"userInfo" : response}, userRecognizeCallback)
    
userRecognizeCallback = (data) ->
    if (not data) or data.error
        # TODO: show a fail page
        showErrorModal()
    else if data.signedIn
        showPage("/home/") # TODO: take a look at doing this in a cleaner way
    else
        showPage("/landing/")
    
window.syLoginCallback = (response) ->
    $.getJSON("http://graph.facebook.com/" + response.authResponse.userID, userInfoCallback)