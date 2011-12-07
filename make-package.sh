#!/bin/sh

SECTION=base
PRIORITY=important
MAINTAINER=sean@chumby.com
VERSION=r1
SOURCE=http://www.chumby.com/
DESCRIPTION=
PACKAGE=
ARCHITECTURE=

PREINST=
POSTINST=
PRERM=
POSTRM=

TEMP_DIR=./pkg-tmp
OUTPUT=

function do_usage() {
    echo "Usage: $0 -n <package_name> -i <input_file_dir> -c <company_name> -o <output_file> [-r r<version>] [-s <source_url>] [-t <temporary_directory>] [-1 <preinst_script>] [-2 <postinst_script>] [-3 <prerm_script>] [-4 <postrm_script>]"
    exit 0
}

function die() {
    cd "${OLD_CWD}"
    exit 1
}

while getopts "n:c:s:r:i:o:t:1:2:3:4:" opt; do
    case $opt in
        n ) PACKAGE=$OPTARG
            ;;
        c ) ARCHITECTURE=$OPTARG
            DESCRIPTION="Provisioning package for ${ARCHITECTURE}"
            ;;
        s ) SOURCE=$OPTARG
            ;;
        i ) INPUT=$OPTARG
            ;;
        o ) OUTPUT=$OPTARG
            ;;
        r ) VERSION=$OPTARG
            ;;
        t ) TEMP_DIR=$OPTARG
            ;;
        1 ) PREINST=$OPTARG
            ;;
        2 ) POSTINST=$OPTARG
            ;;
        3 ) PRERM=$OPTARG
            ;;
        4 ) POSTRM=$OPTARG
            ;;
        * ) do_usage
            ;;
    esac
done

if [ -z ${PACKAGE} ] || [ -z ${ARCHITECTURE} ] || [ -z ${INPUT} ]
then
    do_usage
fi

echo "Package: ${PACKAGE}  Architecture: ${ARCHITECTURE}  Description: ${DESCRIPTION}  Source: ${SOURCE}  Version: ${VERSION}"

OLD_CWD="$(pwd)"
mkdir -p ${TEMP_DIR}/
cd ${TEMP_DIR}
mkdir control
cd control
rm -f control
echo "Package: ${PACKAGE}"              >> control
echo "Architecture: ${ARCHITECTURE}"    >> control
echo "Description: ${DESCRIPTION}"      >> control
echo "Section: ${SECTION}"              >> control
echo "Priority: ${PRIORITY}"            >> control
echo "Maintainer: ${MAINTAINER}"        >> control
echo "Version: ${VERSION}"              >> control
echo "Source: ${SOURCE}"                >> control
if [ ! -z ${PREINST} ]
then
    cp ${PREINST} preinst
    chmod a+x preinst
fi
if [ ! -z ${POSTINST} ]
then
    cp ${POSTINST} postinst
    chmod a+x postinst
fi
if [ ! -z ${PRERM} ]
then
    cp ${PRERM} prerm
    chmod a+x prerm
fi
if [ ! -z ${POSTRM} ]
then
    cp ${POSTRM} postrm
    chmod a+x postrm
fi

tar -czf ../control.tar.gz .
cd ..
rm control/*
rmdir control

cd "${OLD_CWD}/${INPUT}"
tar -czf "${OLD_CWD}/${TEMP_DIR}/data.tar.gz" .
cd "${OLD_CWD}/${TEMP_DIR}"

echo "2.0" > debian-binary

ar -cr "${OLD_CWD}/${OUTPUT}" ./debian-binary ./data.tar.gz ./control.tar.gz
cd "${OLD_CWD}"
rm "${TEMP_DIR}/debian-binary" "${TEMP_DIR}/data.tar.gz" "${TEMP_DIR}/control.tar.gz"
rmdir "${TEMP_DIR}"
