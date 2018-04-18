#!/bin/bash

# icon-hooks.sh
#
# Copyright (C) 2014,2015 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2
#
# KDesk Icon Hooks script - Dynamically update the desktops icons attributes.
#
# You can debug this hook script manually like so:
#
#  $ icon-hooks "myiconname" debug

# Copyright (C) 2016 Alfabook srl
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2
# rebadged with microninja

# we capture errors so we return meaningul responses to kdesk
set +e

# We don't care about case sensitiveness for icon names
shopt -s nocasematch

# collect command-line parameters
icon_name="$1"
if [ "$2" == "debug" ]; then
    debug="true"
fi

# Name of pipe for Kano Notifications desktop widget
pipe_filename="$HOME/.kano-notifications.fifo"

# default return code
rc=0

case $icon_name in

    "profile")
    exit 1
    # Ask kano-profile for the username, experience and level,
    # Then update the icon attributes accordingly.
    IFS=$'\n'
    kano_statuses=`kano-profile-cli get_stats`
    apirc=$?

    # Uncomment me to debug kano profile API
    if [ "$debug" == "true" ]; then
        echo "Received hook call for $icon_name, updating attributes.."
        printf "Kano Profile API returns rc=$apirc, data=\n$kano_statuses\n"
    fi

    for item in $kano_statuses
    do
        eval line_item=($item)
        case ${line_item[0]} in
            "mixed_username:")
                username=${line_item[1]}
                ;;
            "level:")
                level=${line_item[1]}
                ;;
            "progress_image_path:")
                progress_file=${line_item[1]}
                ;;
            "avatar_image_path:")
                avatar_file=${line_item[1]}
                ;;
        esac
    done

    if [ "$debug" == "true" ]; then
        echo -e "\nReturning attributes to Kdesk:\n"
    fi

    # Uncomment line below to test your own username
    #username="My Long Username"

    # Update the message area with username and current level
    msg="$username|Level $level"
    if [ "$username" != "" ] && [ "$level" != "" ]; then
        printf "Message: {90,38} $msg\n"
    fi

    # Update the icon with user's avatar and experience level icon
    if [ "$progress_file" != "" ]; then
        printf "Icon: $progress_file\n"
    fi

    if [ "$avatar_file" != "" ]; then
        printf "IconStamp: {13,13} $avatar_file\n"
    fi

    # Evaluate the quests notification icon
    num_quests=`kano-profile-cli fulfilled_quests_count`
    numbers_path="/usr/share/kano-desktop/images/world-numbers"
    if [ $num_quests -gt 0 ] && [ $num_quests -lt 10 ]; then
        num_file="$numbers_path/${num_quests}.png"
    elif [ $num_quests -gt 9 ]; then
        num_file="$numbers_path/9-plus.png"
    else
        num_file=""
    fi
    printf "IconStatus: {190,53} $num_file"
    ;;


    "world")
        exit
        IFS=$'\n'
        # Returns if online, prints notification count and stats activity
        info=`kano-profile-cli get_world_info`
        apirc=$?

        if [ "$debug" == "true" ]; then
            printf "Kano Profile API returns rc=$apirc, data=\n$info\n"
        fi

        msg1="Kano World"
        icon="/usr/share/kano-desktop/icons/kano-world-launcher.png"

        # Uncomment line below to test your own notifications
        #info="notifications_count: 18"

        # Online / Offline status message
        if [ "$apirc" == "0" ]; then
            notification_icon="/usr/share/kano-desktop/images/world-numbers/minus.png"
            msg2="SIGN UP"
        else
            # We are online, get how many notifications are on the queue and the activity stats
            notification_icon=""
            msg2="ONLINE"
            for item in $info
            do
                eval line_item=($item)
                case ${line_item[0]} in
                    "notifications_count:")
                        # Extract numbers only - Any string will become 0 which means no notifications.
                        notifications=$(printf "%d" ${line_item[1]})
                        if [ $notifications -lt 10 ] && [ $notifications -gt 0 ]; then
                            notification_icon="/usr/share/kano-desktop/images/world-numbers/${notifications}.png"
                        elif [ $notifications -gt 9 ]; then
                            notification_icon="/usr/share/kano-desktop/images/world-numbers/9-plus.png"
                        fi
                        ;;
                    "total_active_today:")
                        msg2=$(printf "%d ONLINE" ${line_item[1]})
                        ;;
                esac
            done
        fi

        # Update the icon with the values
        printf "Icon: $icon\n"
        printf "Message: {75,38} $msg1|$msg2\n"
        printf "IconStatus: {30,53} $notification_icon\n"
        ;;


    "ScreenSaverStart")
    exit 1
        # By default we let the screen saver kick in
        if [ "$debug" == "true" ]; then
            echo "Received hook for Screen Saver Start"
        fi
        rc=0

        # disable Notifications Widget alerts momentarily until the screen saver stops
        if [ -p "$pipe_filename" ]; then
            echo "pause" >> $pipe_filename
        fi

        #
        # Search for any programs that should not play along with the screen saver
        # process names are pattern matched, so kano-updater will also find kano-updater-gui.
        IFS=" "
        non_ssaver_processes="kano-updater kano-xbmc xbmc.bin minecraft-pi omxplayer"
        for p in $non_ssaver_processes
        do
            isalive=`pgrep -f "$p"`
            if [ "$isalive" != "" ]; then
                if [ "$debug" == "true" ]; then
                    echo "cancelling screen saver because process '$p' is running"
                fi
                rc=1
                break
            fi
        done

        if [ "$rc" == "0" ]; then

            if [ "$debug" == "true" ]; then
                echo "starting kano-sync and checking for updates"
            fi
            kano-sync --skip-kdesk --sync --backup --upload-tracking-data -s &
            sudo /usr/bin/kano-updater download --low-prio &
        fi
        ;;

    "ScreenSaverFinish")
        exit 1
        if [ "$debug" == "true" ]; then
            echo "Received hook for Screen Saver Finish"
        fi

        # re-enable notifications widget UI alerts so they popup on the now visible Kano Desktop
        if [ -p "$pipe_filename" ]; then
            echo "resume" >> $pipe_filename
        fi

        # kanotracker collects how many times and for long the screen saver runs
        length=$2
        now=$(date +%s)
        started=$(expr $now - $length)
        kano-tracker-ctl session log screen-saver $started $length
        ;;

    *)
    echo "Received hook for icon name: $icon_name - ignoring"
    ;;
esac

if [ "$debug" == "true" ]; then
    echo "Icon hooks returning rc=$rc"
fi

exit $rc
