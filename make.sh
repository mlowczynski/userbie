#!/bin/bash -ex

### module info ###
# The build environment expects to live in a subdir build/
# It expects to find book information in the parent dir
# ./books/
# ./images/
# ./modules/
# ./build/

### settings ###

OUTPUTDIR="./output"
redirfile="$OUTPUTDIR/debug.txt"
HTMLDIR="$OUTPUTDIR/html"
HTMLIMGDIR="$HTMLDIR/images"
IMAGESDIR="./images" 
MODULESDIR="./modules"
HEADERDIR="$MODULESDIR/header"
FOOTERDIR="$MODULESDIR/footer"
BUILDDIR="."
LIBDIR="$BUILDDIR/lib"
export FOP_OPTS="-Xms512m -Xmx512m"
export BOOKSDIR=./books
HTMLXSL="$LIBDIR/html.xsl"
HTMLCSS="$LIBDIR/html.css"
SITECSS="$LIBDIR/site.css"

### script configuration ###

# set this to empty or zero to disable this feature
# this could be moved to a book config
BUNDLE_APPENDICES=1
APPENDICES_BUNDLE="license rev_history"

### initialisation ###

V=""
CHAPTERS=""
APPENDICES=""

PUBDATE=$(date +'%Y-%m-%d')
YEAR=$(date +%Y)

### functions ###

help() {
	echo
	echo "Userbie book series build script\t\thttp://userbie.com"
	echo
	echo $0 [OPTION] command [book]
	echo 
	echo "Options"
	echo "  -d 0,1,2,3,4		Set debug level, 1 is default"
	echo "					0	No output"
	echo "					1	Standard output"
	echo "					2	Verbose output"
	echo "					3	Extra verbose output"
	echo "					4	Debug output"
	echo "  -h			Help"
	echo
	echo "Commands"
	echo "  clean			clean output dir"
	echo "  pdf [BOOK]		generate pdf"
	echo "  html [BOOK]		generate html"
	echo
	echo "Available books:" $superbooks
	echo "      minibooks:" $minibooks
	echo
	return 0
	}

set_xsl() {
	if	[ -r $BOOKSDIR/$book/pdf.xsl ]
		then	XSLFILE="$BOOKSDIR/$book/pdf.xsl"
		else	XSLFILE="$LIBDIR/pdf.xsl"
	fi
	return 0
}

set_JAVA() {
	# Debian / ubuntu specific
	if [ -x "$(which java)" ]
	then    JAVA_ALTERNATIVE=$(readlink /etc/alternatives/java)
		export JAVA_HOME=${JAVA_ALTERNATIVE%/bin/java}
	else    echor Could not set JAVA_HOME, something unexpected happened in $0
	fi
	return 0
	}

check_ROOTDIR() {

	if	[ -d $BOOKSDIR -a -d $MODULESDIR -a -d $BUILDDIR ]
	then	echo "Current dir is book project root directory."
	else	echor "Please run this script from the book root directory."
	fi
	return 0
        }

add_mod() {
        # add_mod $type $name
        # type is chapter appendix of minibook
        # name is name of module or book
        type=$1
        name=$2
        case $type in
            chapter)
                CHAPTERS=${CHAPTERS}" "$name
                ;;
            appendix)
                APPENDICES=${APPENDICES}" "$name
                ;;
            minibook)
                MINIBOOKS=${MINIBOOKS}" "$name
                ;;
        esac
	return 0
        }

echor() {	# echo error
	echo $* >&2
	exit 1
	}

echod() {	# echo debug
	[ $OPTDEBUG -ge 2 ] && echo $* 
	return 0
	}

