### First needed:
# tools
#   jq and curl
#
# work done on REMS
#            curl -X POST http://localhost:3000/api/users/create \
#            -H "content-type: application/json" \
#            -H "x-rems-api-key: $API_KEY" \
#            -H "x-rems-user-id: $REMS_OWNER" \
#            -d '{
#                  "userid": "robot", "name": "Permission Robot", "email": null
#            }'
#            curl -X POST http://localhost:3000/api/users/create \
#            -H "content-type: application/json" \
#            -H "x-rems-api-key: $API_KEY" \
#            -H "x-rems-user-id: $REMS_OWNER" \
#            -d '{
#                 "userid": "portalbot", "name": "Portal Robot for reading and creating resources and catalogues", "email": null
#            }'
#            cd ~/rems_2.32/;
#
#            # Visas robot
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar grant-role reporter robot
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key add ${PERMISSION_ROBOT_KEY} robot-key
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key allow ${PERMISSION_ROBOT_KEY} get '/api/permissions/.*'
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key set-users ${PERMISSION_ROBOT_KEY} robot
#
#            # Resource and Catalogue robot
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar grant-role owner portalbot
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key add ${PORTALBOT_KEY} portalbot-key
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key allow ${PORTALBOT_KEY} any '/api/(catalogue|catalogue-items|resources)/.*'
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key set-users ${PORTALBOT_KEY} portalbot
#
#            # To list all the keys
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key get
#
#            # to list all the users (and bots)
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar list-users
#
#            # to delete all acces levels
#            java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key allow-all ${PORTALBOT_KEY}
###

# define current directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# config file (parsing_user_portal.config) must be placed in the folder next to this script (parsing_user_portal.sh)
source ${SCRIPT_DIR}/parsing_user_portal.config

# re to check the numbers
re='^[0-9]+$'

# curl wrapper a helping function for REMS: API can be parsed with only
# few parameters instead of 10 lines
# parameters [PUT] ["base API URL"] ["archived" or "enabled"] [item ID number] [archived or enabled boolean "true" or "false"]
function _curl(){
    [[ "${#}" -lt 2 ]] && { echo "error, needed at least 2 parameters" && return 1; }
    _mode="${1}"        # PUT (or GET / POST)
    _api="${2}"         # api/licenes/enables
    shift 2
    _data="${*}"        # json data to be sumbitted
    _command="curl -s -X ${_mode} ${REMS_URL}${_api} \
        -H \"content-type: application/json\" \
        -H \"x-rems-user-id: portalbot\" \
        -H \"x-rems-api-key: ${PORTALBOT_KEY}\" \
        -d '${_data}'"
    _curl_return=$(eval "${_command}")
    _curl_return_id=$(echo "${_curl_return}" | jq .id 2>/dev/null)
    _curl_success=$(echo "${_curl_return}" | jq .success 2>/dev/null)
    if [[ ${_mode} != "GET" ]]; then
        if [[ ${_curl_success} == "true" ]]; then [[ "${VERBOSE}" -ge "1" ]] && echo "success"; return 0;
        else
            echo "error:"
            echo " input was: >${*}<"
            echo -e " command executed was:\n    >${_command}<"
            echo -e " and the output was:\n    >${_curl_return}<"
            return 1
        fi
    else echo "${_curl_return}"         # return GET
    fi
}

# template for creating a resource
function _resource(){
    _data='{
                "resid": "'${_portal_resource_id:-}'",
                "organization": {
                    "organization/id": "'${_organization_id:-}'"
                },
                "licenses": [ '${_license_id}' ]
            }'
    _curl POST /api/resources/create ${_data:-}
    _resource_id="${_curl_return_id}"
}

# template for creating a catalogue
function _catalogue(){
    # finally create a catalogue item, so that the dataset shows up on the main page
    _data='{
                "organization": {
                    "organization/id": "'${_organization_id}'"
                },
                "form": '${_form_id}',
                "resid": '${_resource_id}',
                "wfid": '${_workflow_id}',
                "localizations": {
                    "en": {
                        "title": "'${_portal_resource_title}'",
                        "infourl": "'${_portal_dataset_url}'"
                    }
                },
                "enabled": true,
                "archived": false
            }'
    _curl POST /api/catalogue-items/create ${_data}
    _catalogue_id=${_curl_return_id}
}

