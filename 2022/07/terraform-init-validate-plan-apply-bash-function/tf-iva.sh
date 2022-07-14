# tf-iva - init, validate, plan, apply
function tf-iva {
    if [[ "${1}" =~ ^(-h|--help)$ ]]; then
		cat <<-EOT
			tf-iva - Terraform init, validate, plan, apply by Joe Heaton.dev

			Usage: [TF_PLANS=DIR] tf-iva [chdir]

		Default destiantion for tfplans is \$TMPDIR/terraform
		EOT
        return
    fi

    # Use argument as dir
    [ "${1}" ] && DIR="${1}" || DIR=""

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
    terraform ${DIR:+-chdir=${DIR}} init
    [ ! "$?" = 0 ] && { echo "Error: Terraform init failed."; return 1; }

    echo
    echo "> terraform ${DIR:+-chdir=${DIR}} validate"
    terraform ${DIR:+-chdir=${DIR}} validate
    [ ! "$?" = 0 ] && { echo "Error: Terraform validate failed."; return 1; }

    echo
    echo "> terraform ${DIR:+-chdir=${DIR}} plan -out ${DEST}/${UUID}.tfplan"
    terraform ${DIR:+-chdir=${DIR}} plan -out ${DEST}/${UUID}.tfplan
    [ ! "$?" = 0 ] && { echo "Error: Terraform plan failed."; return 1; }

    echo
    read -n1 -p "Apply this plan? [Y/n]: " yn
    echo
    case $yn in
        [nN]*) echo "Aborting.."; return;;
        [yY]*)
            echo "> terraform ${DIR:+-chdir=${DIR}} apply ${DEST}/${UUID}.tfplan"
            terraform ${DIR:+-chdir=${DIR}} apply ${DEST}/${UUID}.tfplan
            ;;
        "")
            echo "> terraform ${DIR:+-chdir=${DIR}} apply ${DEST}/${UUID}.tfplan"
            terraform ${DIR:+-chdir=${DIR}} apply ${DEST}/${UUID}.tfplan
            ;;
        *) echo "Aborting.."; return;;
    esac 
}
