#!/bin/bash

# NAME OF FILES and DIR
DIR_internal="internal-files"
DIR_internal_headers="$DIR_internal/headers"
NAME_FILE_internal_config="$DIR_internal/internal.json"
NAME_FILE_save_id_tweets_from_hashtags="$DIR_internal/id_tweets_from_hashtag.txt"
NAME_FILE_save_id_users_from_tweets="$DIR_internal/id_users.txt"
NAME_FILE_save_id_tweets_from_user="$DIR_internal/id_tweets_from_user.txt"
NAME_FILE_follow_id_bulk="$DIR_internal/already_follow_anytime.txt"
NAME_FILE_tmp="$DIR_internal/tmp.txt"
NAME_FILE_config="config.json"
NAME_FILE_followers="$DIR_internal/my_followers.txt"
NAME_FILE_following="$DIR_internal/my_following.txt"
NAME_FILE_non_follow_back="$DIR_internal/non_follow_back.txt"
NAME_FILE_unfollow_non_follow_back="$DIR_internal/already_unfollow_anytime.txt"
NAME_FILE_like_id="$DIR_internal/liked_users.txt"
DIR_plot="gnuplot"
NAME_FILE_plot_data="$DIR_plot/data.json"

# TOKENS
USERNAME=$(jq .your_authentication.your_username $NAME_FILE_config | tr -d '"')
API_KEY=$(jq .your_authentication.API_KEY $NAME_FILE_config | tr -d '"')
API_SECRET_KEY=$(jq .your_authentication.API_SECRET_KEY $NAME_FILE_config | tr -d '"')
TK_POSTMAN_ACCESS=$(jq .your_authentication.TK_POSTMAN_ACCESS $NAME_FILE_config | tr -d '"')
BEARER_TOKEN=$(curl -s -u "$API_KEY:$API_SECRET_KEY" --data 'grant_type=client_credentials' 'https://api.twitter.com/oauth2/token' | jq .access_token | tr -d '"')
YOUR_ID=$(curl -s "https://api.twitter.com/2/users/by?usernames=$USERNAME" -H "Authorization: Bearer $BEARER_TOKEN" | jq -r '.data[] | .id')

# Internal function to not have repeated values in files
delete_repeat_from_file () {
  sort $NAME_FILE | uniq > $NAME_FILE_tmp && mv $NAME_FILE_tmp $NAME_FILE
}

# Internal function delete IDs when they are processed to other file
delete_id () {
  local TO_SEARCH=$1
  local FILE_TO_SEARCH=$2
  awk "!/$TO_SEARCH/" $FILE_TO_SEARCH > $NAME_FILE_tmp && mv $NAME_FILE_tmp $FILE_TO_SEARCH
}

# Check the file of followers and followings and extract only not follow back
save_non_follow_back () {
  following_download $YOUR_ID
  followers_download $YOUR_ID
  comm -13 <(sort < $NAME_FILE_followers) <(sort < $NAME_FILE_following) > $NAME_FILE_non_follow_back
}

# Internal function config limits. Run each action to update the internal.json 
update_internal_config () {
  TODAY_DATE=$(date "+%F")
  EXEC_HOUR=$(date "+%H")
  
  # This IF change only if date is not today and restart values to 0
  if [ "$TODAY_DATE" != $(jq .today_date $NAME_FILE_internal_config | tr -d '"') ]; then
    jq ".today_date = \"$TODAY_DATE\"" $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
    jq ".follows_today = 0" $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
    jq ".unfollows_today = 0" $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
    jq ".like_today = 0" $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
  fi

  if [ "$1" = "add_1_follow" ]; then
    jq ".follows_today += 1"  $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
  fi

  if [ "$1" = "add_1_unfollow" ]; then
    jq ".unfollows_today += 1"  $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
  fi

  if [ "$1" = "add_1_like" ]; then
    jq ".like_today += 1"  $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
  fi

  jq ".exec_hour = \"$EXEC_HOUR\"" $NAME_FILE_internal_config > tmp.json && mv tmp.json $NAME_FILE_internal_config
}

