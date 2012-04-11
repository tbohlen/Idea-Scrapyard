
/*
TODO: Implement errors!
TODO: Unify variable names: accountInfo, accountData, userInfo, etc.
TODO: Do not attach all the idea information to the accountdata
*/

(function() {
  var addToRecentIdeas, addUserToTeam, allCommentData, allIdeaData, allRecentIdeas, allTeamData, allUserData, app, bootstrap, checkAuthorized, checkNewUserInformation, coffee, compileJade, dotcloudEnv, express, fs, generateTags, http, jade, logger, makeSearchable, path, qs, redis, redisClient, redisStore, removeUserFromTeam, sessionKey, sessionSecret, shortenIdeaDescriptions, stylus, url,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  http = require('http');

  url = require('url');

  qs = require('querystring');

  fs = require('fs');

  path = require('path');

  redis = require('redis');

  express = require('express');

  redisStore = require('connect-redis')(express);

  jade = require('jade');

  stylus = require('stylus');

  bootstrap = require('./assets/bootstrap/index.js');

  coffee = require("express-coffee");

  logger = require("./logger.js");

  /*
  for running on the dotcloud server
  */

  dotcloudEnv = JSON.parse(fs.readFileSync('/home/dotcloud/environment.json', 'utf-8'));

  redisClient = redis.createClient(dotcloudEnv.DOTCLOUD_DATA_REDIS_PORT, dotcloudEnv.DOTCLOUD_DATA_REDIS_HOST);

  redisClient.auth(dotcloudEnv.DOTCLOUD_DATA_REDIS_PASSWORD, function(result) {
    return logger.log(null, "Redis auth result: " + result);
  });

  /*
  for testing locally
  */

  sessionKey = "scrapyard-key";

  sessionSecret = "hitherehackers";

  redisClient.on("error", function(err) {
    return logger.log(null, "Redis connection error to " + redisClient.host + ":" + redisClient.port + " - " + err);
  });

  redisClient.setnx('ideaCoufnt', 0);

  redisClient.setnx('commentCount', 0);

  app = express.createServer();

  app.listen(8080);

  /*
  TODO: de-spaghettiafy
  */

  app.configure(function() {
    var coffeeOptions, logStream, redisStoreOptions, stylusOptions;
    app.set('view engine', 'jade');
    app.set('tagsKey', 'allTags');
    app.set('wordsKey', 'allWords');
    app.set('ideasKey', 'allIdeas');
    app.set('recentIdeasKey', 'recentIdeas');
    app.set('maxDescriptionLength', 210);
    app.set('maxTeamSize', 4);
    stylusOptions = {
      src: __dirname + '/assets/stylus/',
      dest: __dirname + '/assets/',
      compile: function(str, path) {
        return stylus(str).use(bootstrap()).set('filename', path).set('warn', true).set('compress', true);
      }
    };
    coffeeOptions = {
      path: __dirname + '/assets/',
      live: false,
      uglify: false
    };
    redisStoreOptions = {
      client: redisClient
    };
    path = "log";
    logStream = fs.createWriteStream(path, {
      'flags': 'a+',
      'encoding': 'utf8',
      'mode': 0666
    });
    app.use(stylus.middleware(stylusOptions));
    app.use(coffee(coffeeOptions));
    app.use(express.logger({
      format: "default",
      stream: logStream,
      format: ':method :url'
    }));
    app.use(express.methodOverride());
    app.use(express.bodyParser());
    app.use(express.cookieParser({
      secret: sessionSecret
    }));
    app.use(express.session({
      key: sessionKey,
      secret: sessionSecret,
      store: new redisStore(redisStoreOptions)
    }));
    app.use(app.router);
    app.use(express.static(__dirname + '/assets/', {
      maxAge: 31557600000
    }));
    return app.use(function(err, req, res, next) {
      return res.render(__dirname + "/views/jade/error.jade", {
        layout: false,
        error: err
      });
    });
  });

  app.get("/?", function(req, res, next) {
    return res.render(__dirname + "/views/jade/index.jade", {
      layout: false
    });
  });

  app.get("/ideas/test/?", function(req, res, next) {
    return res.render(__dirname + "/views/jade/idea.jade", {
      layout: false,
      title: "Test Title",
      description: ["Test Description", "Blah Blah Blah"],
      comments: [],
      creator: "Turner Bohlen"
    });
  });

  app.get("/ideas/howMany/?", function(req, res, next) {
    return redisClient.get('ideaCount', function(err, result) {
      return res.send(result);
    });
  });

  app.get("/notAllowed/?", function(req, res, next) {
    return res.render(__dirname + "/views/jade/notAllowed.jade", {
      layout: false
    });
  });

  app.get("/contact/?", function(req, res, next) {
    return res.render(__dirname + "/views/jade/contact.jade", {
      layout: false
    });
  });

  app.get("/home/?", function(req, res, next) {
    var accountData, allUserDataCallback;
    accountData = req.session.userInfo;
    if (!checkAuthorized(accountData)) {
      logger.log(req, "User is not authorized. Redirecting to landing page.");
      return res.redirect("/landing/");
    } else {
      allUserDataCallback = function(userError, userResult) {
        var recentIdeasCallback;
        if ((userError != null) || (!(userResult != null))) {
          logger.log(req, "GET /home/ ERROR: No data recieved about user.");
          return next(userError);
        } else {
          recentIdeasCallback = function(ideasError, ideasResult) {
            var locals;
            if (ideasError != null) ideasResult = [];
            if (!(userResult.email != null)) userResult.email = "none";
            if (userResult.email == null) userResult.email = "none";
            locals = {
              layout: false,
              userInfo: userResult,
              recentIdeas: ideasResult
            };
            return res.render(__dirname + "/views/jade/home.jade", locals);
          };
          return allRecentIdeas(recentIdeasCallback);
        }
      };
      return allUserData(accountData.id, allUserDataCallback);
    }
  });

  app.get("/landing/?", function(req, res, next) {
    return res.render(__dirname + "/views/jade/landing.jade", {
      layout: false
    });
  });

  app.get("/about/?", function(req, res, next) {
    var accountData, locals;
    accountData = req.session.userInfo;
    if (accountData.id && accountData.signedIn) {
      locals = {
        userInfo: accountData,
        layout: false
      };
      return res.render(__dirname + "/views/jade/newVisitor.jade", locals);
    } else {
      return res.redirect("/landing/");
    }
  });

  app.get("/newVisitor/?", function(req, res, next) {
    var accountData, locals;
    accountData = req.session.userInfo;
    if (checkAuthorized(accountData)) {
      locals = {
        userInfo: accountData,
        layout: false
      };
      return res.render(__dirname + "/views/jade/newVisitor.jade", locals);
    } else {
      return res.redirect("/landing/");
    }
  });

  app.get("/suggested-projects/mozillaWatchdog/?", function(req, res, next) {
    var accountData;
    accountData = req.session.userInfo;
    if (checkAuthorized(accountData)) {
      return res.render(__dirname + "/views/jade/suggested-projects/mozillaWatchdog.jade", {
        layout: false
      });
    } else {
      return res.redirect("/landing/");
    }
  });

  app.get("/suggested-projects/mozillaPersona/?", function(req, res, next) {
    var accountData;
    accountData = req.session.userInfo;
    if (checkAuthorized(accountData)) {
      return res.render(__dirname + "/views/jade/suggested-projects/mozillaPersona.jade", {
        layout: false
      });
    } else {
      return res.redirect("/landing/");
    }
  });

  app.post('/password/?', function(req, res, next) {
    var accountData, key, response, setSignedInCallback;
    accountData = req.session.userInfo;
    response = {};
    if ((!(accountData != null)) || (!(accountData.first_name != null)) || (!(accountData.id != null))) {
      response.result = false;
      response.error = "We do not have the necessary information from Facebook to log you in.";
      return res.send(response);
    } else if (req.body.password === accountData.first_name.toString().toLowerCase() + '-hack') {
      key = 'user:' + accountData.id.toString();
      setSignedInCallback = function(signInErr, signInResponse) {
        if (signInErr != null) {
          response.result = false;
          response.error = signInErr;
          return res.send(response);
        } else {
          req.session.userInfo.signedIn = 1;
          response.result = "/newVisitor/";
          response.error = null;
          return res.send(response);
        }
      };
      return redisClient.hset(key, 'signedIn', true, setSignedInCallback);
    } else {
      response.error = "Incorrect password";
      response.badPassword = true;
      response.result = false;
      return res.send(response);
    }
  });

  app.post('/account/emailPermission/?', function(req, res, next) {
    var accountData, newSetting, newSettingCallback, response, userKey;
    accountData = req.session.userInfo;
    newSetting = req.body.newSetting;
    response = {};
    if (!checkAuthorized(accountData)) {
      response.allowed = false;
      response.error = "Not allowed";
      response.result = null;
      return res.send(response);
    } else {
      userKey = "user:" + accountData.id;
      newSettingCallback = function(error, result) {
        if (error != null) {
          response.error = error;
          response.allowed = true;
          response.result = null;
          return res.send(response);
        } else {
          response.error = null;
          response.allowed = true;
          response.result = true;
          req.session.userInfo.shareEmail = newSetting;
          return res.send(response);
        }
      };
      return redisClient.hset(userKey, "shareEmail", newSetting, newSettingCallback);
    }
  });

  app.get('/ideas/new/?', function(req, res, next) {
    var accountData;
    accountData = req.session.userInfo;
    if (!checkAuthorized(accountData)) {
      return res.render(__dirname + '/views/jade/notAllowed.jade', {
        layout: false
      });
    } else {
      return res.render(__dirname + '/views/jade/newIdea.jade', {
        layout: false
      });
    }
  });

  app.get('/ideas/search/?', function(req, res, next) {
    return res.render(__dirname + '/views/jade/search.jade', {
      layout: false,
      results: [],
      tags: []
    });
  });

  /*
  posts to ideas/create builds new idea entries in the database
  */

  app.post('/ideas/create/?', function(req, res, next) {
    var accountData, incrementCountCallback, response;
    accountData = req.session.userInfo;
    response = {};
    if (!checkAuthorized(accountData)) {
      return res.render(__dirname + '/views/jade/notAllowed.jade', {
        layout: false
      });
    } else {
      incrementCountCallback = function(countError, ideaNumber) {
        var callback, currentTime, ideaName, redisData;
        if (countError != null) {
          response.error = countError;
          response.result = null;
          return res.send(response);
        } else {
          ideaName = "idea:" + ideaNumber;
          currentTime = new Date().getTime();
          redisData = {
            title: req.body.title,
            id: ideaNumber,
            description: req.body.description,
            creator: accountData.id,
            tags: req.body.tags,
            date: currentTime,
            upvotes: 0,
            downvotes: 0,
            comments: 0,
            contributors: 0
          };
          callback = function(storeError, success) {
            if (storeError != null) {
              response.error = storeError;
              response.result = null;
              return res.send(response);
            } else {
              generateTags(req.body.tags, ideaNumber);
              makeSearchable(redisData);
              addToRecentIdeas(ideaNumber);
              redisClient.sadd("user:" + redisData.creator + "ideas", redisData.id);
              response.error = null;
              response.result = '/ideas/' + ideaNumber + '/';
              return res.send(response);
            }
          };
          return redisClient.hmset(ideaName, redisData, callback);
        }
      };
      return redisClient.incr('ideaCount', incrementCountCallback);
    }
  });

  /*
  Get requests return the idea with the given number
  */

  app.get('/ideas/:ideaNum([0-9]+)/?', function(req, res, next) {
    var accountData, allIdeaDataCallback, ideaNum;
    accountData = req.session.userInfo;
    ideaNum = req.params.ideaNum.toLowerCase();
    allIdeaDataCallback = function(err, data) {
      var member, teamIDs, _i, _len, _ref, _ref2;
      if (err != null) {
        return next(err);
      } else {
        data.layout = false;
        teamIDs = [];
        _ref = data.team;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          member = _ref[_i];
          teamIDs.push(member.id);
        }
        data.activeUserIsMember = (accountData.id != null) && (_ref2 = accountData.id, __indexOf.call(teamIDs, _ref2) >= 0);
        data.maxTeamSize = app.set("maxTeamSize");
        return res.render(__dirname + '/views/jade/idea.jade', data);
      }
    };
    return allIdeaData(ideaNum, allIdeaDataCallback);
  });

  /*
  Checks the user information to make sure it is somewhat valid
  */

  checkNewUserInformation = function(userInfo) {
    if ((!(userInfo != null)) || (!(userInfo.id != null))) {
      return false;
    } else {
      return true;
    }
  };

  checkAuthorized = function(accountData) {
    logger.log(null, "checking authorization of " + JSON.stringify(accountData));
    if (accountData != null) {
      if (accountData.signedIn === "signedIn" || accountData.signedIn === 1 || accountData.signedIn === "true") {
        return true;
      }
    }
    return false;
  };

  /*
  Check to see if the person trying to connect is known or not.
  
  If they are known and they are signed in then redirect them to the home page
  
  FLOW:
  ---------------------
  post -> existsCallback (check the user exists) -> allUserData
                                                 -> createAccountCallback
  */

  app.post('/account/recognize/?', function(req, res, next) {
    var existsCallback, id, response, userInfo, userKey;
    userInfo = req.body.userInfo;
    id = userInfo.id.toString();
    userKey = 'user:' + id;
    response = {};
    logger.log(req, "Checking new user information");
    if (!checkNewUserInformation(userInfo)) {
      response.error = "Bad User Information";
      response.result = false;
      logger.log(req, "User inforamtions is no good!: " + JSON.stringify(userInfo));
      return res.send(response);
    } else {
      existsCallback = function(err, exists) {
        var createdAccountCallback, userDataCallback;
        if (err != null) {
          logger.log(req, "Error checking user existance: " + userInfo.id.toString());
          response.error = err;
          response.result = false;
          return res.send(response);
        } else if (exists) {
          userDataCallback = function(userError, userResponse) {
            var key, value;
            if (userError != null) {
              logger.log(req, "Error getting existing user information: " + userInfo.id.toString());
              response.error = userError;
              response.result = false;
              return res.sent(response);
            } else if (!checkAuthorized(userResponse)) {
              logger.log(req, "User is not signed on: " + userInfo.id.toString());
              req.session.userInfo = userResponse;
              response.error = null;
              response.result = false;
              return res.send(response);
            } else {
              for (key in userInfo) {
                value = userInfo[key];
                userResponse[key] = value;
              }
              redisClient.hmset(userKey, userResponse);
              req.session.userInfo = userResponse;
              response.error = null;
              response.result = "signedIn";
              logger.log(req, "User is signed in: " + userInfo.id.toString());
              return res.send(response);
            }
          };
          return redisClient.hgetall(userKey, userDataCallback);
        } else {
          userInfo.joinDate = new Date().getTime();
          userInfo.signedIn = 0;
          userInfo.shareEmail = 0;
          userInfo.team = null;
          createdAccountCallback = function(createError, success) {
            if (createError != null) {
              logger.log(req, "Error creating user account store: " + userInfo.id.toString());
              response.error = createError;
              response.result = false;
              return res.send(response);
            } else {
              req.session.userInfo = userInfo;
              response.result = false;
              response.error = null;
              logger.log(req, "User is not signed in and is new: " + userInfo.id.toString());
              return res.send(response);
            }
          };
          return redisClient.hmset(userKey, userInfo, createdAccountCallback);
        }
      };
      return redisClient.exists(userKey, existsCallback);
    }
  });

  /*
  Log the user out
  */

  app.post('/account/logout/?', function(req, res, next) {
    req.session.userInfo = null;
    return res.send(true);
  });

  /*
  Display one's account page
  
  FLOW:
  ---------------------
  post -> existsCallback -> accountInfoCallback -> accountIdeasCallback -> ideaInfoCallback
  */

  app.get('/account/:id([0-9]+)/?', function(req, res, next) {
    var accountData, existsCallback, key, userID;
    accountData = req.session.userInfo;
    if (!checkAuthorized(accountData)) {
      return res.render(__dirname + '/views/jade/notAllowed.jade', {
        layout: false
      });
    } else {
      userID = accountData.id;
      key = 'user:' + userID;
      existsCallback = function(existsError, exists) {
        var userInfoCallback;
        if (existsError != null) {
          return next(existsError);
        } else if (!exists) {
          return next("Does not exist!");
        } else {
          userInfoCallback = function(userError, userResult) {
            var locals;
            if (userError != null) {
              return next(userError);
            } else {
              locals = {
                userInfo: userResult,
                layout: false
              };
              return res.render(__dirname + "/views/jade/account.jade", locals);
            }
          };
          return allUserData(userID, userInfoCallback);
        }
      };
      return redisClient.exists(key, existsCallback);
    }
  });

  /*
  Adds the user to a team assuming the idea exists and the team is not full.
  
  FLOW
  ------------------
  post -> existsCallback (assures idea exists, assumes user does)
  -> setNewTeamCallback (moves the user to the other team using helper function)
  */

  app.post('/team/join/?', function(req, res, next) {
    var accountData, existsCallback, ideaKey, ideaNumber, response, userID, userKey;
    ideaNumber = req.body.idea;
    accountData = req.session.userInfo;
    userID = accountData.id;
    userKey = "user:" + userID;
    ideaKey = "idea:" + ideaNumber;
    response = {};
    if (!checkAuthorized(accountData)) {
      response.error = "You are not signed in";
      response.allowed = false;
      response.result = null;
      return res.send(response);
    } else if (!(ideaNumber != null)) {
      response.error = "No Idea Selected";
      response.allowed = true;
      response.result = null;
      return res.send(response);
    } else {
      existsCallback = function(existanceError, existanceResult) {
        var setNewTeamCallback;
        if (existanceError != null) {
          response.error = existanceError;
          response.allowed = true;
          response.result = null;
          return res.send(response);
        } else if (!existanceResult) {
          response.error = "Idea does not exist";
          response.allowed = true;
          response.result = null;
          return res.send(response);
        } else {
          setNewTeamCallback = function(newTeamError, newTeamResult) {
            if (newTeamError != null) {
              response.error = newTeamError;
              response.allowed = true;
              response.result = null;
              return res.send(response);
            } else {
              response.error = null;
              response.allowed = true;
              response.result = accountData;
              req.session.userInfo.team = ideaNumber;
              return res.send(response);
            }
          };
          return addUserToTeam(userID, ideaNumber, setNewTeamCallback);
        }
      };
      return redisClient.exists(ideaKey, existsCallback);
    }
  });

  /*
  Removes the user from the team he is part of.
  */

  app.post('/team/leave/?', function(req, res, next) {
    var accountData, response, userID;
    accountData = req.session.userInfo;
    userID = accountData.id;
    response = {};
    if (!checkAuthorized(accountData)) {
      response.error = "You must be signed in to leave a team";
      response.allowed = false;
      response.result = null;
      return res.send(response);
    } else {
      return removeUserFromTeam(userID, function(error, result) {
        if (error != null) {
          response.error = error;
          response.allowed = true;
          response.result = null;
          return res.send(response);
        } else {
          response.error = error;
          response.result = accountData;
          response.allowed = true;
          req.session.userInfo.team = null;
          return res.send(response);
        }
      });
    }
  });

  /*
  Find ideas matching specific tags
  
  FLOW:
  ---------------------
  get -> sinterCallback -> allIdeasCallback
  */

  app.get('/ideas/search/tags/:tags/?', function(req, res, next) {
    var response, sinterCallback, tag, tagsArray;
    tagsArray = [
      (function() {
        var _i, _len, _ref, _results;
        _ref = req.params.tags.split('-');
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          tag = _ref[_i];
          _results.push('tag:' + tag);
        }
        return _results;
      })()
    ];
    response = {};
    sinterCallback = function(interError, matches) {
      var allIdeasCallback, multi, num, _i, _len;
      if (interError) {
        response.error = interError;
        response.result = null;
        return res.sent(response);
      } else if (matches) {
        allIdeasCallback = function(err, ideas) {
          var jadeFile, jadeLocals;
          if (err) {
            response.error = err;
            response.result = null;
            return res.send(response);
          } else {
            ideas = shortenIdeaDescriptions(ideas);
            jadeLocals = {
              layout: false,
              ideas: ideas,
              tags: req.params.tags.replace('-', ' ')
            };
            jadeFile = __dirname + "/views/jade/ajax/searchResults.jade";
            return res.render(jadeFile, jadeLocals);
          }
        };
        multi = redisClient.multi();
        for (_i = 0, _len = matches.length; _i < _len; _i++) {
          num = matches[_i];
          multi.hgetall("idea:" + num);
        }
        return multi.exec(allIdeasCallback);
      }
    };
    return redisClient.sinter(tagsArray, sinterCallback);
  });

  app.post('/ideas/comments/create/?', function(req, res, next) {
    var accountData, ideaName, incrementCallback, response;
    response = {};
    accountData = req.session.userInfo;
    if ((!(accountData != null)) || (!(accountData.id != null))) {
      response.result = null;
      response.error = "You must sign in to post a comment";
      res.send(response);
    }
    if ((!(req.body.title != null)) || (!(req.body.message != null)) || (!(req.body.idea != null))) {
      response.result = null;
      response.error = "Bad Comment Information";
      return res.send(response);
    } else {
      ideaName = 'idea:' + req.body.idea;
      incrementCallback = function(incrementError, result) {
        var commentName, currentTime, redisData, setCommentError;
        if (incrementError != null) {
          response.result = null;
          response.error = incrementError;
          return res.send(response);
        } else {
          commentName = ideaName + 'comment:' + result;
          currentTime = new Date().getTime();
          redisData = {
            title: req.body.title,
            message: req.body.message,
            creator: accountData.id,
            idea: req.body.idea,
            date: currentTime,
            upvotes: 0,
            downvotes: 0,
            includevotes: 0
          };
          setCommentError = function(setCommentError, success) {
            var commentData, creatorInfo, jadeFile, jadeLocals;
            if (setCommentError) {
              response.error = setCommentError;
              response.result = null;
              return res.send(response);
            } else {
              creatorInfo = {
                name: accountData.name
              };
              commentData = {
                title: req.body.title,
                message: req.body.message.split(/\r\n|\n/),
                creator: creatorInfo
              };
              jadeLocals = {
                layout: false,
                comment: commentData
              };
              jadeFile = __dirname + "/views/jade/ajax/comment.jade";
              return res.render(jadeFile, jadeLocals);
            }
          };
          return redisClient.hmset(commentName, redisData, setCommentError);
        }
      };
      return redisClient.hincrby(ideaName, 'comments', 1, incrementCallback);
    }
  });

  /*
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
  */

  addUserToTeam = function(userID, ideaID, callback) {
    var hasSpaceCallback, ideaKey, teamKey, userKey;
    userKey = "user:" + userID;
    ideaKey = "idea:" + ideaID;
    teamKey = ideaKey + "team";
    hasSpaceCallback = function(spaceError, spaceResult) {
      var removeCallback;
      if (spaceError != null) {
        return callback(spaceError, false);
      } else if (spaceResult >= app.set("maxTeamSize")) {
        return callback("This team already has the maximum number of members.", false);
      } else {
        removeCallback = function(removeError, removeResult) {
          var multi, multiCallback;
          if (removeError != null) {
            return callback(removeError, false);
          } else if (!removeResult) {
            return callback("Failed to remove user from existing team", false);
          } else {
            multiCallback = function(multiError, multiResult) {
              if (multiError != null) {
                return callback(multiError, false);
              } else {
                return callback(null, true);
              }
            };
            multi = redisClient.multi();
            multi.sadd(teamKey, userID);
            multi.hincrby(ideaKey, "team", 1);
            multi.hset(userKey, "team", ideaID);
            return multi.exec(multiCallback);
          }
        };
        return removeUserFromTeam(userID, removeCallback);
      }
    };
    return redisClient.hget(ideaKey, "team", hasSpaceCallback);
  };

  /*
  Removes the given user from the team he is on, deincrements the team count
  for that idea by one, and clears the user's team field.
  
  If the user or idea did not exist or any redis call threw and error and error
  is returned to the callback
  
  Callback must take (error, success) where success is true or false.
  
  FLOW
  ---------------------
  removeUserFromTeam -> getTeamCallback -> multiCallback (remove user from team,
  deincrement team count, delete team from user)
  */

  removeUserFromTeam = function(userID, callback) {
    var getTeamCallback, userKey;
    userKey = "user:" + userID;
    getTeamCallback = function(teamError, teamResult) {
      var ideaKey, multi, multiCallback, teamKey;
      if (teamError != null) {
        return callback(teamError, false);
      } else {
        multiCallback = function(multiError, multiResults) {
          if (multiError != null) {
            return callback(multiError, false);
          } else {
            return callback(null, true);
          }
        };
        ideaKey = "idea:" + teamResult;
        teamKey = ideaKey + "team";
        multi = redisClient.multi();
        multi.srem(teamKey, userID);
        multi.hincrby(ideaKey, "team", -1);
        multi.hset(userKey, "team", null);
        return multi.exec(multiCallback);
      }
    };
    return redisClient.hget(userKey, "team", getTeamCallback);
  };

  /*
  Include idea number in tag sets from a space-seperated list or array of words
  to a certain idea
  */

  generateTags = function(tagsArray, idea) {
    var allTagsKey, multi, tag, tagKey, _i, _len;
    multi = redisClient.multi();
    allTagsKey = app.set('tagsKey');
    for (_i = 0, _len = tagsArray.length; _i < _len; _i++) {
      tag = tagsArray[_i];
      tagKey = 'tag:' + tag;
      multi.sadd(allTagsKey, tagKey);
      multi.sadd(tagKey, idea);
    }
    return multi.exec(function(multiError, replies) {
      if (multiError) {
        return logger.log(null, "Error tagging post: " + JSON.stringify(multiError));
      }
    });
  };

  /*
  Include idea number in the set for each word it contains to allow for search by any keyword
  */

  makeSearchable = function(ideaData) {
    var allWords, allWordsKey, multi, word, wordKey, _i, _len;
    allWordsKey = app.set('wordsKey');
    allWords = ideaData.title.toLowerCase().split(/[^a-z0-9]/);
    allWords.concat(ideaData.description.toLowerCase().split(/[^a-z0-9]/));
    multi = redisClient.multi();
    for (_i = 0, _len = allWords.length; _i < _len; _i++) {
      word = allWords[_i];
      wordKey = 'word:' + word;
      multi.sadd(allWordsKey, wordKey);
      multi.sadd(wordKey, ideaData.id);
    }
    return multi.exec(function(multiError, replies) {
      if (multiError) {
        return logger.log(null, "Error making post searchable: " + JSON.stringify(multiError));
      }
    });
  };

  /*
  push this idea on to the top of the list of recent ideas
  */

  addToRecentIdeas = function(ideaNumber) {
    var key, pushCallback;
    key = app.set("recentIdeasKey");
    pushCallback = function(pushError, pushResult) {
      if ((pushError != null) || (!pushResult)) {
        return logger.log(null, "Failed to add idea number " + ideaNumber + " to recent ideas");
      }
    };
    return redisClient.lpush(key, ideaNumber, pushCallback);
  };

  /*
  Gets all the information on a certian user that is known to exist in the system.
  This method DOES NOT check for existance before calling
  */

  allUserData = function(userID, callback) {
    var getUserInfoCallback, userData, userIdeaKey, userKey;
    userKey = "user:" + userID;
    userIdeaKey = userKey + "ideas";
    userData = {};
    getUserInfoCallback = function(userErr, userResult) {
      var getIdeaInfoCallback, ideaKey;
      if (userErr) {
        return callback(userErr, null);
      } else {
        userData = userResult;
        if (userData.team != null) {
          ideaKey = "idea:" + userData.team;
          getIdeaInfoCallback = function(ideaError, ideaResult) {
            var userIdeasCallback;
            if (ideaError != null) {
              return callback(ideaError, null);
            } else {
              userData.team = ideaResult;
              userIdeasCallback = function(userIdeasError, userIdeasResult) {
                var idea, multi, multiCallback, _i, _len;
                if (userIdeasError != null) {
                  return callback(userIdeasError, null);
                } else {
                  multiCallback = function(multiError, multiResult) {
                    if (multiError != null) {
                      return callback(multiError, null);
                    } else {
                      userData.ideas = multiResult;
                      return callback(null, userData);
                    }
                  };
                  multi = redisClient.multi();
                  for (_i = 0, _len = userIdeasResult.length; _i < _len; _i++) {
                    idea = userIdeasResult[_i];
                    ideaKey = "idea:" + idea;
                    multi.hgetall(ideaKey);
                  }
                  return multi.exec(multiCallback);
                }
              };
              return redisClient.smembers(userIdeaKey, userIdeasCallback);
            }
          };
          return redisClient.hgetall(ideaKey, getIdeaInfoCallback);
        }
      }
    };
    return redisClient.hgetall(userKey, getUserInfoCallback);
  };

  /*
  Retrieves and returns all the information on the team of the given idea. This
  method DOES NOT check for the existance of an idea before calling.
  
  callback should take (error, result) where result is the array of members in the
  requested team
  */

  allTeamData = function(ideaID, callback) {
    var teamInfoCallback, teamKey;
    teamKey = "idea:" + ideaID + "team";
    teamInfoCallback = function(teamError, teamResult) {
      var multi, multiCallback, userID, userKey, _i, _len;
      if (teamError != null) {
        return callback(teamError, null);
      } else if (teamResult.length === 0) {
        return callback(null, []);
      } else {
        multiCallback = function(multiError, multiResult) {
          if (typeof multError !== "undefined" && multError !== null) {
            return callback(multiError, null);
          } else {
            return callback(null, multiResult);
          }
        };
        multi = redisClient.multi();
        for (_i = 0, _len = teamResult.length; _i < _len; _i++) {
          userID = teamResult[_i];
          userKey = "user:" + userID;
          multi.hgetall(userKey);
        }
        return multi.exec(multiCallback);
      }
    };
    return redisClient.smembers(teamKey, teamInfoCallback);
  };

  /*
  Gathers all the data on a given idea, including full info on the creator, team,
  and comments, with all text conveniently divided into paragraphs.
  
  callback must take (error, data)
  
  FLOW:
  ---------------------
  allIdeaData -> existsCallback -> ideaDataCallback -> creatorInfoCallback -> allCommentData -> callback
  */

  allIdeaData = function(ideaNumber, callback) {
    var existsCallback, ideaKey;
    ideaKey = "idea:" + ideaNumber;
    existsCallback = function(err, exists) {
      var ideaDataCallback;
      if (err) {
        return callback(err, null);
      } else if (!exists) {
        return callback(new NotFound('No one has thought up that idea yet.'), null);
      } else {
        ideaDataCallback = function(err, ideaInfo) {
          var creatorInfoCallback, numberOfComments;
          if (err) {
            return callback(err, null);
          } else {
            numberOfComments = ideaInfo.comments;
            ideaInfo.description = ideaInfo.description.split(/\r\n|\n/);
            creatorInfoCallback = function(err, creatorInfo) {
              var commentInfoCallback;
              if (err) {
                return callback(err, null);
              } else {
                ideaInfo.creator = creatorInfo;
                commentInfoCallback = function(err, commentData) {
                  var teamCallback, teamKey;
                  if (err) {
                    return callback(err, null);
                  } else {
                    ideaInfo.comments = commentData;
                    teamKey = ideaKey + "team";
                    teamCallback = function(teamError, teamResult) {
                      if (teamError != null) {
                        return callback(teamError, null);
                      } else {
                        ideaInfo.team = teamResult;
                        return callback(null, ideaInfo);
                      }
                    };
                    return allTeamData(ideaNumber, teamCallback);
                  }
                };
                return allCommentData(ideaInfo, commentInfoCallback);
              }
            };
            return redisClient.hgetall("user:" + ideaInfo.creator, creatorInfoCallback);
          }
        };
        return redisClient.hgetall(ideaKey, ideaDataCallback);
      }
    };
    return redisClient.exists(ideaKey, existsCallback);
  };

  /*
  Gathers all the comment data for the idea in question and passes to callback (error, data)
  where data is a dictionary of the relevant information on the idea
  
  FLOW:
  ---------------------
  allCommentData -> commentDataCallback -> commentCreatorCallback -> callback
  */

  allCommentData = function(ideaData, callback) {
    var commentDataCallback, key, multi, n, numberOfComments, _ref;
    numberOfComments = ideaData.comments;
    key = "idea:" + ideaData.id;
    multi = redisClient.multi();
    for (n = 1, _ref = +numberOfComments + 1; 1 <= _ref ? n < _ref : n > _ref; 1 <= _ref ? n++ : n--) {
      multi.hgetall(key + 'comment:' + n);
    }
    commentDataCallback = function(err, comments) {
      var comment, commentCreatorCallback, _i, _len;
      if (err) {
        return callback(err, null);
      } else {
        multi = redisClient.multi();
        for (_i = 0, _len = comments.length; _i < _len; _i++) {
          comment = comments[_i];
          comment.message = comment.message.split(/\r\n|\n/);
          multi.hgetall("user:" + comment.creator);
        }
        commentCreatorCallback = function(err, creators) {
          var n, _ref2;
          for (n = 0, _ref2 = +comments.length; 0 <= _ref2 ? n < _ref2 : n > _ref2; 0 <= _ref2 ? n++ : n--) {
            comments[n].creator = creators[n];
          }
          return callback(null, comments);
        };
        return multi.exec(commentCreatorCallback);
      }
    };
    return multi.exec(commentDataCallback);
  };

  /*
  Retrieves the list of recent ideas and populates it with a maximum of 25 items
  
  callback should take (error, result) where result is a list of the recent idea
  dictionaries.
  */

  allRecentIdeas = function(callback) {
    var key, rangeCallback;
    key = app.set("recentIdeasKey");
    rangeCallback = function(rangeError, rangeResult) {
      var id, ideaKey, multi, multiCallback, _i, _len;
      if (rangeError != null) {
        return callback(rangeError, null);
      } else if (rangeResult.length > 0) {
        multiCallback = function(multiError, multiResult) {
          var ideas;
          if (multiError != null) {
            return callback(multiError, null);
          } else {
            ideas = shortenIdeaDescriptions(multiResult);
            return callback(null, ideas);
          }
        };
        multi = redisClient.multi();
        for (_i = 0, _len = rangeResult.length; _i < _len; _i++) {
          id = rangeResult[_i];
          ideaKey = "idea:" + id.toString();
          multi.hgetall(ideaKey);
        }
        return multi.exec(multiCallback);
      } else {
        return callback(null, []);
      }
    };
    return redisClient.lrange(key, 0, 25, rangeCallback);
  };

  /*
  Shorten the descriptions in the given ideas and return the modified ideas
  */

  shortenIdeaDescriptions = function(ideas) {
    var desc, idea, maxLength, _i, _len;
    for (_i = 0, _len = ideas.length; _i < _len; _i++) {
      idea = ideas[_i];
      desc = idea.description;
      maxLength = app.set("maxDescriptionLength");
      if (desc.length > maxLength) {
        idea.description = desc.substring(0, maxLength) + "...";
      }
    }
    return ideas;
  };

  /*
  Return the HTML that results from compileing the given file with the given options
  */

  compileJade = function(jadeFile, jadeLocals, jadeCallback) {
    var readCallback;
    readCallback = function(readError, contents) {
      var renderer;
      if (readError != null) {
        return jadeCallback(readError, null);
      } else {
        renderer = jade.compile(contents, {
          filename: jadeFile
        });
        return jadeCallback(null, renderer(jadeLocals));
      }
    };
    return fs.read(jadeFile, readCallback);
  };

  app.put('/ideas/upvote/?', function(req, res, next) {
    var ideaName;
    ideaName = 'idea:' + req.body.idea;
    return redisClient.hincrby(ideaName, 'upvotes', 1, function(err, result) {
      if (err) {
        return next(err);
      } else {
        return res.sent("Success", 201);
      }
    });
  });

  app.put('/ideas/downvote/?', function(req, res, next) {
    var ideaName;
    ideaName = 'idea:' + req.body.idea;
    return redisClient.hincrby(ideaName, 'downvotes', 1, function(err, result) {
      if (err) {
        return next(err);
      } else {
        return res.sent("Success", 201);
      }
    });
  });

  app.put('/ideas/comments/upvote/?', function(req, res, next) {
    var ideaName;
    ideaName = 'idea:' + req.body.idea + 'comment:' + req.body.comment;
    return redisClient.hincrby(ideaName, 'upvotes', 1, function(err, result) {
      if (err) {
        return next(err);
      } else {
        return res.sent("Success", 201);
      }
    });
  });

  app.put('/ideas/comments/downvote/?', function(req, res, next) {
    var ideaName;
    ideaName = 'idea:' + req.body.idea + 'comment:' + req.body.comment;
    return redisClient.hincrby(ideaName, 'downvotes', 1, function(err, result) {
      if (err) {
        return next(err);
      } else {
        return res.sent("Success", 201);
      }
    });
  });

  app.put('/ideas/comments/includevote/?', function(req, res, next) {
    var ideaName;
    ideaName = 'idea:' + req.body.idea + 'comment:' + req.body.comment;
    return redisClient.hincrby(ideaName, 'includevotes', 1, function(err, result) {
      if (err) {
        return next(err);
      } else {
        return res.sent("Success", 201);
      }
    });
  });

}).call(this);
