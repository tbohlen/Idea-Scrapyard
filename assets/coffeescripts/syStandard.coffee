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
        

##############################################################################
####### Facebook login callbacks to create user, save information etc. #######
##############################################################################
# 
# showNavCallback = (data) ->
#   $("#navwrap").html(data)
#   window.prepareLinks("[class ~='navlink']", "activenavlink")
#   window.prepareLinks("[class ~='fblink']", "activefblink")
# 
# userInfoCallback = (data) ->
#   window.userInfo = data
#   $.post('/account/recognize/', data, showNavCallback)
# 
# window.syLoginStatusCallback = (response) ->
#   if response.authResponse
#       # logged in and connected user, someone you know
#       $.getJSON("http://graph.facebook.com/" + response.authResponse.userID, userInfoCallback)
#   else
#       # if this user is not logged in with facebook then we need to fill in the bar like normal
#       $.get('/nav-normal/', showNavCallback)
#       
# window.syLogoutCallback = (response) ->
#   $.get('/nav-normal/', showNavCallback)
#   
# window.syLoginCallback = (response) ->
#   $.getJSON("http://graph.facebook.com/" + response.authResponse.userID, userInfoCallback)


##############################################################################
####################### Helper Methods for JQuery prep #######################
##############################################################################

# window.prepareLinks = (selector, activeClass) ->
#   $(selector).hover(
#       () -> $(this).toggleClass(activeClass),
#       () -> $(this).toggleClass(activeClass)
#       )
# 
# window.prepareFields = (selector) ->
#   # set up input fields so that they clear and change color at appropriate times
#   $(selector).addClass("idlefield")
#   $(selector).focus(() ->
#       if this.value is this.defaultValue
#           this.value = ""
#           $(this).toggleClass("idlefield").toggleClass("focusfield")
#       )
#   $(selector).blur(() ->
#       if not this.value or this.value.trim() is 0
#           this.value = this.defaultValue
#           $(this).toggleClass("idlefield").toggleClass("focusfield")
#       )

##############################################################################
############################## Document Ready ################################
##############################################################################

# $('document').ready(() ->             
    # window.prepareLinks("[class ~='link']", "active")
    # window.prepareLinks("[class ~='fblink']", "activefblink")
    # window.prepareLinks("[class ~='navlink']", "activenavlink")
    # window.prepareLinks("[class ~='homebutton']", "activehomebutton")
    # window.prepareFields("[class~='formfield']")
    # )