# Internal function to not ask always for new token - NOT WORK currently
update_refesh_token () {
  local REFRESH=$(jq .your_authentication.TK_POSTMAN_REFRESH $NAME_FILE_config | tr -d '"')
  local CLIENT_ID=$(jq .your_authentication.CLIENT_ID $NAME_FILE_config | tr -d '"')
  local API="oauth2/token"
  local CURL=$(curl -s -X POST "https://api.twitter.com/2/$API" \
                  -H "Content-Type: application/x-www-form-urlencoded" \
                  --data-urlencode "refresh_token=$REFRESH" \
                  --data-urlencode "grant_type=refresh_token" \
                  --data-urlencode "client_id=$CLIENT_ID")
  local A_TK=$(jq -r '.access_token' <<< "$CURL")
  local R_TK=$(jq -r '.refresh_token' <<< "$CURL")
  
  jq ".your_authentication.TK_POSTMAN_ACCESS = \"$A_TK\"" $NAME_FILE_config > tmp.json && mv tmp.json $NAME_FILE_config
  jq ".your_authentication.TK_POSTMAN_REFRESH = \"$R_TK\"" $NAME_FILE_config > tmp.json && mv tmp.json $NAME_FILE_config
  
  TK_POSTMAN_ACCESS=$(jq .your_authentication.TK_POSTMAN_ACCESS $NAME_FILE_config | tr -d '"')
}

# Check the limit of the API at real time
checker_limit_api () {
  local NAME_FILE_H=$1

  if [ -e "$NAME_FILE_H" ]; then
    local HARD_LIMIT=$(grep "x-rate-limit-remaining:" $NAME_FILE_H | awk '{print int($2)}')
    if [ "$HARD_LIMIT" -eq "0" ] || [ "$HARD_LIMIT" -eq "1" ]; then
      local EPOCH_TIME_CURRENT=$(date +"%s")
      local EPOCH_TIME_RESET=$(grep "x-rate-limit-reset:" $NAME_FILE_H | awk '{print int($2)}')
      local DIFF_SECONDS=$((EPOCH_TIME_RESET - EPOCH_TIME_CURRENT))
      local DIFF_MINUTES=$((DIFF_SECONDS / 60))
      if [ "$DIFF_MINUTES" -le 0 ]; then
          rm $NAME_FILE_H
      else
          while [ "$DIFF_MINUTES" -gt 0 ]; do
            echo ""
            echo "Limit of API:"
            echo "Have to wait $DIFF_MINUTES minutes to use the api again"
            sleep 60
            DIFF_MINUTES=$((DIFF_MINUTES - 1))
          done
      fi
    fi
  fi
}

# Get list of recent tweets with hashtags
save_id_tweets_from_hashtags () {
  local NAME_FILE="$NAME_FILE_save_id_tweets_from_hashtags"
  local LIMIT_PER_HASHTAG=$(jq .limit_search_from_hashtag $NAME_FILE_config)
  
  cat $NAME_FILE_config | jq '.hashtags[]' | while read message; do
      local HASHTAGS=$(echo $message | tr -d '"')
      local API="tweets/search/recent?query=%23$HASHTAGS&max_results=$LIMIT_PER_HASHTAG"
      curl -s "https://api.twitter.com/2/$API" \
        -H "Authorization: Bearer $BEARER_TOKEN" | jq -r '.data[] | .id' >> $NAME_FILE
  done
  
  delete_repeat_from_file

  echo "Have downloaded $(wc -l $NAME_FILE | awk '{print $1}') ID of hashtags to the file $NAME_FILE"
}

# Get array of id who like a tweet
# EXAMPLE USE: save_id_users_from_tweets $NAME_FILE_save_id_tweets_from_user
save_id_users_from_tweets () {
  local NAME_FILE_TAKE=$1
  local NAME_FILE="$NAME_FILE_save_id_users_from_tweets"
  local NAME_FILE_H="$DIR_internal_headers/headers-tweets.txt"
  
  while read line; do
      
      checker_limit_api $NAME_FILE_H

      echo "Getting $line ..."
      
      local API="tweets/$line/liking_users"
      local CURL=$(curl -s -D $NAME_FILE_H "https://api.twitter.com/2/$API" \
                        -H "Authorization: Bearer $BEARER_TOKEN")

      if [ $(jq -r '.meta.result_count' <<< "$CURL") = 0 ]; then
        echo "No likes. Next tweet ..."
      else
        jq -r '.data[] | .id' <<< "$CURL" >> $NAME_FILE
        # Check if have next_token. Means have more 100 likes. Pass next page to continue downloading.
        while jq -e '.meta.next_token != null' <<< "$CURL" >/dev/null 2>&1; do
          checker_limit_api $NAME_FILE_H
          local PAG_TK=$(jq -r '.meta.next_token' <<< "$CURL")
          local API="tweets/$line/liking_users?pagination_token=$PAG_TK"
          local CURL=$(curl -s -D $NAME_FILE_H "https://api.twitter.com/2/$API" \
                            -H "Authorization: Bearer $BEARER_TOKEN")
          jq -r '.data? | select(. != null)[] | .id' <<< "$CURL" >> $NAME_FILE
        done
      fi
  done < $NAME_FILE_TAKE

  delete_repeat_from_file

  echo "Have downloaded $(wc -l $NAME_FILE | awk '{print $1}') ID of users to the file $NAME_FILE"

  rm $NAME_FILE_H
}

