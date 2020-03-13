#! /bin/bash
# this script is used to help the king to see the relatives of his families and objects clearly

ROOT=`pwd`
WORKDIR="$ROOT/`cat info.json |jq -r .default_work_dir`"
INFO="`pwd`/info.json"
BACKUP="$ROOT/`cat info.json | jq -r .back_up_dir`"
HEIGHT_CHOOSE=200 
WIDTH_CHOOSE=400
HEIGHT_INFO=100
WIDTH_INFO=300

function addFALSE()      # $* to add FALSE for list
{
	for i in $*
	do	
		echo "FALSE $i "
	done
}

function moveFiles()        # move file to another dir 
{
    local files=$(chooseFile)
    local dir=$(chooseDir "please choose dir you want to move to: ")
    if [ "$dir" ] && [ "$files" ];then #dir and files are not blank 
        cd $WORKDIR
        mv $files $dir
        if [ !$? ];then zenity --info --text "succeed!"
        cd $ROOT    
        fi
    fi

}

function chooseDir()  #use to select a dir want to operate or create a new dir
{
    cd $WORKDIR
    choice=$(zenity --list --radiolist --column "" --column "names" TRUE ".." `addFALSE $(ls)` --height=200 --width=400 --title "`pwd`" --text "$*" --separator=" " --extra-button="choose here" --ok-label="open" --extra-button="create a dir" --extra-button="path")
    while [ "$choice" != "choose here" ] && [ "$choice"  ] && [ "$choice" != "path" ]; do   #that mean that you select a dir to open
        if [ -d "$choice" ];then  # you choose a dir not a file
            cd $choice
        elif [ "$choice" == "create a dir" ];then  #you want to create a new dir here
            choice=$(zenity --entry --title "create a new dir here" --text "please input the dir name you want to create, ensure the name should not with Space or Enter")
            if [ ! -d $choice ];then    #the dir not exist
                mkdir $choice
                chmod 700 $choice
                cd $choice 
            fi
        else  # you choose a file ,which is not allowed
            zenity --warning --text "please choose a dir , not a file" --height=100 --width=200
        fi
        choice=$(zenity --list --radiolist --column "" --column "names" TRUE ".." `addFALSE $(ls)` --height=200 --width=400 --title "`pwd`" --text "please choose a dir" --separator=" " --extra-button="choose here" --ok-label="open" --extra-button="create a dir") 
    done
    if [ "$choice" == "choose here" ];then  #you choose a dir
        echo `pwd`
    elif [ "$choice" == "path" ];then
        choice=$(zenity --entry --title "path" --text "please input the dir path")
        if [ -d $choice ];then
            echo $choice
        else
            zenity --warning --title "failed!" --text "invalid path"
        fi
    fi
    cd $ROOT
}

function chooseFile()     #choose some files that you want to operate  $1 is file path if no ,default workdir
{
    if [ "$1" ];then
        cd $1
    else
        cd $WORKDIR
    fi
    echo $(zenity --list --checklist --column "" --column "names" FALSE "*" `addFALSE $(ls)` --height=200 --width=400 --title "`pwd`" --text "please choose files" --separator=" ")
    cd $ROOT
}

function changeWorkingDir()  # change the default working dir
{
    local direct=$(chooseDir "please choose another dir as the working dir" | awk -F'shell_project/' '{print $2}')
    if [ "$direct" ];then
        sed -i "2 s!`jq -r .default_work_dir $INFO`!$direct!g"  $INFO
        WORKDIR="$ROOT/$direct"
        if [ "`ls -l -d $WORKDIR | awk '{print $1}'`" != "drwx------." ];then
            zenity --warning --text "the dir mode is illegel"  --width=$WIDTH_INFO
        fi
        chmod 700 $WORKDIR
        zenity --info --text "working dir changed"
    else
        zenity --warning --text "you can only choose dir below database , sorry!" --width=$WIDTH_INFO
    fi
}

function manualBackUp()          #manual back up some files to here or certain dir
{
    zenity --info --text "please choose files you want to back up" --width=$WIDTH_INFO
    local files=$(chooseFile)       #choose files to go to
    cd $WORKDIR
    choice=$(zenity --info --text "do you want to back up to certain place or here?" --height=$HEIGHT_INFO --width=$WIDTH_INFO --extra-button="choose a dir" --ok-label="exit" --extra-button="here") 
    if [ "$choice" == "here"  ];then       #back here
        tar -zcvf  "`date +%y%m%d%H`.tar.gz"  $files
    elif [ "$choice" == "choose a dir" ];then          #back to path
        local path=$(chooseDir "please choose a dir you want to back up to")
        tar -zcvf "$path/`date +%y%m%d%H`.tar.gz" $dir
    fi
    cd $ROOT
}

