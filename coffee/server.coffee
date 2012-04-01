###
TODO: Implement errors!
TODO: Unify variable names: accountInfo, accountData, userInfo, etc.
TODO: Do not attach all the idea information to the accountdata
###

http = require('http')
url = require('url')
qs = require('querystring')
fs = require('fs')
path = require('path')
redis = require('redis')
express = require('express')
redisStore = require('connect-redis')(express)
jade = require('jade')
stylus = require('stylus')
bootstrap = require('./assets/bootstrap/index.js')
# connectAssets = require('connect-assets')
coffee = require("express-coffee")
logger = require("./logger.js")
###
for running on the dotcloud server
###
dotcloudEnv = JSON.parse(fs.readFileSync('/home/dotcloud/environment.json', 'utf-8'));
redisClient = redis.createClient(dotcloudEnv.DOTCLOUD_DATA_REDIS_PORT, dotcloudEnv.DOTCLOUD_DATA_REDIS_HOST);
redisClient.auth(dotcloudEnv.DOTCLOUD_DATA_REDIS_PASSWORD, (result) -> logger.log(null, "Redis auth result: " + result))

###
for testing locally
###
# redisPort = 6379
# redisAddress = '127.0.0.1'
# redisClient = redis.createClient(redisPort, redisAddress)

# constants (that could just be stored with app.set)
sessionKey = "scrapyard-key"
sessionSecret = "hitherehackers"

redisClient.on("error", (err) -> logger.log(null, "Redis connection error to " + redisClient.host + ":" + redisClient.port + " - " + err))
redisClient.setnx('ideaCoufnt', 0)
redisClient.setnx('commentCount', 0)

app = express.createServer()
app.listen(8080)

###
TODO: de-spaghettiafy
###

app.configure () ->
    app.set('view engine', 'jade')
    app.set('tagsKey', 'allTags')
    app.set('wordsKey', 'allWords')
    app.set('ideasKey', 'allIdeas')
    app.set('recentIdeasKey', 'recentIdeas')
    app.set('maxDescriptionLength', 210)
    app.set('maxTeamSize', 4)
    
    stylusOptions = {src: __dirname + '/assets/stylus/'
                   , dest: __dirname + '/assets/'
                   , compile: (str, path) -> stylus(str).use(bootstrap()).set('filename', path).set('warn', true).set('compress', true)}
                    
    coffeeOptions = {path: __dirname+'/assets/'
                   , live: false
                   , uglify: false}
                   
    redisStoreOptions = {client: redisClient}
    
    path = "log"
    logStream= fs.createWriteStream(path, {
        'flags': 'a+'
        , 'encoding': 'utf8'
        , 'mode': 0666
    })
    
    app.use stylus.middleware(stylusOptions)
    app.use coffee(coffeeOptions)
    app.use express.logger({format : "default", stream : logStream, format: ':method :url'})
    app.use express.methodOverride()
    app.use express.bodyParser()
    app.use express.cookieParser({secret: sessionSecret})
    app.use express.session({key: sessionKey, secret: sessionSecret, store:new redisStore(redisStoreOptions)})
    # app.use connectAssets({src:'./assets/'})
    app.use app.router
    app.use express.static(__dirname + '/assets/', {maxAge: 31557600000})
    app.use (err, req, res, next) -> res.render __dirname + "/views/jade/error.jade", {layout: false, error: err}

#########################################################################
####################### Standard Page Serving ###########################
#########################################################################
    
app.get "/?", (req, res, next) ->
    # TODO: get the last some_number of ideas posted and include them on the index page
    res.render(__dirname + "/views/jade/index.jade", {layout: false})
    
app.get "/ideas/test/?", (req, res, next) ->
    res.render __dirname + "/views/jade/idea.jade", {layout: false, title: "Test Title", description: ["Test Description", "Blah Blah Blah"], comments: [], creator: "Turner Bohlen"}
    
app.get "/ideas/howMany/?", (req, res, next) ->
    redisClient.get 'ideaCount', (err, result) ->
        res.send result
        
app.get "/notAllowed/?", (req, res, next) ->
    res.render __dirname + "/views/jade/notAllowed.jade", {layout: false}
        