# Get ID of USER by name
get_id_from_user () {
  local USERNAME=$1
  local API="users/by?usernames=$USERNAME"
  local RESULT=$(curl -s "https://api.twitter.com/2/$API" \
    -H "Authorization: Bearer $BEARER_TOKEN" | jq -r '.data[] | .id')
  echo $RESULT
}

# Get USERNAME of USER by ID
get_username_from_user () {
  local USERNAME=$1
  local API="users/$USERNAME"
  local RESULT=$(curl -s "https://api.twitter.com/2/$API" \
    -H "Authorization: Bearer $BEARER_TOKEN" | jq '.data.username' | tr -d '"')
  echo $RESULT
}

# Download all followers of user ID passed
# EXAMPLE: followers_download $YOUR_ID
followers_download () {
  local USER_ID=$1
  local NAME_FILE="$NAME_FILE_followers"
  local NAME_FILE_H="$DIR_internal_headers/headers-followers.txt"
  local API="users/$USER_ID/followers?max_results=1000"
  local CURL=$(curl -s -D $NAME_FILE_H "https://api.twitter.com/2/$API" \
                    -H "Authorization: Bearer $BEARER_TOKEN")
  
  checker_limit_api $NAME_FILE_H
  
  if [ $(jq -r '.meta.result_count' <<< "$CURL") = 0 ]; then
    echo "No followers. Skipping ..."
  else
    jq -r '.data[] | .id' <<< "$CURL" > $NAME_FILE
    # Check if have next_token. Means have more 1000 followers. Pass next page to continue downloading.
    while jq -e '.meta.next_token != null' <<< "$CURL" >/dev/null 2>&1; do
      checker_limit_api $NAME_FILE_H
      local PAG_TK=$(jq -r '.meta.next_token' <<< "$CURL")
      local API="users/$USER_ID/followers?max_results=1000&pagination_token=$PAG_TK"
      local CURL=$(curl -s -D $NAME_FILE_H "https://api.twitter.com/2/$API" \
                        -H "Authorization: Bearer $BEARER_TOKEN")
      jq -r '.data? | select(. != null)[] | .id' <<< "$CURL" >> $NAME_FILE
    done
  fi
  
  delete_repeat_from_file
  rm $NAME_FILE_H
  echo "Have downloaded $(wc -l $NAME_FILE | awk '{print $1}') ID of followers to the file $NAME_FILE"
}

# Download all following of user ID passed
# EXAMPLE: following_download $YOUR_ID
following_download () {
  local USER_ID=$1
  local NAME_FILE="$NAME_FILE_following"
  local NAME_FILE_H="$DIR_internal_headers/headers-following.txt"
  local API="users/$USER_ID/following?max_results=1000"
  local CURL=$(curl -s -D $NAME_FILE_H "https://api.twitter.com/2/$API" \
                    -H "Authorization: Bearer $BEARER_TOKEN")
  
  checker_limit_api $NAME_FILE_H
  
  if [ $(jq -r '.meta.result_count' <<< "$CURL") = 0 ]; then
    echo "No following. Skipping ..."
  else
    jq -r '.data[] | .id' <<< "$CURL" > $NAME_FILE
    # Check if have next_token. Means have more 1000 following. Pass next page to continue downloading.
    while jq -e '.meta.next_token != null' <<< "$CURL" >/dev/null 2>&1; do
      checker_limit_api $NAME_FILE_H
      local PAG_TK=$(jq -r '.meta.next_token' <<< "$CURL")
      local API="users/$USER_ID/following?max_results=1000&pagination_token=$PAG_TK"
      local CURL=$(curl -s -D $NAME_FILE_H "https://api.twitter.com/2/$API" \
                        -H "Authorization: Bearer $BEARER_TOKEN")
      jq -r '.data? | select(. != null)[] | .id' <<< "$CURL" >> $NAME_FILE
    done
  fi

  rm $NAME_FILE_H

  echo "Have downloaded $(wc -l $NAME_FILE | awk '{print $1}') ID of following to the file $NAME_FILE"
}

