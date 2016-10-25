#!/bin/bash  
#
# I probably need a GPL license header here...
#
# The script currently prints out the result on the command line

#SMP Username and password
#SMP_USER=S0012345678
#SMP_PASS=mys3creTPW
SMP_USER=
SMP_PASS=

#we should add a check that prevents script execution, if user and password are missing
# if SMP_USER or SMP_PASS is empty
#   notify user and abort execution

#URL to fetch information from (SAP Service Marketplace)
NOTES_URL='https://service.sap.com/sap/support/notes'

#Proper Post data for BC-OP-LNX-SUSE componenet and 7-day filter
POST_DATA='_APP=00200682500000001952&_EVENT=RESULT&00200682500000000719=OW1&00200682500000001280=7&00200682500000004878=00&00200682500000004914=E&00200682500000004915=AND&00200682500000004916=ALL&00200682500000004918=10&00200682500000004919=0&00200682500000004920=BC-OP-LNX-SUSE*&00200682500000004932=1&00200682500000005040=NO_RESTRICTION&00200682500000005063=NO_RES&00200682500000005447=L&00200682500000005448=NO&00200682500000005464=TRUE&00200682500000005465=TRUE&00200682500000005466=TRUE&00200682500000005467=FALSE&00200682500000005468=FALSE&01100107900000000030=NEW&NAMESPACE_SEARCH=NO_SEA&SEARCH_AREA=BC-OP-LNX-SUSE*&TEMP_SEARCH=last7'

#Required for email notification - maybe enabled later
#MAIL_TARGET='<name@email.com>'
#SUBJECT='Updated Notes E-Mail'

ERROR='0'

# in case you need to have a proxy set
#export https_proxy='http://your.proxy.com:8080'


# wget gets redirected to active server, something like WEBSMP204.SAP-AG.DE
rc=$(wget "https://service.sap.com/notes" --no-check-certificate 2>&1)
SERVER=$(echo "$rc" | grep ^Location: | awk -F/ {' print $3 }')

if [ -z "$SERVER" ]; then  
	ERROR="Server could not be determined"
	formatted_result="***** wget output for debugging *****
$rc" 
fi

# Fetching the information from SMP
if [ "$ERROR" = "0" ]; then
	html=$(wget -O - --quiet \
		--user="$SMP_USER" \
		--password="$SMP_PASS" \
		"https://$SERVER/~form/handler"\
		--post-data="$POST_DATA")
	
	searchresult=$(echo "$html" \
	| grep '^[[:space:]]*<TD CLASS="result-line"' \
	| grep -vE '/STRONG>|/SMALL>' \
	| awk -F\> '{ print $3 }' \
	| perl -npe 's@([[:space:]]+)@ @m; s@</A@@; s@&quot;@\"@g')

	# searchresult should now be something like that:
	#  300900 Linux: Available DELL hardware
	#  1021236 Linux: Using SAP Kernel 7.01 and higher on RHEL4 and SLES9
	#  1400911 Linux: SAP on KVM - Kernel-based Virtual Machine

	if [ -z "$searchresult" ]; then
	    # if there are no changed notes, the html will contain
	    # <TD CLASS="numberofnotes"><H3 CLASS="note">0 SAP-Hinweise gefunden</H3></TD>
	    # or
	    # <TD CLASS="numberofnotes"><H3 CLASS="note">0 SAP Notes found</H3></TD>
		# depending on the language setting
	    if echo "$html" | grep numberofnotes | grep -qE '>0 SAP-Hinweise|>0 SAP Notes'; then
		ERROR="no updated notes"
		SUBJECT="No ${SUBJECT}"
		formatted_result="No Notes were updated the last 7 days."
	    else
		ERROR="searchresult empty"
		formatted_result="***** html from post for debugging *****
$html"
	    fi
	fi
fi

# if you want to debug, uncomment this echo
#echo $formatted_result

# check and format
if [ "$ERROR" = "0" ]; then
	echo "$searchresult" | while read notenumber title; do
#		check if notenumber numeric and title not empty
		if ! [ $notenumber -eq $notenumber ]; then exit 1; fi
		if [ -z "$title" ]; then exit 1; fi
	done
	if [ $? -ne 0 ]; then ERROR="searchresult bad format"; fi
	formatted_result=$(echo "$searchresult" \
	| sed 's/&quot;/"/g; s/&lt;/</g; s/&gt;/>/g' \
	| sort -n \
	| while read notenumber title; do
		printf "%10d %s\n           ${NOTES_URL}/${notenumber}\n\n" $notenumber "$title"
	done)
else
	echo $ERROR
fi

# print the list on the console
echo ${formatted_result}


#the next section would be something for further enhancement

#
# email notification
# 

# if an error occurred, send ERROR to a dedicated email address
#if [ "$ERROR" != "0" -a "$ERROR" != "no updated notes" ]; then
#	MAIL_TARGET='<name@email.com>'
#	SUBJECT="ERROR in updatednotes.sh"
#fi

#date=$(/bin/date +'CW%V / %G')

# for local debugging
#echo SERVER:${SERVER}
#echo MAIL TARGET:${MAIL_TARGET}
#echo SUBJECT:${SUBJECT}
#echo date:${date}
#echo ERROR:${ERROR}
#printf "searchresult:\n${searchresult} \n"
#printf "formatted result:\n${formatted_result} \n"
# 
#exit

#/usr/sbin/sendmail -f name@email.com "${MAIL_TARGET}" <<MAIL 
#From: 
#To: ${MAIL_TARGET}
#Subject: ${SUBJECT} - ${date}
#Content-Type: text/plain; charset=ISO-8859-15
#Content-Transfer-Encoding: 8bit
#
#Text ... [...] 
#
#${formatted_result}
#
#
#MAIL

#
# Twitter ?
#

#is there a command line tool to tweet?