#################################
#load data about

function loadInData()
{
    choice=$(zenity --info --extra-button="add from a dir" --extra-button="add from a tar" --extra-button="type to create" --ok-label="exit" --title "add data" --text " which method do you want to use ?" --width=$WIDTH_CHOOSE)
    local from_dir
    local to_dir
    case "$choice" in
        "add from a dir" )
            from_dir=$(chooseDir "please choose where the files from")
            to_dir=$(chooseDir "please choose where the files will move to")
            fromDir $from_dir $to_dir        #move files to dir
        ;;
        "add from a tar")
            from_dir=$(chooseDir "please choose where the tar is") 
            local file=$(chooseFile $from_dir)
            to_dir=$(chooseDir "please choose where the files will move to")
            mkdir "$to_dir/.tmp"
            cd $from_dir  #cd to the target dir for next operations
            cp "$file" "$to_dir/.tmp"  #copy the tar to a temp dir for operate
            cd "$to_dir/.tmp"
            for i in `ls`          # to extract all the tar file
            do
                if [ -d $i ];then  #if there have 
                    rm -rf $i 
                fi
                tar -xf $i  #extract here
                rm -f $i  #delete the tar
            done
            fromDir $to_dir/.tmp $to_dir
            rm -rf "$to_dir/.tmp"
        ;;
        "type to create" )
            to_dir=$(chooseDir "where do you want to add the file to? ")
            output=$(zenity --forms --add-entry="name" --add-entry="sex" --add-entry="couples(1,2,3)" \
            --add-entry="family" --add-entry="children(1,2,3)" --add-entry="maintitle" --add-entry="titles(\"A\",\"B\",\"C\")" --separator="%" --title "record create" --text "please input the infomations, and you can leave it blank if you want" --width=400 height=600 )
            cd $to_dir
            file=$(mkfile)
            sed -i "s/_name/$(awk -F% '{print $1}' <<<$output )/g"  $file
            sed -i "s/_sex/$(awk -F% '{print $2}' <<<$output )/g"  $file
            sed -i "5 s/]/$(awk -F% '{print $3}' <<<$output )&/g"   $file
            sed -i "s/_family/$(awk -F% '{print $4}' <<<$output )/g"  $file
            sed -i "7 s/]/$(awk -F% '{print $5}' <<<$output )&/g"   $file
            sed -i "s/_maintitle/$(awk -F% '{print $6}' <<<$output )/g" $file
            sed -i "9 s/]/$(awk -F% '{print $7}' <<<$output )&/g"   $file
        ;;
        * )
        ;;
    esac
    cd $ROOT
}

