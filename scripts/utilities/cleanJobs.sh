echo "removing jobs"
export user=`eval whoami`
bkill -u ${user} 0
echo "cleaning lsf_jobs folder..."
rm ~/lsf_jobs/* 2> /dev/null
echo "cleaning up scratch folder..."
rm -rf ~/scratch/cWorld__*__*__*

if [[ $user = "bl73w" ]]
then
    dos2unix ~/cMapping/*/mapReduce/* 2> /dev/null
    chmod 750 ~/cMapping/*/mapReduce/*
    dos2unix ~/cMapping/*/sortMapReduce/* 2> /dev/null
    chmod 750 ~/cMapping/*/sortMapReduce/*
    dos2unix ~/cMapping/*/scripts/* 2> /dev/null
    chmod 750 ~/cMapping/*/scripts/*
fi