# Get latest post id of important user in config or any user
# EXAMPLE 1: save_id_tweets_from_user from_config_file
# EXAMPLE 2: save_id_tweets_from_user from_general_user NekoJitaBlog
# EXAMPLE 3: save_id_tweets_from_user from_general_user 44724559
save_id_tweets_from_user () {
  local NAME_FILE="$NAME_FILE_save_id_tweets_from_user"
  local LIMIT_PER_USER=$(jq .limit_search_from_user $NAME_FILE_config)
  
  if [ "$1" = "from_config_file" ]; then
    local USER_TO_COPY=($(cat $NAME_FILE_config | jq -r '.copy_users | .[]'))
  fi

  if [ "$1" = "from_general_user" ]; then
    local USER_TO_COPY=$(echo $2)
  fi

  for message in "${USER_TO_COPY[@]}"; do
      local USER=$(echo $message | tr -d '"')
      echo "Select $USER ..."
      if [[ $USER =~ ^[0-9]+$ ]]; then
          # If is all numbers that means is ID so not need do any.
          local USER_ID=$(echo $USER)
      else
          # Otherway need to convert username to ID.
          local USER_ID=$(get_id_from_user $USER)
      fi
      local API="users/$USER_ID/tweets?max_results=$LIMIT_PER_USER&exclude=retweets"
      local CURL=$(curl -s "https://api.twitter.com/2/$API" \
                        -H "Authorization: Bearer $BEARER_TOKEN")
      jq -r '.data[] | .id' <<< "$CURL" >> $NAME_FILE
  done
  
  delete_repeat_from_file

  echo "Have downloaded $(wc -l $NAME_FILE | awk '{print $1}') ID of hashtags to the file $NAME_FILE"
}

# Follow by ID in bulk
# EXAMPLE: follow_id_bulk $NAME_FILE_save_id_users_from_tweets
follow_id_bulk () {
  local NAME_FILE_TAKE=$1
  local NAME_FILE="$NAME_FILE_follow_id_bulk"
  local NAME_FILE_H="$DIR_internal_headers/headers-follow.txt"
  local SLEEP_TIME="10"
  local LIMIT_FOLLOW=$(expr $(jq .limit_follow_per_day $NAME_FILE_config) - $(jq .follows_today $NAME_FILE_internal_config))
  local COUNTER=1

  if [ $(jq .limit_follow_per_day $NAME_FILE_config | tr -d '"') = $(jq .follows_today $NAME_FILE_internal_config | tr -d '"') ]; then
    echo "limit of follow today"
    exit
  fi

  while [ $COUNTER -le $LIMIT_FOLLOW ] && read line; do
      
      # Check the limit of the API at real time
      checker_limit_api $NAME_FILE_H
      
      echo "Following user ID $line ..."
      
      local API="users/$YOUR_ID/following"
      local STATUS=$(curl -s -D $NAME_FILE_H -X POST "https://api.twitter.com/2/$API" \
        -H "Authorization: Bearer $TK_POSTMAN_ACCESS" \
        -H "Content-Type: application/json" \
        -d '{"target_user_id":"'$line'"}' | jq .status)
      
      if [ "$STATUS" == "401" ]; then
        echo "The status is 401: Unauthorized."
        echo "Check your TK_POSTMAN_ACCESS"
        rm $NAME_FILE_H
        exit
      fi
      
      echo $line >> $NAME_FILE
      
      delete_id $line $NAME_FILE_TAKE
      
      update_internal_config add_1_follow

      echo "Wait $SLEEP_TIME seconds to follow again ..."
      sleep $SLEEP_TIME
      echo ""
      
      local COUNTER=$((COUNTER+1))
  done < $NAME_FILE_TAKE
  
  rm $NAME_FILE_H
}