function fromDir()  #load in data from a dir ;$1 is file_froms $2 is file_to
{
    cd $1
    local files="`find . -type f`"  #find all files need to be moved
    files=$(checkName $files)  # return full path
    local comflict=$(checkComflict $files)  #check comflicts and return file names

    if [ "$comflict" ];then  #comflict appear
        choice=$(zenity --info --title "comflict!" --text "some comflicts occured, do you want to replace all the old files with the new?" --extra-button="replace" --ok-label="back" --extra-button="keep the old" --width=$WIDTH_INFO)
        case "$choice" in
            "replace" )
                deleteFile $comflict         #delete the old files
                mv ./* $2
                addID2Info $files
            ;;
            "keep the old" )
                find . -name "$comflict" -type f -exec rm -f {} \;  #delete the new files 
                mv ./* $2
                addID2Info $files
            ;;
            *)
            ;;
        esac     
    fi
    cd $ROOT
}

function checkComflict()  # to check if conflict appears  $*is the files that are checked
{
    for i in $@    
    do  
        local comflict=`cat $INFO | jq -r .id_used[] | grep "$(cat $i| jq -r .id)"`    #id comflict
        if [ "$comflict" ];then
            echo "$(cat $i| jq -r .id).json"     #return the comflict file name
        fi
    done
}

function deleteFile()  # delete the file in the database
{
    for i in $@
    do
        find "$ROOT/database" -name "$i" -type f -exec rm -f  {} \; 
    done
}

function checkName()   #to check if the name is standard $* is the name of files
{
    for i in $@
    do
        local name="`cat $i | jq -r .id`.json"
        if [  "$name" != `echo $i | awk -F/ '{print $NF}'` ];then
            mv $i $name
            echo $name
        else
            echo $i
        fi
    done
}

function addID2Info()       #add new id  to info.json
{
    for i in $@
    do
        i=`echo $i | awk -F/ '{print $NF}'`
        sed -i "4 s/]/,${i:0:1}&/" $INFO
    done
}

function mkfile()         #create a file
{
    local id=$(expr `cat $INFO | jq -r .id_used[] | sort -n -r | head -1` + 1)
    touch $id.json 
    echo -e "{\n\t\"name\":\"_name\",\n\t\"id\":_id,\n\t\"sex\":\"_sex\",\n\t\"couples\": [],\n\t\"family\":\"_family\",\n\t\"children\":[],\n\t\"maintitle\":\"_maintitle\",\n\t\"titles\":[]\n}" > $id.json
    sed -i "s/_id/$id/g" $id.json
    sed -i "4 s/]/,$id&/g" $INFO
    echo $id.json
}

function restore()   #use to restore files you enter
{
    cd $ROOT
    local file=$(zenity --entry --title "file name" --text "please input the file names you want to restore")
    choice=$(zenity --info --extra-button="from auto back tar" --extra-button="from another tar" --extra-button="restore whole database" --title "restor guide" --text "which way do you want to use" --ok-label="back" )
    if [ "$choice" == "from auto back tar" ];then                # restore from auto
        local backsource=".backup/auto_back.tar.gz"
        cd .backup
        for i in $file
        do 
            i=$(tar -ztf "auto_back.tar.gz" | grep $i | head -1) #search for file
            if [ "$i" ];then
                tar -zxvf "auto_back.tar.gz" $i              #untar a file and move to work dir
                mv $i $WORKDIR
            fi
        done
    elif [ "$choice" == "from another tar" ];then                #restore from another tar
        local backsource=$(zenity --entry --text "please input the source tar full path" --title "enter path")
        cd `echo $backsource | awk -F/ '{$NF="";print $0}'|sed 's/ /\//g'`  
        for i in $file
        do
            i=$(tar -tf "$backsource"|grep $i | head -1)
            if [ "$i" ];then
                tar -xvf "$backsource" $if
                mv $i $WORKDIR
            fi
        done

    elif [ "$choice" == "restore whole database"];then       #to restore the whole database for your don't know which file you want to restore
        tar -zcvf ".backup/database.bak.tar.gz" "database"
        rm -rf "database"
        cp ".backup/auto_back.tar.gz" .
        tar -zxvf "auto_back.tar.gz"
        rm -f "auto_back.tar.gz" 
    fi
    cd $ROOT

}

#############################################
#family about

function searchFamily()  #search one person's family name
{
    choice=$(zenity --entry --title "search" --text "id or name:")
    if [ "$choice" -gt 0 ] 2>/dev/null ;then  #check id or name
        echo "id: $choice: family: "
    else
        echo "name: $choice: family: "
        choice=$(jq -r .id `findFile $choice`)   #change name to id
    fi
    local family_name=$(searchFamily_recursion $choice)      #find family name recursively
    if [ "$family_name" == "null" ];then          #can't known the family
        family_name="Unknown"
    fi
    zenity --info --title "result" --text "$choice 's family is [$family_name]"
}

function searchFamily_recursion()   #to search one person's family name recursively; $1 is the search person's ID 
{
    family=$(jq -r .family $(grep $1 `find database -type f` | grep "id" | awk -F: '{print $1}'))
    if [ "$family" ] && [  "$family" != "null" ] ;then
        echo $family
    else
        for i in $(grep $1 `find database -type f` | grep children |awk -F: '{print $1}')  #find parents's file path
        do
            if [ "`jq -r .sex $i`" == "male" ];then
                searchFamily_recursion `jq -r .id $i`  
            fi
        done
    fi
}

function all_family()    #create a family dir at database
{
    cd "$ROOT/database"
    if [ ! -d ".family" ];then        #create family dir
        mkdir ".family"
    fi
    cd ".family"
    touch ".tmp"   #a temp file that used to record if one person has been added
    touch "wildman"     #create wildman file
    if [ ! -d ".illegel_child" ];then
        mkdir ".illegel_child"  #create illegel_child dir
    fi
    touch ".illegel_child/bastard"    #create file
    for i in `jq -r .id_used[] $INFO`
    do
        add_family $i
    done
    for i in `ls`
    do
        sort $i -n -k 1 -o $i   #sort all file as decrease
    done

    cd ".illegel_child"  #to operate bastard file
    sort "bastard" -n -k 1 -o "bastard"
    touch "bsd.base64" && base64 "bastard" > "bsd.base64" && rm -f bastard      #base64
    line=$(echo "($(cat bsd.base64 |wc -l)-0.5)/10+1" | bc)   
    split "bsd.base64" -l $line -d -a 2 "bsd_" && ls | grep "bsd_" | xargs -n1 -i{} mv {} {}.base64 && rm -f "bsd.base64"  #split
    ls | grep "bsd_"| xargs tar -zcvf "bsd.tar.gz" --remove-files   #tar
    cd ..
    zenity --info --title "family dir created!" --text "the family dir path is \" `pwd`\" " --width=$WIDTH_INFO

    cd $ROOT
}

function add_family()   #add one person to family  $1 is id  $2 is dadfamily
{
    if [ ! "`grep "[$1]" .tmp`" ];then             #the person has not been added
        file=$(findFile $1)
        local fml=$(jq -r .family $file)
        if [ "$fml" ] && [ "$fml" != "null" ]; then   #family is known
            touch "$fml"             # create a family file
            echo -e "$(jq .id $file)  $(jq -r .name $file)"  >>$fml
            if [ "$(jq -r .sex $file)" == "male" ];then         #for male recurse to add
                for i in `jq -r .children[] $file`
                do
                    add_family $i $fml      
                done
            fi
            if [ "$fml" != "$2" ] && [ "$2" ];then             #maybe illegel child
                echo -e "$(jq .id $file)  $(jq -r .name $file)"  >>".illegel_child/bastard"    
            fi
        elif [ "$2" ] ;then            #dadfamily known
            echo -e "$(jq .id $file)  $(jq -r .name $file)" >>$2
            if [ "$(jq -r .sex $file)" == "male" ]; then
                for i in `jq -r .children[] $file`
                do
                    add_family $i $2       #$i is the id of his child ;$2 is dadfamily ; recursion
                done
            fi
        else          #wildman
            echo -e "$(jq .id $file)  $(jq -r .name $file)" >>"wildman"
        fi
        echo "[$1] " >>.tmp              #add to .tmp file for he has been added
    fi
}

function findFile()      # $* is the str or id;  echo path
{
    if [ "$1" -gt 0 ] 2>/dev/null ;then 
        echo $(find $ROOT/database -name "$1".json)        #num
    else
        echo $(grep "$*" `find $ROOT/database -type f` | grep "$*" | awk -F: '{print $1}')   #str
    fi
}

############################################
#succeed about

function succeedOut()       # succeed out recursively ,and $1 is id  $@ is titles 
{
    if [ ! "`grep [$1] .tmp`" ];then
        local titles=($(_titles $1 $(echo $@ | awk '{$1="";print $0}')) )  #all titles can be succeed
        local title_num=${#titles[@]}
        local children=($(_children $1))    #all children can succeed
        local child_num=${#children[@]}
        if [ "$titles" ] && [ "$children" ];then       #titles and children exist
            name=$(jq -r .name $(findFile ${children[0]}))
            sed -i "s/${titles[0]}/& <-- ${children[0]} $name/g"   "succeed.tmp"       #main title succeed 
            if [ $child_num -lt 1 ];then     #need to loop succeed
                local j=1
                for (( i=1 ; $i<$title_num ; i++,j++ ))        #loop succeed
                do
                    if [ $j -eq $child_num ];then
                        j=1
                    fi
                    name=$(jq -r .name $(findFile ${children[$j]}))
                    sed -i "s/${titles[$i]}/& <-- ${children[$j]} $name/g"  "succeed.tmp"
                done
            fi
            for i in $children
            do
                succeedOut $i $(grep " $i " succeed.tmp | awk '{print $1}')
            done

        fi
    fi
}

function _titles()   # to output all the titles that need to be succeed $1 is id
{
    file=$(findFile $1)
    echo $(echo $* | awk '{$1="";print $0}')
    if [ "`grep 'titles' $file`" ] || [ "$2" ] && [ "`jq -r .sex $file`" == "male" ]  ;then
        if [ "`grep 'titles' $file`" ];then
            local title="`jq -r .titles[] $file | sed 's/ /_/g'`"
            for i in $title         # i is titles of 1
            do
                buf="$buf $i "
                echo "$i" >> "succeed.tmp"
                sed -i "s/$i/& <-- $1 $(jq -r .name $file) /g" "succeed.tmp"
            done
        fi
        echo "[$1]" >>.tmp
        for i in `jq -r .couples[] $file`              #i is wives of 1
        do
            file=$(findFile $i)
            if [ "`grep 'title' $file`" ];then
                for j in `jq -r .titles[] $file | sed 's/ /_/g'`       # j is the titles of i female
                do
                buf=" $buf $j "
                echo "$j" >> "succeed.tmp"
                sed -i "s/$j/& <-- $i $(jq -r .name $file)/g" "succeed.tmp"
                done
            fi
            echo "[$i]" >>.tmp
        done
        echo $buf
    fi
}

function _children()  # to select the array of succeed children   $1 is id
{
    echo -n "" > ".tmp2"          #to clean the temp2
    file=$(findFile $1)
    local path
    for i in `jq -r .children[] $file`
    do
        path=$(findFile $i)
        echo  "`jq .id $path`  `jq -r .sex $path`" >>".tmp2"
    done

    if [ ! "`grep ' male' .tmp2`" ];then   # no son
        echo "`awk '{print $1}' .tmp2`" 
    else                                            #have sons
        echo "`grep ' male' .tmp2 | awk '{print $1}'`"     
    fi
    echo "[`grep 'female' .tmp2 | awk '{print $1}'`]" >> ".tmp"
    
}

function succeed_titles()
{
    cd $ROOT
    echo -n "" > .tmp
    echo -n "" > succeed.tmp 
    for i in `jq -r .id_used[] $INFO`
    do
        succeedOut $i          #create succeed info file
    done
    sort "succeed.tmp" -o "succeed.tmp"
    choice=$(zenity --list --title "functions" --text "what do you want to do ?" --column "functions" "inquire person" "inquire title" "output to file")
    case "$choice" in
        "inquire person")
            choice=$(cat "succeed.tmp" | grep $(zenity --entry --title "search" --text "enter id or name") | awk '{print $1}')
            zenity --info --title "titles" --text "the person's titles: $choice"
        ;;
        "inquire title")
            choice=$(zenity --entry --title "search" --text "enter title")
            choice=$(cat "succeed.tmp" | grep `echo $choice | sed 's/ /_/g'` | awk -F"<--" '{print $2}')
            zenity --info --title "person" --text "the title will finally had by [ $choice ]"
        ;;
        "output to file")
            touch "succeed_file"
            cat "succeed.tmp" | awk -F'<--' '{print $1, $2}' > "succeed_file"
            sort "succeed_file" -n -k 2 -o "succeed_file" 
        ;;
        *)
        ;;
    esac
    
}

########################################
#   functions for system and will auto work at certain time
function autoBackUp()     #auto back up when exit
{
    cd $ROOT
    rm -rf .backup
    mkdir .backup
    tar -g .backup/snapshot  -zcvf .backup/"auto_back.tar.gz" "database"
    zenity --info --text "auto back fi"
}

function checkfirst()           #when run the script check first
{
#    check=$(echo $(tar -g .backup/snapshot -cvf ".backup/.checkfile.tar" "$ROOT/database") | awk '{print $NF}')
    for check in `echo $(tar -g .backup/snapshot -cvf ".backup/.checkfile.tar" "$ROOT/database")`
    do
    if [ -f "$check" ];then      
        zenity --warning --text "$check has been changed illegelly!" --width=$WIDTH_INFO
    fi
    done
    if [ "`ls -l -d $WORKDIR | awk '{print $1}'`" != "drwx------." ];then
        zenity --warning --text "the dir mode is illegel"  --width=$WIDTH_INFO
    fi

}

###########################################


#             main part 
####################################

function main()
{
    func=$(zenity --info --title "welcome page" --text "welcome to this script, my king! the script is used to help you to clear the relatives, please click next to start"  --ok-label="exit" --width=$WIDTH_INFO --extra-button="next")
    if [ "$func" ];then
        checkfirst
        while [ "$func" ]
        do
            func=$(zenity --list --title "$WORKDIR" --text "what do you want to do?" --list --column "functions" "move files" \
            "change work dir" "manual back" "restore data" "load in data" "check family of one" "output family info" "title succeed" --cancel-label="exit")
            case "$func" in
                "move files")
                    moveFiles
                ;;
                "change work dir")
                    changeWorkingDir
                ;;
                "manual back")
                    manualBackUp
                ;;
                "restore data")
                    restore
                ;;
                "load in data")
                    loadInData
                ;;
                "check family of one")
                    searchFamily
                ;;
                "output family info")
                    all_family
                ;;
                "title succeed")
                    succeed_titles
                ;;
                *)
                    zenity --info --title "exit" --text "thanks for using!"
                ;;
            esac
        done
        autoBackUp

    fi    
}

main
