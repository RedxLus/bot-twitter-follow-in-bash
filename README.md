# Bot twitter follow in bash

This bot is current in **v0.5** so is in **beta**. May have some unexpected errors. As always, use at your own risk.

This bot is build using **Twitter API V2** only. You can check the code, is very simple. Works with functions and curl api calls directly. It does not go through any external server or need other dependencies. It can be run on any computer or server running Linux or Mac.

Have working currently:

![image](https://user-images.githubusercontent.com/15265490/220315110-63485b7d-f536-4384-bcfd-88590c90ff78.png)

To do (next versions):
* Detect commands need and install or ask to install
* Save unfollows to not follow again (need change the logic of the functions)
* Get the token without need postman (only first config, later it auto update the token)
* Whitelist_users to ignore when follow or unfollow

## Table of content of this readme
- [Bot twitter follow in bash](#bot-twitter-follow-in-bash)
  * [0. Access to developer dashboard in Twitter](#0-access-to-developer-dashboard-in-twitter)
  * [1. Configure the project](#1-configure-the-project)
  * [2. Configure postman](#2-configure-postman)
  * [3. Configure the bot](#3-configure-the-bot)
  * [4. Use the bot](#4-use-the-bot)
  * [FAQ](#faq)
    + [Limit of API?](#limit-of-api-)
    + [Auto graph chart all actions](#auto-graph-chart-all-actions)

## 0. Access to developer dashboard in Twitter

Go to https://developer.twitter.com/en/portal/dashboard and login.

It will prompt to enter some things as: 
* What country are you based in?
* What's your use case?

We accept the terms and conditions and we are already inside.

In some cases, especially when you already have a certain number of followers, you may get: _You do not qualify for Essential access at this time. But they let you access Elevated access._

Remember read the https://help.twitter.com/en/rules-and-policies/twitter-automation and https://developer.twitter.com/en/docs/twitter-api/rate-limits#v2-limits

## 1. Configure the project

To create a Project, click on "New Project" in the Projects & Apps page inside the developer portal.

Set:

![image](https://user-images.githubusercontent.com/15265490/220286288-5a828327-2dda-426f-8757-567d02c7bee2.png)
![image](https://user-images.githubusercontent.com/15265490/220286355-e9968160-ed51-4178-bbd4-f99bdfbaa4e0.png)
![image](https://user-images.githubusercontent.com/15265490/220305251-3ed8c2f3-33a5-4409-b210-8da48930a312.png)
* If you are using postman in the browser is https://oauth.pstmn.io/v1/browser-callback if you are using in the app is https://oauth.pstmn.io/v1/callback


## 2. Configure postman

This has to be done only 1 time. Then the script is automatically refreshed. I recommend downloading the Postman app for convenience, but it can still be done in the browser.

Go to the public postman workspace: https://www.postman.com/twitter/workspace/twitter-s-public-workspace/request/9956214-419497de-aefc-4a8e-9ff5-1b4f73d948e3

Change type to: **OAuth 2.0**

In Configure New Token -> Configure options:

| Search  | Input |
| ------------- | ------------- |
| Token Name  | login-example  |
| Grant Type  | Authorization Code (With PKCE)  |
| Auth URL  | https://twitter.com/i/oauth2/authorize  |
| Access Token URL  | https://api.twitter.com/2/oauth2/token  |
| Client ID  | Generate in Twitter dashboard  |
| Client Secret  | Generate in Twitter dashboard  |
| Scope  | tweet.read users.read follows.write offline.access follows.read like.write  |
| State  | state  |

![image](https://user-images.githubusercontent.com/15265490/220308941-f03d40dd-9934-4eeb-9977-fa7a0ae5d418.png)

Now copy the Access Token to TK_POSTMAN_ACCESS and refresh_token to TK_POSTMAN_REFRESH in config.json

![image](https://user-images.githubusercontent.com/15265490/220314293-a8fdac09-d997-4bd1-bd98-f45d4de562dc.png)

## 3. Configure the bot

To configure this bot. Change the parameters of the config.json file.

| Search  | Input |
| ------------- | ------------- |
| your_username  | Your screen username. Without @  |
| CLIENT_ID  | Check Twitter dashboard  |
| API_KEY  | Check Twitter dashboard  |
| API_SECRET_KEY  | Check Twitter dashboard  |
| TK_POSTMAN_ACCESS  | Check Postman  |
| TK_POSTMAN_REFRESH  | Check Postman  |

## 4. Use the bot

Just run:

``bash twitter-bot.sh``

Have English menu:

![image](https://user-images.githubusercontent.com/15265490/220546238-8a9fca98-ccce-4e85-8dba-b4d4ff79d58d.png)

And Spanish menu:

![image](https://user-images.githubusercontent.com/15265490/220546306-60ba4f19-726d-46b5-804d-24b38881a7b2.png)

You can change the language by changing the language variable in config.json. Currently just English and Spanish supported. But feel free to MR and update.

## FAQ

### Limit of API?

The script read the header and detect when the API have a limit and will auto refresh every minute until can continue.

![image](https://user-images.githubusercontent.com/15265490/220545805-405207eb-22e8-4383-9ea6-9412c68e152b.png)

### Auto graph chart all actions

The script will generate a graph of all actions: Follow, Unfollow and Likes.

You can check in the dir gnuplot.

![graph](https://user-images.githubusercontent.com/15265490/235502987-6753baab-059a-4474-970e-dc8a88208c46.png)