app.get "/contact/?", (req, res, next) ->
    res.render __dirname + "/views/jade/contact.jade", {layout: false}
    
        
app.get "/home/?", (req, res, next) ->
    accountData = req.session.userInfo
    
    if not checkAuthorized(accountData)
        res.redirect("/landing/")
    else
        
        allUserDataCallback = (userError, userResult) ->
            if userError? or (not userResult?)
                next userError
            else
            
                recentIdeasCallback = (ideasError, ideasResult) ->
                    if ideasError?
                        ideasResult = []
                    if not userResult.email?
                        userResult.email = "none"
                    userResult.email ?= "none"
                    locals = {layout : false, userInfo : userResult, recentIdeas: ideasResult}
                    res.render(__dirname + "/views/jade/home.jade", locals)
            
                allRecentIdeas(recentIdeasCallback)
                
        allUserData(accountData.id, allUserDataCallback)
    
app.get "/landing/?", (req, res, next) ->
    res.render __dirname + "/views/jade/landing.jade", {layout: false}
    
app.get "/about/?", (req, res, next) ->
    accountData = req.session.userInfo
    if accountData.id and accountData.signedIn
        locals =
            userInfo: accountData
            layout: false
        res.render(__dirname + "/views/jade/newVisitor.jade", locals)
    else
        res.redirect "/landing/"
    
app.get "/newVisitor/?", (req, res, next) ->
    accountData = req.session.userInfo
    if checkAuthorized(accountData)
        locals =
            userInfo: accountData
            layout: false
        res.render __dirname + "/views/jade/newVisitor.jade", locals
    else
        res.redirect "/landing/"
        
app.get "/suggested-projects/mozillaWatchdog/?", (req, res, next) ->
    accountData = req.session.userInfo
    if checkAuthorized(accountData)
        res.render(__dirname + "/views/jade/suggested-projects/mozillaWatchdog.jade", {layout: false})
    else
        res.redirect("/landing/")
    
    
app.get "/suggested-projects/mozillaPersona/?", (req, res, next) ->
    accountData = req.session.userInfo
    if checkAuthorized(accountData)
        res.render(__dirname + "/views/jade/suggested-projects/mozillaPersona.jade", {layout: false})
    else
        res.redirect("/landing/")
    
#########################################################################
####################### Dealing with Passwords ##########################
#########################################################################

app.post '/password/?', (req, res, next) ->
    accountData = req.session.userInfo
    response = {}
    
    if (not accountData?) or (not accountData.first_name?) or (not accountData.id?)
        response.result = false
        response.error = "We do not have the necessary information from Facebook to log you in."
        res.send(response)
        
    else if req.body.password == accountData.first_name.toString().toLowerCase() + '-hack'
        key = 'user:' + accountData.id.toString()
        
        setSignedInCallback = (signInErr, signInResponse) ->
            if signInErr?
                response.result = false
                response.error = signInErr
                res.send(response)
            else
                req.session.userInfo.signedIn = 1
                response.result = "/newVisitor/"
                response.error = null
                res.send(response)
                
        redisClient.hset key, 'signedIn', true, setSignedInCallback
        
    else
        response.error = "Incorrect password"
        response.badPassword = true
        response.result = false
        res.send response
        
#########################################################################
########################## Eamil Permissions ############################
#########################################################################

app.post '/account/emailPermission/?', (req, res, next) ->
    accountData = req.session.userInfo
    newSetting = req.body.newSetting
    response = {}
    if not checkAuthorized(accountData)
        response.allowed = false
        response.error = "Not allowed"
        response.result = null
        res.send response
    else
        userKey = "user:" + accountData.id
        newSettingCallback = (error, result) ->
            if error?
                response.error = error
                response.allowed = true
                response.result = null
                res.send response
            else
                response.error = null
                response.allowed = true
                response.result = true
                req.session.userInfo.shareEmail = newSetting
                res.send response
        redisClient.hset(userKey, "shareEmail", newSetting, newSettingCallback)

#########################################################################
############################ Idea Serving ###############################
#########################################################################

app.get '/ideas/new/?', (req, res, next) ->
    accountData = req.session.userInfo
    if not checkAuthorized(accountData)
        res.render __dirname + '/views/jade/notAllowed.jade', {layout: false}
    else
        res.render(__dirname + '/views/jade/newIdea.jade', {layout: false})
    
