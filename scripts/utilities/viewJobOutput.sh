for f in ~/lsf_jobs/*; 
    do
        if [ -s "$f" ]
        then
            echo ""; 
            echo "--- $f ---"; 
            cat $f;
            jobID=`basename "$f" | awk -F "_" '{print $2}' | awk -F "." '{print $1}'`
        fi
done;

