# tf-iva - init, validate, plan, apply
function tf-iva {
    if [[ "${1}" =~ ^(-h|--?help)$ ]]; then
		cat <<-EOT
			tf-iva - Terraform init, validate, plan, apply by Joe Heaton.dev

			Usage: [TF_PLANS=DIR] tf-iva [FLAGS] [chdir]

			Flags:
			    -h|--help    - Display this help text
			    -d|--destroy - Perform a destroy instead of apply
			    -t|--target  - Targetted apply (does not support destroy)

			Example:
			    tf-iva --target module.folder my_terraform

			Default destiantion for tfplans is \$TMPDIR/terraform
		EOT
        return
    fi

    terraform="$( which terraform 2>/dev/null )"

    # --destroy and exit
    if [[ "${1}" =~ ^(-d|--?destroy)$ ]]; then
        DIR="${2}"
        echo
        echo "> terraform ${DIR:+-chdir=${DIR}} destroy"
        $terraform ${DIR:+-chdir=${DIR}} destroy
        return
    fi

    # --target set TARGET & DIR
    if [[ "${1}" =~ ^(-t|--?target)$ ]]; then
        TARGET="${2}"
        DIR="${3}"
    fi

    # Use argument as DIR if DIR unset
    [ ! "${DIR}${TARGET}" ] && [ "${1}" ] && DIR="${1}" || DIR=""

    # Abort if DIR unset
    [ ! "${DIR}${TARGET}" ] && { echo "DIR unset.. Aborting!"; return 1; }

    # Set tfplan destination
    if [ "${TF_PLANS}" ]; then
        # Override DEST if $TF_PLANS set
        DEST="${TF_PLANS}"
    else
        # Set TMPDIR if missing
        DEST="${TMPDIR:-/tmp}/terraform"
    fi

    # Make temp directory for terraform
    [ ! -d "${DEST}" ] && mkdir ${DEST} >/dev/null

    # Get random UUID for our plan name
    UUID="$(< /proc/sys/kernel/random/uuid )"
    
    echo
    echo "> terraform ${DIR:+-chdir=${DIR}} init"
    $terraform ${DIR:+-chdir=${DIR}} init
    [ ! "$?" = 0 ] && { echo "Error: Terraform init failed."; return 1; }

    echo
    echo "> terraform ${DIR:+-chdir=${DIR}} validate"
    $terraform ${DIR:+-chdir=${DIR}} validate
    [ ! "$?" = 0 ] && { echo "Error: Terraform validate failed."; return 1; }

    echo "> terraform ${DIR:+-chdir=${DIR}} plan ${TARGET:+-target=${TARGET}} -out ${DEST}/${UUID}.tfplan"
    $terraform ${DIR:+-chdir=${DIR}} plan ${TARGET:+-target=${TARGET}} -out ${DEST}/${UUID}.tfplan
    [ ! "$?" = 0 ] && { echo "Error: Terraform plan failed."; return 1; }

    read -r -p "Apply this plan? [Y/n]: " yn
	[[ ! "${yn,,}" =~ ^y|yes$ ]] && return 1
    echo
    case $yn in
        [nN]*) echo "Aborting.."; return;;
        [yY]*)
            echo "> terraform ${DIR:+-chdir=${DIR}} apply ${TARGET:+-target=${TARGET}} ${DEST}/${UUID}.tfplan"
            $terraform ${DIR:+-chdir=${DIR}} apply ${TARGET:+-target=${TARGET}} ${DEST}/${UUID}.tfplan
            ;;
        "")
            echo "> terraform ${DIR:+-chdir=${DIR}} apply ${TARGET:+-target=${TARGET}} ${DEST}/${UUID}.tfplan"
            $terraform ${DIR:+-chdir=${DIR}} apply ${TARGET:+-target=${TARGET}} ${DEST}/${UUID}.tfplan
            ;;
        *) echo "Aborting.."; return;;
    esac 
}