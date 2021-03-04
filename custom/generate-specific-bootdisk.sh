#!/bin/bash
#     ____             __             ____  ______  __
#    / __ \____  _____/ /_____  _____/ __ \/ ___/ |/ /
#   / / / / __ \/ ___/ //_/ _ \/ ___/ / / /\__ \|   /
#  / /_/ / /_/ / /__/ ,< /  __/ /  / /_/ /___/ /   |
# /_____/\____/\___/_/|_|\___/_/   \____//____/_/|_| GEN BOOT DISK
#
# Repo:             https://github.com/sickcodes/Docker-OSX/
# Title:            Mac on Docker (Docker-OSX)
# Author:           Sick.Codes https://sick.codes/
# Version:          3.1
# License:          GPLv3+

help_text="Usage: generate-specific-bootdisk.sh

General options:
    --model <string>                Device model, e.g. 'iMacPro1,1'
    --serial <filename>             Device Serial number
    --board-serial <filename>       Board Serial number
    --uuid <filename>               SmUUID
    --mac-address <string>          Used to set the ROM value; lowercased and without a colon
    --width <string>                Resolution x axis length in pixels (default 1920)
    --height <string>               Resolution y axis length in pixels (default 1080
    --output-bootdisk <filename>    Optionally change the bootdisk output filename
    
    --master-plist-url <url>        Specify an alternative master plist, via URL.
    --custom-plist | --master-plist <filename>
                                    Optionally change the input plist. Placeholders:
                                        {{DEVICE_MODEL}}, {{SERIAL}}, {{BOARD_SERIAL}},
                                        {{UUID}}, {{ROM}}, {{WIDTH}}, {{HEIGHT}}

    --help, -h, help                Display this help and exit

Example:
    ./generate-specific-bootdisk.sh \
        --model iMacPro1,1 \
        --serial C02TW0WAHX87 \
        --board-serial C027251024NJG36UE \
        --uuid 5CCB366D-9118-4C61-A00A-E5BAF3BED451 \
        --mac-address A8:5C:2C:9A:46:2F \
        --output-bootdisk OpenCore-nopicker.qcow2 \
        --widht 1920 \
        --height 1080

Author:  Sick.Codes https://sick.codes/
Project: https://github.com/sickcodes/Docker-OSX/
"

PLIST_MASTER=config-nopicker-custom.plist

# gather arguments
while (( "$#" )); do
    case "${1}"  in

    --help | -h | h | help ) 
                echo "${help_text}" && exit 0
            ;;

    --model=* | -m=* )
                export DEVICE_MODEL="${1#*=}"
                shift
            ;;
    --model* | -m* ) 
                export DEVICE_MODEL="${2}"
                shift
                shift
            ;;

    --serial=* )
                export SERIAL="${1#*=}"
                shift
            ;;
    --serial* )
                export SERIAL="${2}"
                shift
                shift
            ;;

    --board-serial=* )
                export BOARD_SERIAL="${1#*=}"
                shift
            ;;
    --board-serial* )
                export BOARD_SERIAL="${2}"
                shift
                shift
            ;;

    --uuid=* )
                export UUID="${1#*=}"
                shift
            ;;
    --uuid* )
                export UUID="${2}"
                shift
                shift
            ;;

    --mac-address=* )
                export MAC_ADDRESS="${1#*=}"
                shift
            ;;
    --mac-address* )
                export MAC_ADDRESS="${2}"
                shift
                shift
            ;;

    --width=* )
                export WIDTH="${1#*=}"
                shift
            ;;
    --width* )
                export WIDTH="${2}"
                shift
                shift
            ;;

    --height=* )
                export HEIGHT="${1#*=}"
                shift
            ;;
    --height* )
                export HEIGHT="${2}"
                shift
                shift
            ;;

    --output-bootdisk=* )
                export OUTPUT_QCOW="${1#*=}"
                shift
            ;;
    --output-bootdisk* )
                export OUTPUT_QCOW="${2}"
                shift
                shift
            ;;

    --master-plist-url=* )
                export MASTER_PLIST_URL="${1#*=}"
                shift
            ;;
            
    --master-plist-url* )
                export MASTER_PLIST_URL="${2}"
                shift
                shift
            ;;

    --master-plist=* )
                export MASTER_PLIST="${1#*=}"
                shift
            ;;
    --master-plist* )
                export MASTER_PLIST="${2}"
                shift
                shift
            ;;

    --custom-plist=* )
                export MASTER_PLIST="${1#*=}"
                shift
            ;;
    --custom-plist* )
                export MASTER_PLIST="${2}"
                shift
                shift
            ;;

    *)
                echo "Invalid option. Running with default values..."
                shift
            ;;
    esac
