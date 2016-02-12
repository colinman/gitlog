# TODO: move userid to cookie
request = require 'request'
express = require 'express'
bodyParser = require 'body-parser'
qs = require 'querystring'
OAuth2 = require('oauth').OAuth2
_ = require 'underscore'
querystring = require 'querystring'
redis = require "redis"

[apiUrl, baseUrl] = ['https://api.github.com', 'http://gitlog.treehacks.com']

# To modify hook path, modify jade file too
[redirectPath, registerPath, listenPath, hookPath, viewPath] = ['/oauth', '/register', '/listen', '/hook', '/log']
[clientID, clientSecret] = ['c63286947a4872bbbe3b', 'b685dd56a2e5b6302d019c5256b0898f7ebfc472']
listenSecret = 'notreallyasecret'

app = express()
app.use bodyParser.json() # for parsing application/json
app.use bodyParser.urlencoded(extended: true) # for parsing application/x-www-form-urlencoded
app.use express.static(__dirname + '/public')
app.set 'view engine', 'jade'

users = {} # Maps ID's to users to store server state in ram
rclient = redis.createClient()

# configure Oauth2 object
oauth2 = new OAuth2(clientID, clientSecret, 'https://github.com/', 'login/oauth/authorize', 'login/oauth/access_token', null)

app.get registerPath, (req, res) -> res.render 'register.jade', registerURL: getAccessTokenURL()

app.get redirectPath, (req, res) ->
  oauth2.getOAuthAccessToken req.query.code, {'redirect_uri': baseUrl + redirectPath},
  (e, access_token, refresh_token, results) ->
    if e
      console.log 'Error Parsing Access Token: ' + JSON.stringify(e)
      res.redirect registerPath
    else if results.error
      console.log 'Error Parsing Access Token: ' + JSON.stringify(results)
      res.redirect registerPath
    else
      console.log 'Obtained access_token: ', access_token
      userid = (Math.random() + 1).toString(36).substring(2, 15)
      # probably won't collide
      users[userid] = token: access_token
      getRepos userid, (repos) ->
        res.render 'repos.jade',
          repos: repos
          userid: userid

app.get viewPath, (req, res) ->
  allCommits = []
  rclient.lrange 'pushes', 0, 100, (err, pushes) ->
    for push in pushes
      push = JSON.parse push
      for commit in push.commits then allCommits.push commit:commit, repo:push.repo
    res.render 'log.jade', commits: allCommits

app.get hookPath, (req, res) ->
  [userid, hookUrl, reponame] = [req.query.id, req.query.url, req.query.reponame]
  if !userid or !hookUrl or !reponame or !users[userid] then return res.redirect(registerPath)
  user = users[userid]
  writeHook userid, hookUrl, (err) ->
    if err then return writeBody res, 'An error occurred. Please try again.'
    else
      delete users[userid]
      res.render 'hook.jade', repoName: reponame

app.post listenPath, (req, res) ->
  payload = JSON.parse req.body.payload
  repo = payload.repository
  if !payload.commits or !repo then return console.log "Registration"
  rclient.lpush "pushes", JSON.stringify({commits:payload.commits, repo:repo})
  commits = payload.commits
  res.status(200).send({})

app.get '*', (req, res) -> res.redirect '/register'

app.listen 80, -> console.log 'Listening on 80'

oauth_headers = (userid) -> {
  'Authorization': 'token ' + users[userid]['token']
  'User-Agent': 'Treehacks App'
}

# redirects user to authenticate us to give us access token
getAccessTokenURL = ->
  csrfToken = Math.random().toString(36).substring(7)
  oauth2.getAuthorizeUrl
    scope: [
      'repo'
      'user'
      'write:repo_hook'
    ]
    state: csrfToken

writeBody = (res, body) ->
  res.writeHead 200,
    'Content-Length': body.length
    'Content-Type': 'text/html'
  res.end body

getRepos = (userid, cb) ->
  request {
    url: apiUrl + '/user/repos'
    qs: type: 'owner'
    headers: oauth_headers(userid)
  }, (error, response, body) ->
    # note: response is of type IncomingMessage
    if error then console.log 'Error:', error
    else if !response.statusCode != 200 then console.log 'Error code:', response.statusCode
    cb JSON.parse(body)

writeHook = (userid, hookUrl, cb) ->
  request {
    url: hookUrl
    method: 'POST'
    headers: oauth_headers(userid)
    body: JSON.stringify(
      name: 'web'
      active: true
      config:
        url: baseUrl + listenPath
        secret: listenSecret
    )
  }, (error, response, body) ->
    if error then console.log 'Error:', error
    else if !response.statusCode != 201
      console.log 'Error code:', response.statusCode
      console.log 'Error:', body
    cb()