app.get '/ideas/search/?', (req, res, next) ->
    res.render(__dirname + '/views/jade/search.jade', {layout: false, results: [], tags: []})

###
posts to ideas/create builds new idea entries in the database
###
app.post '/ideas/create/?', (req, res, next) ->
    # TODO: find a way to prettify the URLs
    accountData = req.session.userInfo
    response = {}
    if not checkAuthorized(accountData)
        res.render __dirname + '/views/jade/notAllowed.jade', {layout: false}
    else
        incrementCountCallback = (countError, ideaNumber) ->       # retrieve the next available idea number and assign it to this idea
            if countError?
                response.error = countError
                response.result = null
                res.send(response)
            else
                ideaName = "idea:" + ideaNumber         # generate key and data for redis
                currentTime = new Date().getTime()
                redisData =                             # prepare the data that we will store for this idea
                    title: req.body.title
                    id: ideaNumber
                    description: req.body.description
                    creator: accountData.id
                    tags : req.body.tags
                    date: currentTime
                    upvotes: 0
                    downvotes: 0
                    comments: 0
                    contributors: 0
                
                # TODO: make sure this idea key isn't set yet
                callback = (storeError, success) ->
                    if storeError?
                        response.error = storeError
                        response.result = null
                        res.send(response)
                    else
                        generateTags(req.body.tags, ideaNumber)
                        makeSearchable(redisData)
                        addToRecentIdeas(ideaNumber)
                        redisClient.sadd("user:"+redisData.creator+"ideas", redisData.id)
                        response.error = null
                        response.result = '/ideas/' + ideaNumber + '/'
                        res.send(response)

                redisClient.hmset(ideaName, redisData, callback)

        redisClient.incr('ideaCount', incrementCountCallback)

###
Get requests return the idea with the given number
###
app.get '/ideas/:ideaNum([0-9]+)/?', (req, res, next) ->
    accountData = req.session.userInfo
    ideaNum = req.params.ideaNum.toLowerCase()          # TODO: if this is not an idea number then try and find an idea with this name and ask the user which idea they wanted
    allIdeaDataCallback = (err, data) ->
        if err?
            next(err)
        else
            data.layout = false
            teamIDs = []
            teamIDs.push member.id for member in data.team
            data.activeUserIsMember = (accountData.id? and (accountData.id in teamIDs))
            data.maxTeamSize = app.set("maxTeamSize")
            res.render(__dirname + '/views/jade/idea.jade', data)
    allIdeaData(ideaNum, allIdeaDataCallback)


#########################################################################
########################## Account Serving ##############################
#########################################################################

###
Checks the user information to make sure it is somewhat valid
###
checkNewUserInformation = (userInfo) ->
    if (not userInfo?) or (not userInfo.id?)
        return false
    else
        return true
        
checkAuthorized = (accountData) ->
    if accountData?
        if accountData.signedIn == "signedIn" or accountData.signedIn == 1 or accountData.signedIn == "true"
            return true
    return false

###
Check to see if the person trying to connect is known or not.

If they are known and they are signed in then redirect them to the home page

FLOW:
---------------------
post -> existsCallback (check the user exists) -> allUserData
                                               -> createAccountCallback
###

