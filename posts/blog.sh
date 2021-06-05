#!/bin/bash

HELP="Usage: blog.sh [opts] [title]\n  [-f|--format]=[md:default|rst|html|txt]\n  [-d|--date]=[YYYY-mm-dd|today:default]\n  [-c|--category]=[name]\n  --visual\n  [-a|--autocommit]\n"

[ -z "$1" ] && { printf "$HELP"; exit 1; }

printf "blog.sh - Handle file-based authoring!\n"

for i in "$@"; do
  case $i in
    -h*|--help)
        printf "$HELP"
        exit 0;;
    -f=*|--format=*)
        FORMAT="${i#*=}"
        shift;;
    -d=*|--date=*)
        DATE="${i#*=}"
        shift;;
    -c=*|--category=*)
        DIR="${i#*=}"
        shift;;
    -v|--visual)
        VISUAL_MODE=true
        shift;;
    -a|--autocommit)
        AUTOCOMMIT=true
        shift;;
    *) printf "" ;;
  esac
done

[ -z "$1" ] && { printf "Please specify a title! - e.g. blog.sh test\n"; exit 1; }
TITLE="$1"
[[ $( echo "$TITLE" | grep -P "^[a-zA-Z0-9_\-\ ]+" ) ]] || { echo "Title contains unsupported characters: $1"; exit 1; }

# FORMAT
if [ -z "$FORMAT" ]; then
    read -p "* Which format? [md:default|rst|html|txt] " FORMAT
    [ -z "$FORMAT" ] && FORMAT="md"
fi

# DIR
if [ -z "$DIR" ]; then
    read -p "* Which category? [blog:default] " DIR
    [ -z "$DIR" ] && DIR="blog"
fi

# Check data dirs in category
TESTDIR="${DIR}/$(date +%Y)"
if [ -d "${TESTDIR}" ]; then
    DIR="$TESTDIR"

    TESTDIR="${DIR}/$(date +%m)"
    if [ -d "${TESTDIR}" ]; then
        DIR="$TESTDIR"
    fi
fi

# FILENAME
[ "$DATE" ] || DATE="$( date +%Y-%m-%d )"
FILENAME="${DATE}-${TITLE}.${FORMAT}"

# Build fullpath
FULLPATH="$DIR${DIR:+/}$FILENAME"

# Check for existing files (this year)
MATCH_TITLE="$( find . -name "$( date +%Y )*${TITLE}*" -type f )"
if [ "$MATCH_TITLE" ]; then
    printf "* Matching titles found:\n${MATCH_TITLE}\n"

    # Continue or not?
    printf "* Would you like to continue with ${FULLPATH}? "
    read -p "[(y)|n] " CONTINUE
    [ "${CONTINUE:-y}" = "y" ] || { echo "Exiting.."; exit 0; }
fi

# Create $DIR
DIR_MADE="$(mkdir $DIR 2>/dev/null)"
[ "$DIR_MADE" ] && printf "* Making new category $DIR\n"

# Fill in boilerplate
case $FORMAT in
    md)
        printf -- "---\ntitle: $TITLE\nstatus: draft\n---\n\n" > $FULLPATH;;
    rst)
        printf "$TITLE\n" > $FULLPATH
        printf '#%.0s' $(seq 1 ${#TITLE}) >> $FULLPATH
        printf "\n\n:status: draft\n\n\n" >> $FULLPATH;;
    html)
        cat << EOF > $FULLPATH
<html>
 <head>
  <title>$TITLE</title>
  <meta name="status" content="draft">
 </head>
 <body>

    <p></p>
 
 </body>
</html>
EOF
        ;;
esac

# Abort if any boilerplate failed (permissions)
[ "$?" != 0 ] && { printf "Error preparing file.. Abort!\n"; exit 1; }

# Open FULLPATH in editor
printf "\nEditing ${FULLPATH} "

if [[ "$VISUAL_MODE" = "true" && "$VISUAL" ]]; then
    printf "in ${VISUAL}"
    $VISUAL $FULLPATH
elif [[ -z "$VISUAL_MODE" && "$EDITOR" ]]; then
    printf "in ${EDITOR}"
    $EDITOR $FULLPATH
else
    /bin/vi $FULLPATH
fi; printf "..\n"

# Git autocommit
if [ "$AUTOCOMMIT" ] && [ -e .git ];  then
    ( git diff ${FULLPATH}; git add ${FULLPATH}; git commit -m "Autosave"; )
fi

# Delete category if nothing has been saved inside
[ "$DIR" ] && rmdir --ignore-fail-on-non-empty $DIR