# helping function for curl parsing the portal/molgenis
function _curl_portal(){
    _mode="${1}"        # PUT (or GET / POST)
    _api="${2}"         # api/licenes/enables
    shift 2
    _data="${*}"        # json data to be sumbitted
    _command="curl -s -X ${_mode} ${PORTAL_URL}${_api} \
        -H \"content-type: application/json\" \
        -H \"Authorization: x-molgenis-token ${PORTAL_TOKEN}\" \
        -d '${_data}'"

    _curl_return=$(eval "${_command}")
    _curl_success=$(echo "${_curl_return}" | jq ".errors | .[] | .\"message\"" 2>/dev/null)
    if [[ ${_mode} != "GET" ]]; then
        if [[ "x${_curl_success}" == "x" ]]; then [[ "${VERBOSE}" -ge "1" ]] && echo "success"; return 0;
        else
            echo "error:"
            echo " input was: ${*}"
            echo -e " command executed was:\n    ${_command}"
            echo -e " and the output was:\n    ${_curl_return}"
            return 1
        fi
    else echo "${_curl_return}"         # return GET
    fi
}

# parsing both portal/molgenis as well as REMS: and checking if it correct reply
function _collect_portal_rems_data(){
        [[ "${VERBOSE}" -ge "1" ]] && echo -n "  - collecting from portal main info of datasets ... "
        _curl_portal POST /PortalGDI/api/graphql '{"query": "query { Dataset { id title description mg_insertedOn mg_updatedOn } }" }' || return 1
        _dataset_all_main_info="$(jq -r ".data.Dataset" <<< "${_curl_return}")"
        _dataset_all_ids="$(jq -r ".[].id" <<< "${_dataset_all_main_info}")"
        [[ "${VERBOSE}" -ge "1" ]] && echo -n "  - collecting from REMS all resources ... "
        _rems="$(_curl GET /api/resources/  | jq -r ".[] | .\"resid\"")"
        [[ "${VERBOSE}" -ge "1" ]] && echo "success"
}

# iterate trough each portal dataset and check if already inserted
function _portal_dataset_pull(){
    [[ "${VERBOSE}" -ge "1" ]] && echo " Rems resources"
    [[ "${VERBOSE}" -ge "1" ]] && echo "  - comparing each resource "
    while read _each_dataset_unformatted ; do
        _each_dataset="${_each_dataset_unformatted//[\\\"\']/}"
        _already_inserted=false
        while read _each_rems_resource_unformatted ; do
            _each_rems_resource="${_each_rems_resource_unformatted//[\\\"\']/}"
            if [[ "${_each_rems_resource}" == "${_each_dataset}" ]]; then
                _already_inserted=true
                [[ "${VERBOSE}" -ge "1" ]] && echo "      '${_each_dataset}' already inserted"
                continue 2
            fi
        done <<< "${_rems}"
        if ! ${_already_inserted} ; then
            _portal_resource_id="${_each_dataset}"
            echo "      > '${_each_dataset}' missing - inserting in rems [$(date)]"
            [[ "${VERBOSE}" -ge "1" ]] && echo -n "          resource: "
            _resource
            # gets in return _resource_id, that is used in catalogue creation

            _portal_resource_title="$(jq -r ".[] | select(.id==\"${_each_dataset}\") | .title" <<< "${_dataset_all_main_info}")"
            _portal_resource_description="$(jq -r ".[] | select(.id==\"${_each_dataset}\") | .description" <<< "${_dataset_all_main_info}")"

            [[ "${VERBOSE}" -ge "1" ]] && echo -n "          catalogue: "
            _portal_dataset_url="${PORTAL_URL}/${PORTAL_DATABASE}/gportal/#/${PORTAL_TABLE}?_view=cards&_limit=1&id=${_portal_resource_id}"
            _catalogue
            # gets in return _catalogue_id that get's updated on user Portal
        fi
    done <<< "${_dataset_all_ids}"
}

# template call for DISABLING rems item
# [api location] [id]
function _curl_disable(){
    _curl PUT /api/${1}/enabled '{ "id": '${2}', "enabled": false }' || return 1
}

# template call for ARCHIVING rems item
# [api location] [id]
function _curl_archive(){
    _curl PUT /api/${1}/archived '{ "id": '${2}', "archived": true }' || return 1
}