app.post '/account/recognize/?', (req, res, next) ->
    userInfo = req.body.userInfo
    id = userInfo.id.toString()
    userKey = 'user:' + id
    response = {}
    logger.log(req, "Checking new user information")
    if not checkNewUserInformation(userInfo)
        response.error = "Bad User Information"
        response.result = false
        logger.log(req, "User inforamtions is no good!: " + JSON.stringify(userInfo))
        res.send response
    else
        existsCallback = (err, exists) ->
            if err?
                logger.log(req, "Error checking user existance: " + userInfo.id.toString())
                response.error = err
                response.result = false
                res.send response
            else if exists
            
                userDataCallback = (userError, userResponse) ->
                    if userError?
                        logger.log(req, "Error getting existing user information: " + userInfo.id.toString())
                        response.error = userError
                        response.result = false
                        res.sent response
                    else if (not userResponse.signedIn)
                        logger.log(req, "User is not signed on: " + userInfo.id.toString())
                        req.session.userInfo = userResponse
                        response.error = null
                        response.result = false
                        res.send response
                    else
                        # update the users information in our database
                        for key, value of userInfo
                            userResponse[key] = value
                        redisClient.hmset(userKey, userResponse)
                        req.session.userInfo = userResponse
                        response.error = null
                        response.result = "signedIn"
                        logger.log(req, "User is signed in: " + userInfo.id.toString())
                        res.send response
                        
                redisClient.hgetall(userKey, userDataCallback)
                
            else
                userInfo.joinDate = new Date().getTime()
                userInfo.signedIn = 0
                userInfo.shareEmail = 0
                userInfo.team = null
                
                createdAccountCallback = (createError, success) ->
                    if createError?
                        logger.log(req, "Error creating user account store: " + userInfo.id.toString())
                        response.error = createError
                        response.result = false
                        res.send response
                    else
                        req.session.userInfo = userInfo
                        response.result = false
                        response.error = null
                        logger.log(req, "User is not signed in and is new: " + userInfo.id.toString())
                        res.send response

                redisClient.hmset(userKey, userInfo, createdAccountCallback)

        redisClient.exists(userKey, existsCallback)

###
Log the user out        
###
app.post '/account/logout/?', (req, res, next) ->
    req.session.userInfo = null
    res.send true

###
Display one's account page

FLOW:
---------------------
post -> existsCallback -> accountInfoCallback -> accountIdeasCallback -> ideaInfoCallback

###
app.get '/account/:id([0-9]+)/?', (req, res, next) ->
    accountData = req.session.userInfo
    if not checkAuthorized(accountData) # just checks to see if the user is signed in
        res.render(__dirname + '/views/jade/notAllowed.jade', {layout: false})
    else
        userID = accountData.id
        key = 'user:' + userID
        existsCallback = (existsError, exists) ->       # make sure the requested user exists
            if existsError?
                next existsError
            else if not exists
                next "Does not exist!"
            else
                            
                userInfoCallback = (userError, userResult) ->
                    if userError?
                        next userError
                    else
                        locals = 
                            userInfo : userResult
                            layout : false
                        res.render(__dirname+"/views/jade/account.jade", locals)
                
                allUserData(userID, userInfoCallback)
            
        redisClient.exists(key, existsCallback)
    
#########################################################################
########################## Dealing with Teams ###########################
#########################################################################

###
Adds the user to a team assuming the idea exists and the team is not full.

FLOW
------------------
post -> existsCallback (assures idea exists, assumes user does)
-> setNewTeamCallback (moves the user to the other team using helper function)
###
app.post '/team/join/?', (req, res, next) ->
    ideaNumber = req.body.idea
    accountData = req.session.userInfo
    userID = accountData.id
    userKey = "user:" + userID
    ideaKey = "idea:" + ideaNumber
    response = {}
    if not checkAuthorized(accountData)
        response.error = "You are not signed in"
        response.allowed = false
        response.result = null
        res.send response
    else if not ideaNumber?
        response.error = "No Idea Selected"
        response.allowed = true
        response.result = null
        res.send response
    else
        existsCallback = (existanceError, existanceResult) ->
            if existanceError?
                response.error = existanceError
                response.allowed = true
                response.result = null
                res.send response
            else if not existanceResult
                response.error = "Idea does not exist"
                response.allowed = true
                response.result = null
                res.send response
            else
                setNewTeamCallback = (newTeamError, newTeamResult) ->
                    if newTeamError?
                        response.error = newTeamError
                        response.allowed = true
                        response.result = null
                        res.send response
                    else
                        response.error = null
                        response.allowed = true
                        response.result = accountData
                        req.session.userInfo.team = ideaNumber
                        res.send response
                addUserToTeam(userID, ideaNumber, setNewTeamCallback)
                
        redisClient.exists(ideaKey, existsCallback)
        
###
Removes the user from the team he is part of.
###
app.post '/team/leave/?', (req, res, next) ->
    accountData = req.session.userInfo
    userID = accountData.id
    response = {}
    if not checkAuthorized(accountData)
        response.error = "You must be signed in to leave a team"
        response.allowed = false
        response.result = null
        res.send(response)
    else
        removeUserFromTeam userID, (error, result) ->
            if error?
                response.error = error
                response.allowed = true
                response.result = null
                res.send response
            else
                response.error = error
                response.result = accountData
                response.allowed = true
                req.session.userInfo.team = null
                res.send response
        

