#!/bin/bash

#again new text
#this is the new version
#variables 
bucket=0
key=0
uploadid=0
etag=0
etagfile=etagfile
part=1
file=$1
bucket=$2


if [ $# -ne 2 ]
then
	echo "usage: mpup.sh <file> <bucket>"
	exit
fi
#get md5
md5=$(openssl md5 -binary $file | base64)

#remove old sessions
rm partfile*
echo "partfiles removed"
echo "..."

#split file
split -b 5m $file partfile
echo $file split in 5MB parts
echo "..."

#create mpupload
uploadid=$(aws s3api create-multipart-upload --bucket $bucket --key $file --metadata md5=$md5|grep -i uploadid|awk -F\" '{print $4}')
#aws s3api create-multipart-upload --bucket $bucket --key $file --metadata md5=$md5

#upload parts
part=1
parts=$(ls partfile*|wc -l|awk '{print $1}')
ls partfile*
echo -n press enter to start uploading $parts parts :
read
for i in partfile*
do
   aws s3api upload-part --bucket $bucket --key $file --part-number $part --body $i --upload-id $uploadid > /dev/null 
   echo "uploaded $part in background"
   ((part+=1))
done

#list parts
aws s3api list-parts --bucket $bucket --key $file --upload-id $uploadid|grep ETag|awk -F\" '{print $5}' > listedparts
#remove characters
sed -i -e 's/\\$//' listedparts
parts=$(wc -l listedparts|awk '{print $1}')

#create partsfile
echo { > etagfile
echo \"Parts\": [ >>etagfile
#initialize variable part
part=1

for i in $(cat listedparts)
do
	echo \{ >> $etagfile
        echo \"PartNumber\": $part\, >> $etagfile
        echo \"ETag\": \"${i}\" >> $etagfile
 	if [ $part -eq $parts ]
	then echo \} >> $etagfile
             echo \] >> $etagfile
	     echo \} >> $etagfile
	else
	     echo \}\, >> $etagfile
        ((part+=1))
	fi
done

#complete the upload
echo "completing the upload"
aws s3api complete-multipart-upload --multipart-upload file://$etagfile --bucket $bucket --key $file --upload-id $uploadid

