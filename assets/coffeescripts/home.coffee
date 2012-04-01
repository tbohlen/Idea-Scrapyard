# add a the string trim method if it does not exist
if typeof(String.prototype.trim) is "undefined"
    String.prototype.trim = () ->
        String(this).replace(/^\s+|\s+$/g, '')

##############################################################################
############################## Reusable Methods ##############################
##############################################################################

getBaseURL = ->
    pathArray = window.location.pathname.split( '/' );
    return pathArray[2] or "";

showPage = (data) ->
    # we know this user and so we should show the home page of the app
    window.location.href = data
        
###
Show the error modal
###
showErrorModal = ->
    $("#errorModal")[0].modal("show")

##############################################################################
############################# Button Interaction #############################
##############################################################################

$(document).ready ->
    $("#emailPermission").change(changeEmailPermission)

changeEmailPermission = ->
    checkboxState = ($("#emailPermission")[0].checked) ? 1 : 0
    console.log("posting checkbox state " + checkboxState.toString())
    $.post('/account/emailPermission/', {newSetting: checkboxState}, emailPermissionChangeCallback)
    
emailPermissionChangeCallback = (response) ->
    console.log("In callback!")
    if response.error?
        showErrorModal()
    else if response.result
        showPermissionChangeModal()
        
showPermissionChangeModal = ->
    $("#permissionModal")[0].modal("show")