#########################################################################
############################ Tag Searching ##############################
#########################################################################


###
Find ideas matching specific tags

FLOW:
---------------------
get -> sinterCallback -> allIdeasCallback
###

app.get '/ideas/search/tags/:tags/?', (req, res, next) ->
    tagsArray = ['tag:'+tag for tag in req.params.tags.split('-')]
    response = {}
    sinterCallback = (interError, matches) ->
        if interError
            response.error = interError
            response.result = null
            res.sent response
        else if matches
            allIdeasCallback = (err, ideas) ->
                if err
                    response.error = err
                    response.result = null
                    res.send response
                else        # render the page using the information on the ideas that matched
                    ideas = shortenIdeaDescriptions ideas
                    jadeLocals = {layout:false, ideas:ideas, tags:req.params.tags.replace('-', ' ')}
                    jadeFile = __dirname + "/views/jade/ajax/searchResults.jade"
                    res.render(jadeFile, jadeLocals)
                    # compileJadeCallback = (jadeError, jadeResult) ->
                    #     if jadeError?
                    #         response.result = null
                    #         response.error = err
                    #         res.send response
                    #     else
                    #         response.result = jadeResult
                    #         response.error = null
                    #         res.send response
                    # 
                    # compileJade(jadeFile, jadeLocals, compileJadeCallback)
        
            multi = redisClient.multi()
            for num in matches
                multi.hgetall("idea:"+num)            
            multi.exec allIdeasCallback
    
    redisClient.sinter tagsArray, sinterCallback


#########################################################################
########################## Comment Serving ##############################
#########################################################################


app.post '/ideas/comments/create/?', (req, res, next) ->
    response = {}
    accountData = req.session.userInfo
    if (not accountData?) or (not accountData.id?)
        response.result  = null
        response.error = "You must sign in to post a comment"
        res.send response
    if (not req.body.title?) or (not req.body.message?) or (not req.body.idea?)
        response.result = null
        response.error = "Bad Comment Information"
        res.send response
    else
        ideaName = 'idea:'+req.body.idea
        
        incrementCallback = (incrementError, result) ->
            if incrementError?
                response.result = null
                response.error = incrementError
                res.send response
            else
                commentName = ideaName + 'comment:' + result
                currentTime = new Date().getTime()
                redisData =
                    title : req.body.title
                    message : req.body.message
                    creator : accountData.id
                    idea : req.body.idea
                    date : currentTime
                    upvotes : 0
                    downvotes : 0
                    includevotes : 0
                setCommentError = (setCommentError, success) ->
                    if setCommentError
                        response.error = setCommentError
                        response.result = null
                        res.send response
                    else
                        creatorInfo = 
                            name : accountData.name
                        commentData = 
                            title : req.body.title
                            message : req.body.message.split(/\r\n|\n/)
                            creator : creatorInfo
                        jadeLocals = {layout:false, comment:commentData}
                        jadeFile = __dirname + "/views/jade/ajax/comment.jade"
                        res.render(jadeFile, jadeLocals)
                        # compileCallback = (compileError, compileResult) ->
                        #     if compileError?
                        #         response.error = compileError
                        #         response.result = null
                        #         res.send response
                        #     else
                        #         response.result = compileResult
                        #         response.error = null
                        #         res.send response
                        # 
                        # compileJade(jadeFile, jadeLocals, compileCallback)
                redisClient.hmset(commentName, redisData, setCommentError)
                        
        redisClient.hincrby(ideaName, 'comments', 1, incrementCallback)
                      
                    
    
#########################################################################
######################## Post Helper Functions ##########################
#########################################################################

###
Add the given user to the given project. This first removes the user from
any team he is already on.

Next it adds the user to the new team and increments that teams count by one.

If the second team already had the maximum number of people or the idea or user
did not exist then an error is returned to the callback.

Callback must take (error, success) where success is true or false

