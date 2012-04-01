$(document).ready () -> $('#createideabutton').click () -> createIdea()

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




        
window.syCheckIdeaSubmit = (e) ->
    if e and e.keyCode == 13
        createIdea()
    
createIdea = () ->
    if $('#titleInput')[0].value == $('#titleInput')[0].placeholder || $('#titleInput')[0].value.trim() == ''
        $("#titleGroup").removeClass("error").addClass("error")
        $("#titleHelp").addClass("hidden").removeClass("hidden")
    else if $('#descInput')[0].value == $('#descInput')[0].placeholder || $('#descInput')[0].value.trim() == ''
        $("#descGroup").removeClass("error").addClass("error")
        $("#descHelp").addClass("hidden").removeClass("hidden")
    else if $('#tagInput')[0].value == $('#tagInput')[0].placeholder || $('#tagInput')[0].value == ''
        $("#tagGroup").removeClass("error").addClass("error")
        $("#tagHelp").addClass("hidden").removeClass("hidden")
    else
        $("#titleGroup").removeClass("error")
        $("#titleHelp").removeClass("hidden").addClass("hidden")
        $("#descGroup").removeClass("error")
        $("#descHelp").removeClass("hidden").addClass("hidden")
        $("#tagGroup").removeClass("error")
        $("#tagHelp").removeClass("hidden").addClass("hidden")
        
        toSend = 
            title: $('#titleInput')[0].value
            description: $('#descInput')[0].value
            tags: $('#tagInput')[0].value.toLowerCase().replace(/[^a-z0-9]/, ' ').split(' ')
            
        createIdeaCallback = (response) ->
            console.log("GOT A RESPONSE" + JSON.stringify(response))
            if (not response?) or response.error?
                showErrorModal()
            else
                showPage(response.result)
        $.post('/ideas/create/', toSend, createIdeaCallback)
    return false