# tf-iva - init, validate, plan, apply
function tf-iva {
    if [[ "${1}" =~ ^(-h|--?help)$ ]]; then
		cat <<-EOT
			tf-iva - Terraform init, validate, plan, apply by Joe Heaton.dev

			Usage: [TF_PLANS=DIR] tf-iva [FLAGS] [DIR]

			Flags:
			    -h|--help      - Display this help text
			    -d|--destroy   - Destroy, cannot be mixed with other flags
			    -t|--target    - Targetted apply
			    -c|--chdir - Catch -chdir, not required

			Example:
			    # Apply in current directory
			    tf-iva
			    
			    # Apply target in current directory
			    tf-iva --target module.folder

			    # Apply target in chdir directory
			    tf-iva --target module.folder my_tf
			    
			    # Destroy in current directory
			    tf-iva --destroy
			    
			    # Destroy in chdir directory
			    tf-iva --destroy my_tf
			
			Default destiantion for tfplans is \$TMPDIR/terraform
		EOT
        return
    fi

    local DIR TARGET DEST UUID
    local terraform="$( which terraform 2>/dev/null )"
    [ ! "${terraform}" ] && { echo "Error: Terraform not found."; return 1; }

    # --destroy and exit
    if [[ "${1}" =~ ^(-d|--?destroy)$ ]]; then
        DIR="${2}"
        # Targetted destroy: tf-iva --destroy --target module.test dir
        [[ "${2}" =~ ^(-t|--?target)$ ]] && { TARGET="${3}"; DIR="${4}"; }
        # Error on all other flags
        [[ "${DIR}" =~ ^- ]] && { echo "Error: Destroy cannot be used with another flag"; return 1; }
        echo
        echo "> terraform ${DIR:+-chdir=${DIR}} destroy ${TARGET:+-target=${TARGET}}"
        $terraform ${DIR:+-chdir=${DIR}} destroy ${TARGET:+-target=${TARGET}}
        return $?
    fi

    # --target set TARGET & DIR
    if [[ "${1}" =~ ^(-t|--?target)$ ]]; then
        TARGET="${2}"
        DIR="${3:-$PWD}"
        # Catch --chdir and set DIR
        [[ ${3} =~ ^(-c|--?chdir)$ ]] && DIR="${4}"
    fi

    # Use argument as DIR if DIR unset
    [[ ! "${1}" =~ ^- ]] && DIR="${1}"

    # Catch --chdir and set DIR
    [[ ${1} =~ ^(-c|--?chdir)$ ]] && DIR="${2}"

    # Abort if DIR missing
    [ "${DIR}" ] && [ ! -d "${DIR}" ] && { echo "Error: Directory does not exist."; return 1; }

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
	[[ ! "${yn,,}" =~ ^(y|yes)$ ]] && return 1
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