FLOW
---------------------
addUserToTeam  -> hasSpaceCallback (checks to make sure the team has space)
-> removeCallback (removes user from team) -> multiCallback (add user to team, 
increment team count, add team to user fields)
###
addUserToTeam = (userID, ideaID, callback) ->
    userKey = "user:" + userID
    ideaKey = "idea:" + ideaID
    teamKey = ideaKey + "team"
    hasSpaceCallback = (spaceError, spaceResult) ->
        if spaceError?
            callback spaceError, false
        else if spaceResult >= app.set("maxTeamSize")
            callback "This team already has the maximum number of members.", false
        else
            removeCallback = (removeError, removeResult) ->
                if removeError?
                    callback removeError, false
                else if not removeResult
                    callback "Failed to remove user from existing team", false
                else
                    multiCallback = (multiError, multiResult) ->
                        if multiError?
                            callback(multiError, false)
                        else
                            callback(null, true)
        
                    multi = redisClient.multi()
                    multi.sadd(teamKey, userID)
                    multi.hincrby(ideaKey, "team", 1)
                    multi.hset(userKey, "team", ideaID)
                    multi.exec(multiCallback)
            
            removeUserFromTeam(userID, removeCallback)
            
    redisClient.hget(ideaKey, "team", hasSpaceCallback)
    
###
Removes the given user from the team he is on, deincrements the team count
for that idea by one, and clears the user's team field.

If the user or idea did not exist or any redis call threw and error and error
is returned to the callback

Callback must take (error, success) where success is true or false.

FLOW
---------------------
removeUserFromTeam -> getTeamCallback -> multiCallback (remove user from team,
deincrement team count, delete team from user)
###    
removeUserFromTeam = (userID, callback) ->
    userKey = "user:" + userID
    getTeamCallback = (teamError, teamResult) ->
        if teamError?
            callback teamError, false
        else
            multiCallback = (multiError, multiResults) ->
                if multiError?
                    callback multiError, false
                else
                    callback null, true
            
            ideaKey = "idea:" + teamResult
            teamKey = ideaKey + "team"
            
            multi = redisClient.multi()
            multi.srem(teamKey, userID)
            multi.hincrby(ideaKey, "team", -1)
            multi.hset(userKey, "team", null)
            multi.exec(multiCallback)
                
    redisClient.hget(userKey, "team", getTeamCallback)

###
Include idea number in tag sets from a space-seperated list or array of words
to a certain idea
###
generateTags = (tagsArray, idea) ->     
    multi = redisClient.multi()
    allTagsKey = app.set('tagsKey')
    
    for tag in tagsArray
        tagKey = 'tag:'+tag
        multi.sadd(allTagsKey, tagKey)          # add each tag to the list of all used tags
        multi.sadd(tagKey, idea)            # add the idea number to each tag set
        
    multi.exec (multiError, replies) ->
        if multiError
            logger.log(null, "Error tagging post: " +JSON.stringify(multiError))


###
Include idea number in the set for each word it contains to allow for search by any keyword
###
makeSearchable = (ideaData) ->
    allWordsKey = app.set('wordsKey')
    allWords = ideaData.title.toLowerCase().split(/[^a-z0-9]/)
    allWords.concat(ideaData.description.toLowerCase().split(/[^a-z0-9]/))
    
    multi = redisClient.multi()
    
    for word in allWords
        wordKey = 'word:'+word
        multi.sadd(allWordsKey, wordKey)
        multi.sadd(wordKey, ideaData.id)
    
    multi.exec (multiError, replies) ->
        if multiError
            logger.log(null, "Error making post searchable: "+JSON.stringify(multiError))

###
push this idea on to the top of the list of recent ideas         
###
addToRecentIdeas = (ideaNumber) ->
    key = app.set("recentIdeasKey")
    pushCallback = (pushError, pushResult) ->
        if pushError? or (not pushResult)
            logger.log(null, "Failed to add idea number " + ideaNumber + " to recent ideas")
    redisClient.lpush(key, ideaNumber, pushCallback)

#########################################################################
######################## Get Helper Functions ###########################
#########################################################################

###
Gets all the information on a certian user that is known to exist in the system.
This method DOES NOT check for existance before calling

###