done


download_qcow_efi_folder () {
    git clone --depth 1 https://github.com/kholia/OSX-KVM.git
    cp -ra ./OSX-KVM/OpenCore-Catalina/EFI .
    mkdir -p ./EFI/OC/Resources
    # clone some Apple drivers
    git clone --depth 1 https://github.com/acidanthera/OcBinaryData.git
    # copy said drivers into EFI/OC/Resources
    cp -a ./OcBinaryData/Resources/* ./EFI/OC/Resources
    # EFI Shell commands
    touch startup.nsh && echo 'fs0:\EFI\BOOT\BOOTx64.efi' > startup.nsh
}

generate_bootdisk () {

    if [[ "${MASTER_PLIST}" ]]; then
        [[ -e "${MASTER_PLIST}" ]] || echo "Could not find: ${MASTER_PLIST}"
    elif [[ "${MASTER_PLIST}" ]] && [[ "${MASTER_PLIST_URL}" ]]; then
        echo 'You specified both a custom plist file AND a custom plist url. Use one or the other.'
    elif [[ "${MASTER_PLIST_URL}" ]]; then
        wget -O "${MASTER_PLIST:=./config-custom.plist}" "${MASTER_PLIST_URL}" \
            || { echo "Could not download ${MASTER_PLIST_URL}" && exit 1 ; }
    else
        MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/Docker-OSX/master/custom/config-nopicker-custom.plist'
        wget -O "${MASTER_PLIST:=./config-nopicker-custom.plist}" "${MASTER_PLIST_URL}" \
            || { echo "Could not download ${MASTER_PLIST_URL}" && exit 1 ; }
    fi


    [[ -e ./opencore-image-ng.sh ]] || wget https://raw.githubusercontent.com/sickcodes/Docker-OSX/master/custom/opencore-image-ng.sh && chmod +x opencore-image-ng.sh

    # plist required for bootdisks, so create anyway.
    if [[ "${DEVICE_MODEL}" ]] \
            && [[ "${SERIAL}" ]] \
            && [[ "${BOARD_SERIAL}" ]] \
            && [[ "${UUID}" ]] \
            && [[ "${MAC_ADDRESS}" ]]; then
        ROM="${MAC_ADDRESS//\:/}"
        ROM="${ROM,,}"
        sed -e s/{{DEVICE_MODEL}}/"${DEVICE_MODEL}"/g \
            -e s/{{SERIAL}}/"${SERIAL}"/g \
            -e s/{{BOARD_SERIAL}}/"${BOARD_SERIAL}"/g \
            -e s/{{UUID}}/"${UUID}"/g \
            -e s/{{ROM}}/"${ROM}"/g \
            -e s/{{WIDTH}}/"${WIDTH:-1920}"/g \
            -e s/{{HEIGHT}}/"${HEIGHT:-1080}"/g \
            "${MASTER_PLIST}" > ./tmp.config.plist || exit 1
    else
        cat <<EOF
Error: one of the following values is missing:

--model "${DEVICE_MODEL:-MISSING}"
--serial "${SERIAL:-MISSING}"
--board-serial "${BOARD_SERIAL:-MISSING}"
--uuid "${UUID:-MISSING}"
--mac-address "${MAC_ADDRESS:-MISSING}"

--width "${WIDTH:-1920}"
--height "${HEIGHT:-1080}"

EOF
        exit 1
    fi

    ./opencore-image-ng.sh \
        --cfg "./tmp.config.plist" \
        --img "${OUTPUT_QCOW:-./${SERIAL}.OpenCore-nopicker.qcow2}" || exit 1
        rm ./tmp.config.plist

}

main () {
    download_qcow_efi_folder
    generate_bootdisk
}

main

