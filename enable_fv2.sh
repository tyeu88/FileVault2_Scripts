#!/bin/bash

####################################################################################################
#
# Copyright (c) 2017, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################################
#
# Description
#
# The purpose of this script is to allow the logged in user to enable filevault
# without logging out. This has been modified from the reissuekey script.
# 
#
# First put a configuration profile for FV2 recovery key redirection in place.
# Ensure keys are being redirected to your JSS.
#
# This script will prompt the user for their password so that filevault can
# be enabled using `fdesetup enable`
#
####################################################################################################
#
# HISTORY
#
# -Created by Sam Fortuna on Sept. 5, 2014
# -Updated by Sam Fortuna on Nov. 18, 2014
# -Added support for 10.10
#   -Updated by Sam Fortuna on June 23, 2015
#       -Properly escapes special characters in user passwords
# -Updated by Bram Cohen on May 27, 2016
# -Pipe FV key and password to /dev/null
# -Updated by Jordan Wisniewski on Dec 5, 2016
# -Removed quotes for 'send {${userPass}}     ' so
# passwords with spaces work.
# -Updated by Shane Brown/Kylie Bareis on Aug 29, 2017
# - Fixed an issue with usernames that contain
# sub-string matches of each other.
# -Updated by Bram Cohen on Jan 3, 2018
# - 10.13 adds a new prompt for username before password in changerecovery
# -Updated by Matt Boyle on July 6, 2018
# - Error handeling, custom Window Lables, Messages and FV2 Icon
# -Updated by David Raabe on July 26, 2018
# - Added Custom Branding to pop up windows
# -Updated by Sebastien Del Saz Alvarez on January 22, 2021
# -Changed OS variable and relevant if statements to use OS Build rather than OS Version to avoid errors in Big Sur
# - Modified this script to enable filevault instead of changing the key - Tanya Yeu Feb 2022
####################################################################################################
#
# Parameter 4 = Set organization name in pop up window
# Parameter 5 = Failed Attempts until Stop
# Parameter 6 = Custom text for contact information.
# Parameter 7 = Custom Branding - Defaults to Self Service Icon

## Get the logged in user's name
userName=$(/usr/bin/stat -f%Su /dev/console)

## Grab the UUID of the User
userNameUUID=$(dscl . -read /Users/$userName/ GeneratedUID | awk '{print $2}')

## Get the OS build
BUILD=`/usr/bin/sw_vers -buildVersion | awk {'print substr ($0,0,2)'}`

#Customizing Window

selfServiceBrandIcon="/Users/${userName}/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
jamfBrandIcon="/Library/Application Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns"
fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"
windowTitle="Enable Filevault"

if [ ! -z "$4" ]
then
orgName="$4 -"
fi

if [ ! -z "$6" ]
then
haltMsg="$6"
else
haltMsg="Please contact Team WPT for Further assistance."
fi

if [[ ! -z "$7" ]]; then
brandIcon="$7"
elif [[ -f $selfServiceBrandIcon ]]; then
  brandIcon=$selfServiceBrandIcon
elif [[ -f $jamfBrandIcon ]]; then
  brandIcon=$jamfBrandIcon
else
brandIcon=$fileVaultIcon
fi


## Counter for Attempts
try=0
if [ ! -z "$5" ]
then
maxTry=$5
else
maxTry=2
fi

passwordPrompt () {
## Get the logged in user's password via a prompt
echo "Prompting ${userName} for their login password."
userPass=$(/usr/bin/osascript -e "
on run
display dialog \"Enable Filevault\" & return & \"Enter login password for '$userName'\" default answer \"\" with title \"$orgName ${windowTitle}\" buttons {\"Cancel\", \"Ok\"} default button 2 with icon POSIX file \"$brandIcon\" with text and hidden answer
set userPass to text returned of the result
return userPass
end run")
if [ "$?" == "1" ]
then
echo "User Canceled"
exit 0
fi
try=$((try+1))
if [[ $BUILD -ge 13 ]] &&  [[ $BUILD -lt 17 ]]; then
## This "expect" block will populate answers for the fdesetup prompts that normally occur while hiding them from output
result=$(expect -c "
log_user 0
spawn fdesetup enable
expect \"Enter a password for '/'\"
send {${userPass}}   
send \r
log_user 1
expect eof
" >> /dev/null)
elif [[ $BUILD -ge 17 ]]; then
result=$(expect -c "
log_user 0
spawn fdesetup enable
expect \"Enter the user name:\"
send {${userName}}   
send \r
expect \"Enter the password for '/'\"
send {${userPass}}   
send \r
log_user 1
expect eof
")
else
echo "OS version not 10.9+ or OS version unrecognized"
echo "$(/usr/bin/sw_vers -productVersion)"
exit 5
fi
}

successAlert () {
/usr/bin/osascript -e "
on run
display dialog \"\" & return & \"Filevault successfully enabled\" with title \"$orgName ${windowTitle}\" buttons {\"Close\"} default button 1 with icon POSIX file \"$brandIcon\"
end run"
}

errorAlert () {
 /usr/bin/osascript -e "
on run
display dialog \"FileVault not enabled\" & return & \"$result\" buttons {\"Cancel\", \"Try Again\"} default button 2 with title \"$orgName ${windowTitle}\" with icon POSIX file \"$brandIcon\"
end run"
 if [ "$?" == "1" ]
  then
echo "User Canceled"
exit 0
else
try=$(($try+1))
fi
}

haltAlert () {
/usr/bin/osascript -e "
on run
display dialog \"FileVault not enabled\" & return & \"$haltMsg\" buttons {\"Close\"} default button 1 with title \"$orgName ${windowTitle}\" with icon POSIX file \"$brandIcon\"
end run
"
}

fvOnAlert (){
    /usr/bin/osascript -e "
    on run
    display dialog \"Filevault already enabled\" & return & \"No action required.\" buttons{\"Close\"} default button 1 with title \"$orgName ${windowTitle}\" with icon POSIX file \"$brandIcon\"
    end run
    "
}

## Check to see disk is already encrypted
encryptCheck=`fdesetup status`
statusCheck=$(echo "${encryptCheck}" | grep "FileVault is On.")
expectedStatus="FileVault is On."
if [ "${statusCheck}" == "${expectedStatus}" ]; then
echo "${encryptCheck}"
fvOnAlert
exit 0
fi

while true
do
passwordPrompt
if [[ $result = *"Error"* ]]
then
echo "Error enabling Filevault"
if [ $try -ge $maxTry ]
then
haltAlert
echo "Quitting.. Too Many failures"
exit 0
else
echo $result
errorAlert
fi
else
echo "Successfully enabled Filevault"
successAlert
exit 0
fi
done
