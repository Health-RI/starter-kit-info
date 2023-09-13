# for testing only:
#   _postfix="1" would create UMCG1 organization, and inside
#                all the main items (forms, license, workflow) with the same name postfix
_postfix=""


# default values of Organization/License/Form/Workflow/Catalogue: ID's, titles, content
_organization_id="umcg${_postfix}"
_organization_short_name="${_organization_id}"
_organization_name="Universitair Medisch Centrum Groningen${_postfix}"

_license_title="Main License Agreement${_postfix}"
_license_textcontent="The data here is a placeholder until the actual data will be uploaded.\nViewing, (re)using or accessing of the data on this website/server and connected resources, is permitted upon request and only after access request has been granted by this website owner."

_resource_id="urn:gdi:example-dataset${_postfix}"
_resource_org_id="${_organization_id}"
_resource_title="Dataset${_postfix}"
_resource_textcontent="resource textcontend"

_form_title="Data Access Request Form${_postfix}"
_form_internal_name="${_form_title}"
_form_external_title="${_form_title}"

_workflow_title="Default Workflow${_postfix}"
#_form_id="7"       # uncomment this to fix against specific form

_catalogue_title="example cataloge dataset${_postfix}"

# re to check the numbers
re='^[0-9]+$'


# mail helper curl for Portal/Moglenis, to call later with few parameters
# instead of 10 lines
# parameters [PUT] ["base API URL"] ["archived" or "enabled"] [item ID number] [archived or enabled boolean "true" or "false"]
function _curl(){
    _mode="${1}"        # PUT (or GET / POST)
    _api="${2}"         # api/licenes/enables
    shift 2
    _data="${*}"        # json data to be sumbitted
    _command="curl -s -X ${_mode} ${REMS_URL}${_api} \
        -H \"content-type: application/json\" \
        -H \"x-rems-api-key: $API_KEY\" \
        -H \"x-rems-user-id: $REMS_OWNER\" \
        -d '${_data}'"
    _curl_return=$(eval "${_command}")
    _curl_return_id=$(echo "${_curl_return}" | jq .id 2>/dev/null)
    _curl_success=$(echo "${_curl_return}" | jq .success 2>/dev/null)
    if [[ ${_mode} != "GET" ]]; then
        if [[ ${_curl_success} == "true" ]]; then echo "success"; return 0;
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

# create a bot to auto-approve applications
function bot(){
    _curl POST /api/users/create '{ "userid": "approver-bot", "name": "Approver Bot", "email": null }' || return 1
}

# create an organization which will hold all data
function organization(){
    # check if organization is already created
    _curl GET /api/organizations/${_organization_id}

    _data='{
                "organization/id": "'${_organization_id}'",
                "organization/short-name": {
                    "en": "'${_organization_short_name}'"
                },
                "organization/name": {
                    "en": "'${_organization_name}'"
                }
            }'
    _curl POST /api/organizations/create ${_data}
}

function license(){
    # create a license for a resource
    _data='{
                "licensetype": "text",
                "organization": {
                    "organization/id": "'${_organization_id}'"
                },
                "localizations": {
                    "en": {
                        "title": "'${_license_title}'",
                        "textcontent": "'${_license_textcontent}'"
                    }
                }
            }'
    _curl POST /api/licenses/create ${_data}
    _license_id=${_curl_return_id}
}

# create a form for the dataset application process
# extra fields explained @ https://rems-demo.rahtiapp.fi/swagger-ui/index.html#/forms/post_api_forms_create
function form(){
    #/api/forms/{form-id}
    _data='{
                "form/title": "'${_form_title}'",
                "form/internal-name": "'${_form_internal_name}'",
                "form/external-title": {
                    "en": "'${_form_external_title}'"
                },
                "form/fields": [
                    {
                        "field/title": {
                            "en": "Affiliation"
                        },
                        "field/type": "texta",
                        "field/max-length": 600,
                        "field/optional": false,
                        "field/placeholder": { "en": "Enter employment information or affiliation with any other organization." }
                    },
                    {
                        "field/title": {
                            "en": "Position"
                        },
                        "field/type": "text",
                        "field/max-length": null,
                        "field/optional": false
                    },
                    {
                        "field/title": {
                            "en": "Co-applicants"
                        },
                        "field/type": "texta",
                        "field/max-length": 1000,
                        "field/optional": false,
                        "field/placeholder": { "en": "Include full postal and email address for each co-applicant." }
                    },
                    {
                        "field/title": {
                            "en": "Title of the study"
                        },
                        "field/type": "texta",
                        "field/max-length": 200,
                        "field/optional": false,
                        "field/placeholder": { "en": "Enter the title of the study (less than 30 words)" }
                    },
                    {
                        "field/title": {
                            "en": "Study description"
                        },
                        "field/type": "texta",
                        "field/max-length": 2000,
                        "field/optional": false,
                        "field/placeholder": { "en": "Please describe the study in no more than 750 words.\n1. Outline of the study design\n2. An indication of the methodologies to be used\n3. Proposed use of the project data\n4. Preceding peer-reviews of the study (if any present)\n5. Specific details of what you plan to do with the project data\n6. Timeline\n7. Key references" }
                    }
                ],
                "organization": {
                    "organization/id": "'${_organization_id}'"
                }
            }'
            _curl POST /api/forms/create ${_data}
            _form_id=${_curl_return_id}
}

