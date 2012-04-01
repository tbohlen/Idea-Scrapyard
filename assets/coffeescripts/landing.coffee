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
TODO: check if the user is signed in to facebook but not the site on page load and display the relevant modal if so.
###
    
showFailedLoginModal = () ->
    $("#failedLoginModal").modal("show")
    
showPasswordModal = () ->
    $("#passwordModal").modal("show")

hidePasswordModal = () ->
    $("#passwordModal").modal("hide")

##############################################################################
############################# Button Interaction #############################
##############################################################################

window.syLogin = (response) ->
    FB.login(window.syLoginCallback, {scope: 'email'})

##############################################################################
####################### Facebook methods and callbacks #######################
##############################################################################
    
window.syLoginCallback = (response) ->
    if (not response?) or (response.error?)
        showFailedLoginModal()
    else
        $.getJSON("http://graph.facebook.com/" + response.authResponse.userID, {accessToken : response.authResponse.accessToken}, userInfoCallback)

userInfoCallback = (response, status, item) ->
    if (not response?) or (response.error?)
        showFailedLoginModal()
    else
        $.post('/account/recognize/', {"userInfo" : response}, userInfoSuccess)
    
userInfoSuccess = (data) ->
    if (not data?) or (data.error?)
        showErrorModal()
    else if data.result == "signedIn" or data.result == "true" or data.result == 1
        console.log("User is signed in. Redirecting to home.")
        showPage("/home/")
    else
        showPasswordModal()
        
##############################################################################
############################# Password handling ##############################
##############################################################################

window.sySubmitPassword = () ->
    console.log("Submitting password")
    $.post('/password/', {password: $('#password')[0].value.toString()}, passwordCallback)

passwordCallback = (response) ->
    $("#passwordGroup").removeClass("error")
    $("#badPassword").hide()
    if (not response?) 
        hidePasswordModal()
        showErrorModal()
    else if response.badPassword
        $("#passwordGroup").addClass("error")
        $("#badPassword").show()
    else if response.error? or (not response.result?)
        hidePasswordModal()
        showErrorModal()
    else
        showPage(response.result)