allUserData = (userID, callback) ->
    userKey = "user:" + userID
    userIdeaKey = userKey + "ideas"
    userData = {}
    getUserInfoCallback = (userErr, userResult) ->
        if userErr
            callback userErr, null
        else
            userData = userResult
            
            if userData.team?
                ideaKey = "idea:" + userData.team
                
                getIdeaInfoCallback = (ideaError, ideaResult) ->
                    if ideaError?
                        callback ideaError, null
                    else
                        userData.team = ideaResult
                        
                        userIdeasCallback = (userIdeasError, userIdeasResult) ->
                            if userIdeasError?
                                callback userIdeasError, null
                            else
                            
                                multiCallback = (multiError, multiResult) ->
                                    if multiError?
                                        callback multiError, null
                                    else
                                        userData.ideas = multiResult
                                        callback null, userData
                                        
                                multi = redisClient.multi()
                                for idea in userIdeasResult
                                    ideaKey = "idea:" + idea
                                    multi.hgetall ideaKey
                                multi.exec(multiCallback)
                                
                        redisClient.smembers(userIdeaKey, userIdeasCallback)
                
                redisClient.hgetall(ideaKey, getIdeaInfoCallback)
            
    redisClient.hgetall(userKey, getUserInfoCallback)

###
Retrieves and returns all the information on the team of the given idea. This
method DOES NOT check for the existance of an idea before calling.

callback should take (error, result) where result is the array of members in the
requested team
###
allTeamData = (ideaID, callback) ->
    teamKey = "idea:" + ideaID + "team"
    
    teamInfoCallback = (teamError, teamResult) ->
        if teamError?
            callback teamError, null
        else if teamResult.length == 0
            callback null,[]
        else
            multiCallback = (multiError, multiResult) ->
                if multError?
                    callback multiError, null
                else
                    callback null, multiResult
        
            multi = redisClient.multi()
            for userID in teamResult
                userKey = "user:" + userID
                multi.hgetall userKey
            multi.exec multiCallback
                                            
    redisClient.smembers teamKey, teamInfoCallback



###
Gathers all the data on a given idea, including full info on the creator, team,
and comments, with all text conveniently divided into paragraphs.

callback must take (error, data)

FLOW:
---------------------
allIdeaData -> existsCallback -> ideaDataCallback -> creatorInfoCallback -> allCommentData -> callback
###
allIdeaData = (ideaNumber, callback) ->
    ideaKey = "idea:" + ideaNumber
    existsCallback = (err, exists) ->
        if err
            callback err, null
        else if not exists
            callback new NotFound('No one has thought up that idea yet.'), null     # TODO: have a solid 404 page when someone requests and idea that does not exist###
        else
        
            ideaDataCallback = (err, ideaInfo) ->
                if err
                    callback err, null
                else
                    numberOfComments = ideaInfo.comments
                    ideaInfo.description = ideaInfo.description.split(/\r\n|\n/)        # split the idea description into paragraphs
                    
                    creatorInfoCallback = (err, creatorInfo) ->
                        if err
                            callback err, null
                        else
                            ideaInfo.creator = creatorInfo
                            
                            commentInfoCallback = (err, commentData) ->
                                if err
                                    callback err, null
                                else
                                    ideaInfo.comments = commentData
                                    teamKey = ideaKey + "team"
                                    
                                    teamCallback = (teamError, teamResult) ->
                                        if teamError?
                                            callback teamError, null
                                        else
                                            ideaInfo.team = teamResult
                                            callback null, ideaInfo
                                            
                                    allTeamData ideaNumber, teamCallback
                        
                            allCommentData ideaInfo, commentInfoCallback
                    
                    redisClient.hgetall "user:"+ ideaInfo.creator, creatorInfoCallback          # retrieve the information on the creator of this particular idea
                            
            redisClient.hgetall ideaKey, ideaDataCallback       # if the key does exist then retrieve all the information about it
                        
    redisClient.exists ideaKey, existsCallback          # Check that the key exists.
                    
###
Gathers all the comment data for the idea in question and passes to callback (error, data)
where data is a dictionary of the relevant information on the idea

FLOW:
---------------------
allCommentData -> commentDataCallback -> commentCreatorCallback -> callback