clean() {
	echo "Cleaning up $OUTPUTDIR directory"
	# We don't need the .xml files
	rm -rf $V $OUTPUTDIR/*.xml
	# We don't need the previous errors.txt
	[ -f $redirfile ] && rm -rf $V $redirfile
	# Symlink creation fails unless we remove this symlink first
	[ -h $OUTPUTDIR/book.pdf ] && rm -rf $V $OUTPUTDIR/book.pdf
	# Clean $HTMLDIR
	[ -d $HTMLDIR ] && rm -rf $V $HTMLDIR/*.xml
	return 0
	}

check_book() {
	if [ ! -z $book ]
		then 	# check if $book parameter is one of the available books
			echo -n "Checking if $book.cfg exists in ./books directory ... "
			check=0
			for entry in $books ; do
				if [ $entry = $book ]
					then check=1
				fi
			done
			if [ $check = 1 ]
				then echo "Selected book $book"
				else echor "$book is not available"
			fi
		else
			echo "No book specified, assuming default book"
			book="default"
		fi
	return 0
	}

build_header() {
	cat "$HEADERDIR/doctype.xml" | sed s@LIBDIR@../$LIBDIR@g	> $headerfile
        echo "<book>"                                           >> $headerfile
        echo "<bookinfo>"                                       >> $headerfile
        echo "<title>$BOOKTITLE</title>"                        >> $headerfile
	if [ -n "$BOOKSUBTITLE" ]
		then echo "<subtitle>$BOOKSUBTITLE</subtitle>"               >> $headerfile
	fi
	local abstractFile="$HEADERDIR/abstract_$book.xml"
	if [ ! -f "$abstractFile" ] 
		then abstractFile="$HEADERDIR/abstract_minibook.xml"
	fi
	$BUILDDIR/buildheader.pl \
		"$abstractFile" \
		"$BOOKSDIR/$book/copyrights" \
		"$BOOKSDIR/$book/authors" \
		"$BOOKSDIR/$book/editors" \
		"$BOOKSDIR/$book/contributors" \
		"$BOOKSDIR/$book/reviewers" \
		"$BOOKSDIR/$book/publisher" \
		"$PUBDATE" \
		"$YEAR" \
		"$TEACHER"			                            		>> $headerfile	 
        echo "</bookinfo>"                                      >> $headerfile
	cat "$HEADERDIR/preface.xml"				>> $headerfile
	return 0
	}

build_footer() {
	cat "$FOOTERDIR/footer.xml" >$footerfile
	}

build_part_body() {

    for modtype in CHAPTERS APPENDICES
    do
        echod Building $modtype ..
        for mod in ${!modtype}
        do
            echod -n "Building module $mod "
            modfile=$OUTPUTDIR/mod_$mod.xml

            # enumerate module files for this module $mod
	    if [ -d "$MODULESDIR/$mod" ]
	    then	MODULES=$(ls ${MODULESDIR}/${mod}/*)
 	    else	echor "Error: module $mod does not exist!" 
	    fi
            echo $MODULES

            # Generate the start chapter/appendix tag
            case $modtype in
                CHAPTERS)
                    echo "<chapter id=\"$mod\">"      > $modfile
                    ;;
                APPENDICES)
        		    echo "<appendix id=\"$mod\">" 	 > $modfile
                    ;;
            esac
            # Generate all the sections
            for module in $MODULES
            do
                echod -n "\t.. adding module $module"
                cat $module                                 >> $modfile
            done
            echod

            # Generate the end chapter tag
            case $modtype in
                CHAPTERS)
                    echo "</chapter>"                               >> $modfile
                    ;;
                APPENDICES)
                    echo "</appendix>"                               >> $modfile
                    ;;
            esac

            # add the module to the body
            cat $modfile >> $partfile

        done
    done
    return 0
}

fill_part() {
	local partfile="$1"
	local part_id="$2"

	echo "<part id=\"$part_id\">"		>>$bodyfile
	# Here we use the BOOKTITLE as a title for the PART
	echo "<title>$BOOKTITLE</title>"	>>$bodyfile
	cat "$partfile"        			>>$bodyfile
	echo "</part>"      			>>$bodyfile
	return 0
}

build_part() {
    PART=$1

    # empty the partfile and reset the variables
    >$partfile
    CHAPTERS=""
    APPENDICES=""

    if [ "$PART" = "CUSTOMPART" ]
    then    # just build the part body using the chapters and apendices from the main book config
	    if [ "$BUNDLE_APPENDICES" = 1 ]
	    then	echod "restore the bundled appendices: ${APPENDICES_BUNDLE}"
			APPENDICES=${APPENDICES_BUNDLE}
	    fi
            . $BOOKSDIR/$book/config
            build_part_body
    else    # first read in the config of this part minibook
            . $BOOKSDIR/$PART/config
	    if [ "$BUNDLE_APPENDICES" = 1 ]
	    then	# move content of APPENDICES var to be used later in the custompart
			APPENDICES_BUNDLE=${APPENDICES_BUNDLE}${APPENDICES}
			APPENDICES=""
	    fi
            # then build that part body
            build_part_body
    fi
    return 0
    }

build_body() {
    # first build minibooks, each minibook is a "<part>"
    # then chapters, then appendices "which each are "<chapter>
    # if we have both minibooks and separate chapters+appendices, then build the latter set as a custom minibook in a separate <part>
    # if we have no minibooks, then no need for "<part>"

    if [ -z "$MINIBOOKS" ]
    then    # no minibooks
            HAZ_MINIBOOKS=0
    else    # build minibooks
            HAZ_MINIBOOKS=1
            for minibook in $MINIBOOKS
            do  echod "Assembling the part for minibook $minibook"
		build_part $minibook
                fill_part "$partfile" "$minibook"
            done
    fi

    if [ -z "$CHAPTERS $APPENDICES" ]
    then    # no custom part
            HAZ_CUSTOMPART=0
    else    # simple custom book or custom part
            HAZ_CUSTOMPART=1
	    # just build the custom book
	    echod "Assembling the custom part or simple book."
            build_part CUSTOMPART
	    if [ $HAZ_MINIBOOKS = 0 ]
	    then	# just use partfile as bookbody
            		cat $partfile   >>$bodyfile
	    else	# add custom part as extra part
			# set booktitle for custompart
			if [ $(echo $CHAPTERS $APPENDICES | wc -w ) -gt 1 ]
			then	BOOKTITLE="Appendices"
				BOOKSUBTITLE="$BOOKSUBTITLE"
			else	BOOKTITLE="Appendix"
				BOOKSUBTITLE="$BOOKSUBTITLE"
			fi
			echod "Adding the custom part at the end."
			fill_part "$partfile" "${BOOKTITLE,,}"
	    fi
    fi
    return 0
    }

build_xml() {
	echo -n "Parsing config $BOOKSDIR/$book/config ... "
	CHAPTERS=""
	APPENDICES=""
	. $BOOKSDIR/$book/config

	echod "This book contains:"
	echod "MINIBOOKS = $MINIBOOKS"
	echod "CHAPTERS = $CHAPTERS"
	echod "APPENDICES = $APPENDICES"

	echo "generating book $book (titled \"$BOOKTITLE\")"
	[ -d $OUTPUTDIR ] || mkdir $OUTPUTDIR

	BOOKTITLE2=$(echo $BOOKTITLE | sed -e 's/\ /\_/g' -e 's@/@-@g' )
	filename=$BOOKTITLE2
	xmlfile=$OUTPUTDIR/$filename.xml
	pdffile=$OUTPUTDIR/$filename.pdf
	headerfile=$OUTPUTDIR/section_header.xml
	footerfile=$OUTPUTDIR/section_footer.xml
	bodyfile=$OUTPUTDIR/section_body.xml
	partfile=$OUTPUTDIR/part.xml
	partcustomfile=$OUTPUTDIR/partcustom.xml

	# make header
	build_header

	# make footer
	build_footer

	# make body
	build_body

	# build master xml
	echo "Building $xmlfile"
	cat $headerfile  > $xmlfile
	cat $bodyfile   >> $xmlfile
	cat $footerfile >> $xmlfile
	return 0
	}

build_pdf() {
  echor PDF generation disabled in this edition
	set_xsl
	set_JAVA
	echo 
	echo "---------------------------------"
	echo "Generating $pdffile"
	fop -xml $xmlfile -xsl $XSLFILE -pdf $pdffile $EXECDEBUG
	ln -s $V $filename.pdf $OUTPUTDIR/book.pdf
	echo "---------------------------------"
	return 0
	}

build_html() {
    [ -d $HTMLDIR ] && rm -rf $V $HTMLDIR
    mkdir $V $HTMLDIR || echor Error creating $HTMLDIR
    mkdir $V $HTMLIMGDIR || echor Error creating $HTMLIMGDIR

    # We only need the one xml file
    cp $V $xmlfile $HTMLDIR || echor error copying $xmlfile

    # Locate the used images in the xml file
    images=`grep "<imagedata " $HTMLDIR/*.xml | sed 's@.* fileref="[^"]*/\([^"/]*\)".*@\1@'`

    # Copy all the used images
    for img in $images
    do
         echo Copying $img to $HTMLIMGDIR ...
         cp $V "$IMAGESDIR/$img" $HTMLIMGDIR/ || echor Error copying $img
    done

    # Copy css file to html directory
    cp $HTMLCSS $HTMLDIR
    cp $SITECSS $HTMLDIR

    # Run xsltproc in $HTMLDIR to generate the html
    echo "Converting xml to html ..."
    ( cd $HTMLDIR ; xsltproc -o "$filename.html" "../../$HTMLXSL" "$filename.xml" ) \
         || echor  Error generating the html file "$filename.html"

    # don't need the xml anymore in the $HTMLDIR
    rm -f "$filename.xml" 

    return 0
}

while getopts "d: h" option
do
	case $option in
		d ) 	OPTDEBUG=$OPTARG
			shift 2
			;;
		h ) 	help
			shift 1
			exit 0
			;;
        esac
