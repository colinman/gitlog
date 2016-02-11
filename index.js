// TODO: move userid to cookie

var request = require('request');
var express = require('express');
var app = express();
var qs = require('querystring');
var OAuth2 = require('oauth').OAuth2;
var _ = require('underscore');
var querystring = require('querystring');

var baseUrl = 'https://710a72a7.ngrok.com';
var apiUrl = 'https://api.github.com';

// To modify hook path, modify jade file too
var redirectPath = '/oauth', registerPath = '/register', listenPath = '/listen', hookPath = '/hook';
var redirectURL = baseUrl + redirectPath;
var listenURL = baseUrl + listenPath;
var clientID = 'c63286947a4872bbbe3b';
var clientSecret = 'b685dd56a2e5b6302d019c5256b0898f7ebfc472';

app.set('view engine', 'jade');

var users = {}; // Maps ID's to users to store server state

// configure Oauth2 object
var oauth2 = new OAuth2(clientID, clientSecret, 'https://github.com/', 'login/oauth/authorize', 'login/oauth/access_token', null);

function oauth_headers (userid) {
  return {'Authorization': 'token ' + users[userid]["token"], 'User-Agent': 'Treehacks App'};
}

// redirects user to authenticate us to give us access token
function getAccessTokenURL () {
  var csrfToken = Math.random().toString(36).substring(7);
  return oauth2.getAuthorizeUrl({
    scope: ['repo', 'user', 'write:repo_hook'],
    state: csrfToken 		// note: not using this for now
  });
}

function writeBody(res, body) {
  res.writeHead(200, { 'Content-Length': body.length, 'Content-Type': 'text/html' });
  res.end(body);
}

function getRepos(userid, cb) {
  request({url:apiUrl + '/user/repos', qs: {type: 'owner'}, headers: oauth_headers(userid)}, function (error, response, body) {
    // note: response is of type IncomingMessage
    if (error) console.log('Error:', error);
    else if (response.statusCode !== 200) console.log('Error code:', response.statusCode);
    cb(JSON.parse(body));
  });
}

function writeHook(userid, hookUrl, cb) {
  request({
    url: hookUrl,
    method: "POST",
    headers: oauth_headers(userid),
    body: JSON.stringify({
      name: "web",
      active: true,
      config: {
      	url: baseUrl + listenPath
      }    
    })
  }, function (error, response, body) {
    if (error) console.log('Error:', error);
    else if (response.statusCode !== 200) {
      console.log('Error code:', response.statusCode);
      console.log('Error:', body);
    }
    cb();
  });
}

app.get(registerPath, function(req, res) {
  writeBody(res, '<a href="' + getAccessTokenURL() + '"> Get Code </a>');
});

app.get(redirectPath + "", function(req, res) {
  oauth2.getOAuthAccessToken(
    req.query.code, {'redirect_uri': redirectURL},
    function (e, access_token, refresh_token, results){
      if (e) {
	console.log("Error Parsing Access Token: " + JSON.stringify(e));
	res.redirect(registerPath);
      } else if (results.error) {
	console.log("Error Parsing Access Token: " + JSON.stringify(results));
	res.redirect(registerPath);
      }
      else {
        console.log('Obtained access_token: ', access_token);
        var userid = (Math.random() + 1).toString(36).substring(2,15); // probably won't collide
        users[userid] = {token: access_token};
	getRepos(userid, function (repos) {
	  res.render('repos.jade', { repos: repos, userid: userid });
	});
      }
    });
});

app.get(hookPath, function(req, res) {
  var userid = req.query.id, hookUrl = req.query.url;
  if (!userid || !hookUrl || !users[userid]) return res.redirect(registerPath);
  var user = users[userid];
  console.log(user);
  writeHook(userid, hookUrl, function (err) {
    if (err) writeBody(res, "An error occurred. Please try again.");
    else res.render('hook.jade', {token: user.token});    
  });
});

app.post(listenPath, function(req, res) {
  console.log(req.body);
});

app.use(express.static(__dirname + '/public'));

app.listen(8080, function() {
  console.log("Listening on 8080");
});