###
allCommentData = (ideaData, callback) ->
    numberOfComments = ideaData.comments
    key = "idea:"+ideaData.id
    
    multi = redisClient.multi()
    for n in [1...(+numberOfComments+1)]            # retrieve all comments. They are stored as idea:(ideaNumber)comment:(commentNumber)
        multi.hgetall key+'comment:'+n              # TODO: make the comment count start at 0 like any normal list###

    
    commentDataCallback = (err, comments) ->
        if err
            callback err, null
        else
            
            multi = redisClient.multi()
            for comment in comments
                comment.message = comment.message.split(/\r\n|\n/)          # split all comments into paragraphs
                multi.hgetall "user:" + comment.creator         # retrieve information of the creator of the comments

            commentCreatorCallback = (err, creators) ->
                for n in [0...(+comments.length)]
                    comments[n].creator = creators[n]           # store all the creator information in the comments
                
                callback null, comments
        
            multi.exec commentCreatorCallback
            
    multi.exec commentDataCallback
    
###
Retrieves the list of recent ideas and populates it with a maximum of 25 items

callback should take (error, result) where result is a list of the recent idea
dictionaries.
###
allRecentIdeas = (callback) ->
    key = app.set("recentIdeasKey")

    rangeCallback = (rangeError, rangeResult) ->
        if rangeError?
            callback(rangeError, null)
        else if rangeResult.length > 0
            multiCallback = (multiError, multiResult) ->
                if multiError?
                    callback(multiError, null)
                else
                    ideas = shortenIdeaDescriptions(multiResult)
                    callback(null, ideas)
                    
            multi = redisClient.multi()
            for id in rangeResult
                ideaKey = "idea:" + id.toString()
                multi.hgetall(ideaKey)
            multi.exec(multiCallback)
            
        else
            callback(null, [])
            
    redisClient.lrange(key, 0, 25, rangeCallback)
    
###
Shorten the descriptions in the given ideas and return the modified ideas
###
shortenIdeaDescriptions = (ideas) ->
    for idea in ideas
        desc = idea.description
        maxLength = app.set("maxDescriptionLength")
        if desc.length > maxLength
            idea.description = desc.substring(0, maxLength)+"..."
    return ideas
    
    
###
Return the HTML that results from compileing the given file with the given options    
###
compileJade = (jadeFile, jadeLocals, jadeCallback) ->
    readCallback = (readError, contents) ->
        if readError?
            jadeCallback(readError, null)
        else
            renderer = jade.compile(contents, {filename: jadeFile})
            jadeCallback(null, renderer(jadeLocals))
    fs.read(jadeFile, readCallback)

    


#########################################################################
######### EVERYTHING BELOW HERE IS NOT YET USED ON THE WEBPAGE ##########
#########################################################################





#########################################################################
############################### Voting ##################################
#########################################################################

app.put('/ideas/upvote/?', (req, res, next) ->
    ideaName = 'idea:'+req.body.idea
    redisClient.hincrby(ideaName, 'upvotes', 1, (err, result) ->
        if err
            next(err)
        else
            res.sent("Success", 201)
        )
    )
    
app.put('/ideas/downvote/?', (req, res, next) ->
    ideaName = 'idea:'+req.body.idea
    redisClient.hincrby(ideaName, 'downvotes', 1, (err, result) ->
        if err
            next(err)
        else
            res.sent("Success", 201)
        )
    )
    
app.put('/ideas/comments/upvote/?', (req, res, next) ->
    ideaName = 'idea:'+req.body.idea+'comment:'+req.body.comment
    redisClient.hincrby(ideaName, 'upvotes', 1, (err, result) ->
        if err
            next(err)
        else
            res.sent("Success", 201)
        )
    )
    
app.put('/ideas/comments/downvote/?', (req, res, next) ->
    ideaName = 'idea:'+req.body.idea+'comment:'+req.body.comment
    redisClient.hincrby(ideaName, 'downvotes', 1, (err, result) ->
        if err
            next(err)
        else
            res.sent("Success", 201)
        )
    )

app.put('/ideas/comments/includevote/?', (req, res, next) ->
    ideaName = 'idea:'+req.body.idea+'comment:'+req.body.comment
    redisClient.hincrby(ideaName, 'includevotes', 1, (err, result) ->
        if err
            next(err)
        else
            res.sent("Success", 201)
        )
    )