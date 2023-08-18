#!/bin/bash 

# Read a file in your working directory for variables, if it exists
source mastodon_vars.txt

# Dictionary
declare -A mastodonOpts

# Only run this part if script has never been run before
if [[ ! -f ${workDir}/.mastodon_script_has_run ]]; then

    # Silently clear up old variable file 
    rm -f ${workDir}/mastodon_vars.txt

    # Intro message
    echo -e "\nGreetings!  This script will change your Mastodon instance's character limit to a setting that you desire."
    echo "This script assumes you are running the entire Mastodon Docker container suite."
    echo "This script will also optionally update your Elasticsearch index for those instances that have full text search enabled."
    echo "Once the character limit has been updated (and optional Elastic container has been provided), all containers will restart."

    # Set and move into the working directory
    echo -e -n "\n\nWhat is your working directory for this script? "
    read -r mastodonOpts[workDir]
    echo -e "\nMoving into working directory..."
    cd "${mastodonOpts[workDir]}"

    # Ask for Web image name
    echo -e -n "\nWhat is your Mastodon Web docker container's name? "
    read -r mastodonOpts[dockName]

    # Ask for Streaming image name
    echo -e -n "\nWhat is your Streaming API docker container's name? "
    read -r mastodonOpts[streamName]

    # Ask for Sidekiq image name
    echo -e -n "\nWhat is your Sidekiq docker container's name? "
    read -r mastodonOpts[sidekiqName]

    # Ask for new character limit
    echo -e -n "\nWhat would you like to set the new character limit to? "
    read -r mastodonOpts[charLimit]

    # Ask if they have an Elasticsearch configured for their Mastodon instance 
    echo -e -n "\nDo you have full text search enabled on your instance? (y/n)" 
    read -r mastodonOpts[elasticYesNo]

    # Create a file in the working directory that stores the dictionary key value pairs as bash readable variables
    touch ${mastodonOpts[workDir]}/mastodon_vars.txt
    for i in "${!mastodonOpts[@]}"
    do
        echo "$i=${mastodonOpts[$i]}" >> ${mastodonOpts[workDir]}/mastodon_vars.txt
    done

    # Create empty file that tells script it has been run before
    touch ${mastodonOpts[workDir]}/.mastodon_script_has_run
fi

# Variable to check to see if character limit is stock
charCur='$(docker exec -it $dockName grep "500\b" /opt/mastodon/app/javascript/mastodon/features/compose/components/compose_form.js)'

# If charCur returns a value...
if [[ -n "$charCur" ]]; then

    # If Elastic is configured, update the Elastic index first
    if [[ "$elasticYesNo" == "y" || "$elasticYesNo" == "Y" ]]; then
        docker exec -it "$dockName" tootctl search deploy
    fi

    # Change the character limit, recompile inside of the docker container, then reload all containers
    docker exec -it "$dockName" sed -i "s/500\b/$charLimit/g" /opt/mastodon/app/javascript/mastodon/features/compose/components/compose_form.js
    docker exec -it "$dockName" sed -i "s/500\b/$charLimit/g" /opt/mastodon/app/validators/status_length_validator.rb
    docker exec -it "$dockName" bundle exec rails assets:precompile
    docker container restart "$dockName" "$streamName" "$sidekiqName"
else
    if [[ "$elasticYesNo" == "y" || "$elasticYesNo" == "Y" ]]; then
        docker exec -it "$dockName" tootctl search deploy
        docker container restart "$dockName" "$sidekiqName"
    fi
    echo "Your container's character limit has already been changed.  Skipping..."
fi