# create a workflow (DAC) to handle the application, here the auto-approve bot will handle it
function workflow(){
    _data='{
                "organization": {
                    "organization/id": "'${_organization_id}'"
                },
                "title": "'${_workflow_title}'",
                "forms": [
                    {
                        "form/id": '${_form_id}'
                    }
                ],
                "type": "workflow/default",
                "handlers": [
                    "approver-bot"
                ],
                "licenses": [ { "license/id": '${_license_id}' } ]
            }'
    _curl POST /api/workflows/create ${_data}
    _workflow_id=${_curl_return_id}
}


function resource(){
    _data='{
                "resid": "'${_resource_id}'",
                "organization": {
                    "organization/id": "'${_organization_id}'"
                },
                "licenses": ['${_license_id}']
            }'
    _curl POST /api/resources/create ${_data}
    _resource_id=${_curl_return_id}
}

# finally create a catalogue item, so that the dataset shows up on the main page
function catalogue(){
    _data='{
                "organization": {
                    "organization/id": "'${_organization_id}'"
                },
                "form": '${_form_id}',
                "resid": '${_resource_id}',
                "wfid": '${_workflow_id}',
                "localizations": {
                    "en": {
                        "title": "'${_catalogue_title}'"
                    }
                },
                "enabled": true,
                "archived": false
            }'
    _curl POST /api/catalogue-items/create ${_data}
    _catalogue_id=${_curl_return_id}
}

### Disable and archive for RESOURCES, FORMS, WORKFLOWS, CATALOGS and LICENSES
# [api location] [id]
function _curl_disable(){
    _curl PUT /api/${1}/enabled '{ "id": '${2}', "enabled": false }' || return 1
}
# [api location] [id]
function _curl_archive(){
    _curl PUT /api/${1}/archived '{ "id": '${2}', "archived": true }' || return 1
}

### Disable and archive for ORGANIZATIONS
# [api location] [id]
function _curl_disable_org(){
    _curl PUT /api/${1}/enabled '{ "organization/id": "'${2}'", "enabled": false }' || return 1
}
# [api location] [id]
function _curl_archive_org(){
    _curl PUT /api/${1}/archived '{ "organization/id": "'${2}'", "archived": true }' || return 1
}

function main_run(){
    # bot

    # either hardcoding the organization value (for items to be stored to)
    # or comment it and uncomment #organization function below
    _organization_id="umcg"
    # organization

    # either hardcoding the license ID value (for items to be stored to)
    # or comment it and uncomment #license function below
    _license_id="3"
    #license

    # either hardcoding the form ID value (for items to be stored to)
    # or comment it and uncomment #form function below
    _form_id="3"
    #form

    # either hardcoding the workflow ID value (for items to be stored to)
    # or comment it and uncomment #workflow function below
    _workflow_id="5"
    #workflow
}

main_run

# this is an example function on how to archive all the items
#function archive_all(){
#    _curl_disable catalogue-items ${_catalogue_id} || return 1
#    _curl_archive catalogue-items ${_catalogue_id} || return 1
#
#    _curl_disable resources ${_resource_id} || return 1
#    _curl_archive resources ${_resource_id} || return 1
#
#    _curl_disable workflows ${_workflow_id} || return 1
#    _curl_archive workflows ${_workflow_id} || return 1
#
#    _curl_disable forms ${_form_id} || return 1
#    _curl_archive forms ${_form_id} || return 1
#
#    _curl_disable licenses ${_license_id} || return 1
#    _curl_archive licenses ${_license_id} || return 1
#
#    _curl_disable_org organizations ${_organization_id} || return 1
#    _curl_archive_org organizations ${_organization_id} || return 1
#}