done

command=$1
book=$2

case $OPTDEBUG in
	0)	# DEBUG 0 is zero output (except help message)
		REDIR=">$redirfile 2>&1"
		;;
	"" | 1)	# DEBUG 1 is default, only STDOUT
		REDIR="2>$redirfile"
		;;
	2)	# DEBUG 2 is all output we get normally
		REDIR=""
		;;
	3)	# DEBUG 3 is all output we get normally + verbose flag everywhere
		REDIR=""
		V="-v"
		;;
	4)	# DEBUG 4 is all output we get normally + fop exec debug on + verbose flag everywhere
		REDIR=""
		EXECDEBUG="-d"
		V="-v"
		;;
	*)	help
		exit 0
		;;
esac

##############

check_ROOTDIR

books=$( cd $BOOKSDIR ; find * -maxdepth 1 -type d)
superbooks=$( cd $BOOKSDIR ; find * -maxdepth 1 -type d | grep -v minibook ) || true
minibooks=$( cd $BOOKSDIR ; find * -maxdepth 1 -type d | grep minibook)

mkdir -p $OUTPUTDIR

# Redirect everything according to REDIR var from now on.
eval "exec $REDIR"

# Main loop
case "$command" in
  clean)
	clean
	;;
  pdf)
	[ -x "$(which fop)" ] || echor "fop not installed."
	clean
	check_book
	echo "Building '$book' book."
	build_xml
	echo "Generating pdf for '$book' book."
	build_pdf
	echo "Done generating pdf $OUTPUTDIR/book.pdf -> $pdffile" 
	;;
  html)
	[ -x "$(which xsltproc)" ] || echor "xsltproc not installed."
	clean 
	check_book
	echo "Building '$book' book."
	build_xml
	echo "Generating html for '$book' book."
	build_html
 	echo "Done Generating html for '$book' book."
	;;
  *)
	help
	;;
	
esac

