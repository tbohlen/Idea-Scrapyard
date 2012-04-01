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