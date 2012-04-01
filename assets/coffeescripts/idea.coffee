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
    location.href = data
        
###
Show the error modal
###
showErrorModal = () ->
    $("#errorModal").modal("show")  

######### For This Page #########

$(document).ready(() -> $('#newcommentbutton').click(() -> makeComment()))

makeComment = () ->
    console.log()
    if $('#commentBody')[0].value is $('#commentBody')[0].placeholder or $('#commentBody')[0].value is ''
        # does nothing ATM
    else if $('#commentTitle')[0].value is $('#commentTitle')[0].placeholder or $('#commentTitle')[0].value is ''
        # does nothing ATM
    else
        newCommentTitle = $('#commentTitle')[0].value
        newCommentBody = $('#commentBody')[0].value
        splitPath = window.location.pathname.split('/')                                         # split the pathname by / to find the idea number
        ideaNum = splitPath[splitPath.length - 1]
        if ideaNum is ''
            ideaNum = splitPath[splitPath.length - 2]                                   # need to compensate for the trailing / so check to see if the last substring is empty
        data =
            title : newCommentTitle
            message : newCommentBody
            idea : ideaNum
    
        createCommentCallback = (response) ->
            console.log("Comment result is " + JSON.stringify(response))
            if (not response?) or typeof response is "object"
                showErrorModal()
            else if typeof response is "string"
                $('#newcommentform').before(response)
                $('#commentBody')[0].value = ''
                $('#commentBody').toggleClass('idlefield').toggleClass('focusfield')
                $('#commentTitle')[0].value = ''
                $('#commentTitle').toggleClass('idlefield').toggleClass('focusfield')
    
        $.post('/ideas/comments/create/', data, createCommentCallback)
    return false

###
Team joining through button interaction
###
window.syJoinTeam = ->
    splitPath = window.location.pathname.split('/')
    ideaID = splitPath[splitPath.length - 1]
    if ideaID is ''
        ideaID = splitPath[splitPath.length - 2]
    joinCallback = (response) ->
        console.log("Join response ")
        console.log(JSON.stringify(response))
        if not response.allowed
            showPage("/notAllowed/")
        else if response.error? or not response.result?
            showErrorModal()
        else
            # put the user on the team list
            if $(".members p").length == 1
                $("#noMembers").toggleClass("hidden")
            $(".members").append("<p id='" + response.result.id.toString() + "'><a href='/account/"+response.result.id.toString()+"/'>" + response.result.name.toString() + "</ a></ p>")
            $("#leaveButton").toggleClass('hidden')
            $("#joinButton").toggleClass('hidden')
    
    $.post("/team/join/", {idea: ideaID}, joinCallback)

###
Removal from team through button interaction
###
window.syLeaveTeam = ->
    splitPath = window.location.pathname.split('/')
    ideaID = splitPath[splitPath.length - 1]
    if ideaID is ''
        ideaID = splitPath[splitPath.length - 2]
    
    leaveCallback = (response) ->
        if not response.allowed
            showPage("/notAllowed/")
        else if response.error? or not response.result?
            showErrorModal()
        else
            $("#"+response.result.id).remove()
            $("#leaveButton").toggleClass('hidden')
            $("#joinButton").toggleClass('hidden')
            if $(".members p").length == 1
                $("#noMembers").toggleClass("hidden")
    
    $.post("/team/leave/", ideaID, leaveCallback)