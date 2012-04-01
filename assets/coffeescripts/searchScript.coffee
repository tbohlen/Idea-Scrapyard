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






$(document).ready(() -> $('#searchButton').click(() -> searchTags()))
    
window.syCheckSearchSubmit = (e) ->
    console.log("check search!")
    if e and e.keyCode == 13
        searchTags()
    
searchTags = () ->
    val = $('#searchInput')[0].value
    
    if val is $('#searchInput')[0].defaultValue || val is ''                        # make sure there is a title
        $("#searchGroup").removeClass("error").addClass("error")
        $("#searchHelp").addClass("hidden").removeClass("hidden")
    else
        $("#titleGroup").removeClass("error")
        $("#titleHelp").removeClass("hidden").addClass("hidden")
    
        tagsString = val.toLowerCase().replace(' ', '-')
        
        searchCallback = (response) ->
            console.log("Got response")
            console.log(JSON.stringify(response))
            if (not response?) or typeof response is "object"
                showErrorModal()
            else
                $('.resultwrap').html(response)
        
        $.get('/ideas/search/tags/'+tagsString+'/', searchCallback)
    return false