# unfollow not follow back
# EXAMPLE: unfollow_non_follow_back $NAME_FILE_non_follow_back
unfollow_non_follow_back () {
  local NAME_FILE_TAKE=$1
  local NAME_FILE="$NAME_FILE_unfollow_non_follow_back"
  local NAME_FILE_H="$DIR_internal_headers/headers-unfollow.txt"
  local SLEEP_TIME="1"
  local LIMIT_UNFOLLOW=$(expr $(jq .limit_unfollow_per_day $NAME_FILE_config) - $(jq .unfollows_today $NAME_FILE_internal_config))
  local COUNTER=1

  if [ $(jq .limit_unfollow_per_day $NAME_FILE_config | tr -d '"') = $(jq .unfollows_today $NAME_FILE_internal_config | tr -d '"') ]; then
    echo "limit of unfollow today"
    exit
  fi

  save_non_follow_back

  while [ $COUNTER -le $LIMIT_UNFOLLOW ] && read line; do
      
      # Check the limit of the API at real time
      checker_limit_api $NAME_FILE_H
      
      echo "Unfollowing user ID $line ..."

      local API="users/$YOUR_ID/following/$line"
      local STATUS=$(curl -s -D $NAME_FILE_H -X DELETE "https://api.twitter.com/2/$API" \
        -H "Authorization: Bearer $TK_POSTMAN_ACCESS" \
        -H "Content-Type: application/json" | jq .status)
      
      if [ "$STATUS" == "401" ]; then
        echo "The status is 401: Unauthorized."
        echo "Check your TK_POSTMAN_ACCESS"
        rm $NAME_FILE_H
        exit
      fi
      
      echo $line >> $NAME_FILE
      
      delete_id $line $NAME_FILE_TAKE
      
      update_internal_config add_1_unfollow

      echo "Wait $SLEEP_TIME seconds to unfollow again ..."
      sleep $SLEEP_TIME
      echo ""
      
      local COUNTER=$((COUNTER+1))
  done < $NAME_FILE_TAKE
  
  rm $NAME_FILE_H
}

# Generate plot using internal.config info of actions
generate_plot () {
  jq -s '.[0] + [.[1]]' $NAME_FILE_plot_data $NAME_FILE_internal_config > $NAME_FILE_tmp && mv $NAME_FILE_tmp $NAME_FILE_plot_data
  jq 'reverse | unique_by(.today_date) | group_by(.today_date) | map(max_by(.exec_hour))' $NAME_FILE_plot_data > $NAME_FILE_tmp && mv $NAME_FILE_tmp $NAME_FILE_plot_data

  cd ./$DIR_plot && gnuplot plot.gnp && cd .. && echo "Generated the chart."
}

# Not finish
like_id () {
  local NAME_FILE_TAKE=$1
  local NAME_FILE="$NAME_FILE_like_id"
  local NAME_FILE_H="$DIR_internal_headers/headers-likes.txt"
  
  while read line; do
      
    checker_limit_api $NAME_FILE_H

    echo "Getting $line ..."
    local API="users/$YOUR_ID/likes"
    local CURL=$(curl -s -D $NAME_FILE_H -X POST "https://api.twitter.com/2/$API" \
                      -H "Authorization: Bearer $TK_POSTMAN_ACCESS" \
                      -H "Content-Type: application/json" \
                      -d '{"tweet_id":"'$line'"}')
    update_internal_config add_1_like
    echo $CURL | jq .
  done < $NAME_FILE_TAKE

}

# Not finish
like_non_follow_back () {
  save_non_follow_back

  while read line; do
      echo "Getting $line ..."
      USER_ID=$(get_username_from_user $line)
      echo " is $USER_ID"
      rm $NAME_FILE_save_id_tweets_from_user
      save_id_tweets_from_user from_general_user $USER_ID
      head -n 1 $NAME_FILE_save_id_tweets_from_user > $NAME_FILE_save_id_tweets_from_user.tmp
      mv $NAME_FILE_save_id_tweets_from_user.tmp $NAME_FILE_save_id_tweets_from_user
      like_id $NAME_FILE_save_id_tweets_from_user
      sleep 3
  done < $NAME_FILE_non_follow_back
}

start () {
  clear
  generate_plot
  update_internal_config
  update_refesh_token
  
  if [ $(jq .language $NAME_FILE_config | tr -d '"') == "es" ]; then
    es
  else
    en
  fi
}