# based on Portal/Molgenis values
# iterate through each REMS resource and catalogues and check
# if they should be DISABLED and ARCHIVED
function _rems_catalogue_archive(){
    [[ "${VERBOSE}" -ge "1" ]] && echo " Archiving Rems catalogues"
    [[ "${VERBOSE}" -ge "1" ]] && echo "  - comparing each resource "
    while read _each_rems_resource_unformatted ; do
        _each_rems_resource="${_each_rems_resource_unformatted//[\\\"\']/}"
        _exist_in_both=false
        while read _each_dataset_unformatted ; do
	    _each_dataset="${_each_dataset_unformatted//[\\\"\']/}"
            if [[ "${_each_rems_resource}" == "${_each_dataset}" ]]; then
                _exist_in_both=true
                [[ "${VERBOSE}" -ge "1" ]] && echo "      '${_each_rems_resource}' - nothing to remove"
            fi
        done <<< "${_dataset_all_ids}"
        if ! ${_exist_in_both} ; then
            echo "      > '${_each_rems_resource}' removing (reason: not defined in portal) [$(date)]"
            _current_resource_id="$(_curl GET /api/resources/  | jq -r ".[] | select (.resid==\"${_each_rems_resource}\") | .id" )"
            _current_catalogue_id="$(_curl GET /api/catalogue/  | jq -r ".[] | select (.resid==\"${_each_rems_resource}\") | .id" )"
            # disable catalogue
            _curl_disable catalogue-items  ${_current_catalogue_id}
            # archive catalogue
            _curl_archive catalogue-items ${_current_catalogue_id}
            # disable resource
            _curl_disable resources ${_current_resource_id}
            # archive resource
            _curl_archive resources ${_current_resource_id}
        fi
    done <<< "${_rems}"
}

# update each of the REMS resource and dataset: if name mismatched in Portal/Molgenis
function _rems_update_catalogue_titles(){
    [[ "${VERBOSE}" -ge "1" ]] && echo " Updating Rems catalogue titles"
    [[ "${VERBOSE}" -ge "1" ]] && echo "  - comparing each resource "
    while read _each_rems_resource_unformatted ; do
        _each_rems_resource="${_each_rems_resource_unformatted//[\\\"\']/}"
	[[ "${VERBOSE}" -ge "2" ]] && echo "       _each_rems_resource=${_each_rems_resource}"
        while read _each_dataset_unformatted ; do
            _each_dataset="${_each_dataset_unformatted//[\\\"\']/}"
	    [[ "${VERBOSE}" -ge "2" ]] && echo "       _each_dataset=${_each_dataset}"
            [[ "${VERBOSE}" -ge "2" ]] && echo "      ? ${_each_rems_resource} == ${_each_dataset}"
            if [[ "${_each_rems_resource}" == "${_each_dataset}" ]]; then
            	[[ "${VERBOSE}" -ge "2" ]] && echo "        ! ${_each_rems_resource} == ${_each_dataset}"
                { # checking title
                    _portal_resource_title_unformatted="$(jq -r ".[] | select(.id==\"${_each_dataset}\") | .title" <<< "${_dataset_all_main_info}")"
                     _portal_resource_title="${_portal_resource_title_unformatted//[\\\"\']/}"
                    _current_catalogue_id="$(_curl GET /api/catalogue/  | jq -r ".[] | select (.resid==\"${_each_rems_resource}\") | .id" )"
                    _current_catalogue_title_unformatted="$(_curl GET /api/catalogue/  | jq -r ".[] | select (.resid==\"${_each_rems_resource}\") | .\"localizations\".\"en\".\"title\"")"
                    _current_catalogue_title="${_current_catalogue_title_unformatted//[\\\"\']/}"
                    [[ "${VERBOSE}" -ge "2" ]] && {
                        echo "          _portal_resource_title   = $_portal_resource_title"
                        echo "          _current_catalogue_id    = $_current_catalogue_id"
                        echo "          _current_catalogue_title = $_current_catalogue_title"
                        echo "          ? titles '${_portal_resource_title}' != '${_current_catalogue_title}'"
                    }
                    if [[ "${_portal_resource_title}" != "${_current_catalogue_title}" ]]; then
                        _curl PUT /api/catalogue-items/edit '{ "id": '${_current_catalogue_id}', "localizations": { "en": { "title": "'${_portal_resource_title}'" } } }'
                        echo "      title of .resid==\"${_each_rems_resource}\" updated to \"${_portal_resource_title}\" [$(date)]"
                    fi
                }
            fi
        done <<< "${_dataset_all_ids}"
    done <<< "${_rems}"
}

# define all the functions calls in correct order
function _main_update(){
    _collect_portal_rems_data
    _portal_dataset_pull
    _rems_catalogue_archive
    _rems_update_catalogue_titles
}

# main loop that never ends
while : ; do
   [[ "${VERBOSE}" -ge "1" ]] && echo "starting loop [$(date)]"
   _main_update
   sleep ${MAIN_DELAY}
done

## Extra stuff

### Disable and archive for RESOURCES, FORMS, WORKFLOWS, CATALOGS and LICENSES
# [api location] [id]
function _curl_disable(){
    _curl PUT /api/${1}/enabled '{ "id": '${2}', "enabled": false }' || return 1
}
# [api location] [id]
function _curl_archive(){
    _curl PUT /api/${1}/archived '{ "id": '${2}', "archived": true }' || return 1
}