es () {
  until [ "${selection}" = "99" ]; do
    clear
    echo ""
    echo "Ahora escribe el número correspondiente para comenzar con el bot de Twitter:" 
    echo ""
    echo ""
    echo "Acciones importantes:"
    echo "1. Unfollow todos los que no te sigan de vuelta"
    echo "2. Follow todos los que hayan dado like a los hashtags recientes del $NAME_FILE_config"
    echo "3. Follow todos los que hayan dado like a los tweets recientes de los usuarios definidos en $NAME_FILE_config"
    echo "4. Dar like a los que no te sigan"
    echo ""
    echo ""
    echo "Acciones generales:"
    echo "5. Obtener una lista de tweets recientes desde los hashtags del $NAME_FILE_config"
    echo "6. Obtener una lista de users que han dado like a los tweets. Usa el archivo del punto 4"
    echo "7. Obtener una lista de tweets recientes de los usuarios definidos en $NAME_FILE_config"
    echo "8. Obtener una lista de users que han dado like a los tweets. Usa el archivo del punto 6" 
    echo "9. Follow todos los ID de $NAME_FILE_save_id_users_from_tweets"
    echo "10. Generar plot. Ejecute y verifique que $DIR_plot tenga el graph.png"
    echo ""
    echo ""
    echo "99. Salir del script. Exit." 
    echo ""
    echo -n "Seleccione una opción [1 - 99]: "
        read selection
        case_versions
  done
}

en () {
  until [ "${selection}" = "7" ]; do
    clear
    echo ""
    echo "Now type the corresponding number to start the Twitter bot:"
    echo ""
    echo ""
    echo "Important Actions:"
    echo "1. Unfollow everyone who doesn't follow you back"
    echo "2. Follow everyone who has liked recent $NAME_FILE_config hashtags"
    echo "3. Follow everyone who has liked the recent tweets of the users defined in $NAME_FILE_config"
    echo "4. Like those who don't follow you"
    echo ""
    echo ""
    echo "General Actions:"
    echo "5. Get a list of recent tweets from the hashtags in $NAME_FILE_config"
    echo "6. Get a list of recent tweets from the users defined in $NAME_FILE_config"
    echo "7. Get a list of users who have liked the tweets. Use the file from point 1"
    echo "8. Get a list of users who have liked the tweets. Use the file from point 2"
    echo "9. Follow all ID from $NAME_FILE_save_id_users_from_tweets"
    echo "10. Generate plot. Run and check $DIR_plot have the graph.png"
    echo ""
    echo ""
    echo "99. Exit script. Exit."
    echo ""
    echo -n "Select an option [1 - 99]: "
        read selection
        case_versions
  done
}

case_versions (){
  case ${selection} in
  1)
    echo ""
    unfollow_non_follow_back $NAME_FILE_non_follow_back
    generate_plot
    sleep 5
  ;;
  2)
    echo ""
    save_id_tweets_from_hashtags
    sleep 3
    save_id_users_from_tweets $NAME_FILE_save_id_tweets_from_hashtags
    sleep 5
    follow_id_bulk $NAME_FILE_save_id_users_from_tweets
    generate_plot
    sleep 5
  ;;
  3)
    echo ""
    save_id_tweets_from_user from_config_file
    sleep 3
    save_id_users_from_tweets $NAME_FILE_save_id_tweets_from_user
    sleep 5
    follow_id_bulk $NAME_FILE_save_id_users_from_tweets
    generate_plot
    sleep 5
  ;;
  4)
    echo ""
    like_non_follow_back
    generate_plot
    sleep 5
  ;;
  5)
    echo ""
    save_id_tweets_from_hashtags
    sleep 3
  ;;
  6)
    echo ""
    save_id_users_from_tweets $NAME_FILE_save_id_tweets_from_hashtags
    sleep 5
  ;;
  7)
    echo ""
    save_id_tweets_from_user from_config_file
    sleep 5
  ;;
  8)
    echo ""
    save_id_users_from_tweets $NAME_FILE_save_id_tweets_from_user
    sleep 5
  ;;
  9)
    echo ""
    follow_id_bulk $NAME_FILE_save_id_users_from_tweets
    generate_plot
    sleep 5
  ;;
  10)
    echo ""
    generate_plot
    sleep 5
  ;;
  99)
    echo "Exit."
  ;;
  *)
  echo "Unrecognized number."
  sleep 2
  ;;
  esac
}

start