#!/bin/bash

# Ensure variables are always set before going forward.
# Will prevent this script to be runned unless called from run.sh (by design)
set -o nounset

set -o errexit

echo "Deploying on OpenStack"

source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_env_vars_set

function deploy_network(){
    echo "Starting the network deployment"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-create_network.yml
    echo "network deployment successful"
}
function deploy_ses(){
    source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_environment_is_ready_for_deploy
    echo "Starting a SES deploy"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-deploy_ses.yml
    echo "ses-ansible deploy is successful"
}
function deploy_caasp(){
    source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_environment_is_ready_for_deploy
    echo "Starting caasp deploy"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-create_caasp.yml
    echo "CaaSP deployed successfully"
}
function deploy_ccp_deployer() {
    source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_environment_is_ready_for_deploy
    echo "Creating CCP deploy node"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-deploy_ccp_deployer.yml
}
function enroll_caasp_workers() {
    echo "Enrolling caasp worker nodes into the cluster"
    run_ansible ${socok8s_absolute_dir}/playbooks/generic-enroll_caasp_workers.yml
}
function patch_upstream(){
    echo "Running dev-patcher"
    echo "Nothing will happen if developer mode is not set"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-patch_upstream.yml
}
function build_images(){
    echo "Running image builder"
    echo "Nothing will happen if developer mode is not set"
    run_ansible -e "build_osh_images=yes" ${socok8s_absolute_dir}/playbooks/openstack-build_images.yml
}
function setup_caasp_workers_for_openstack(){
    echo "Ensuring caasp workers can be used for openstack"
    run_ansible ${socok8s_absolute_dir}/playbooks/generic-setup_caasp_workers_for_openstack.yml
}
function deploy_osh(){
    echo "Now deploy SUSE version of OSH"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-deploy_osh.yml
}
function deploy_airship(){
    echo "Now deploy SUSE version of Airship"
    tagged_info=''
    tags='all'
    if [[ "${1:-default}" != 'default' ]]; then
        tagged_info=" --tags $1"
        tags=$1
        echo "Now deploy SUSE version of Airship for specific tags ( ${tags} )"
    fi
    run_ansible ${socok8s_absolute_dir}/playbooks/generic-deploy_airship.yml ${tagged_info}
}
function deploy_tempest(){
    echo "Deploying Tempest"
    run_ansible ${socok8s_absolute_dir}/playbooks/deploy_tempest.yml
}
function clean_airship(){
    clean_action=''
    action_desc='everything'
    if [[ "${1:-default}" != 'default' ]]; then
        clean_action=" -e clean_action=$1"
        action_desc=$1
    fi
    echo "DANGER ZONE. Set the env var 'DELETE_ANYWAY' to 'YES' to delete airship artifacts ( ${action_desc} ) in your userspace."
    if [[ ${DELETE_ANYWAY:-"NO"} == "YES" ]]; then
        run_ansible ${socok8s_absolute_dir}/playbooks/generic-clean_airship.yml ${clean_action}
    fi
}
function teardown(){
    if [[ ${SOCOK8S_GATHER_LOGS:-"NO"} == "YES" ]]
    then
        gather_logs
    fi
    clean_openstack
    clean_userfiles
}
function clean_k8s(){
    echo "DANGER ZONE. Set the env var 'DELETE_ANYWAY' to 'YES' to delete everything in your userspace."
    if [[ ${DELETE_ANYWAY:-"NO"} == "YES" ]]; then
        echo "DELETE_ANYWAY is set, cleaning up k8s"
        run_ansible ${socok8s_absolute_dir}/playbooks/generic-clean_k8s.yml
    fi
}
function clean_openstack(){
    echo "Deleting on OpenStack"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-osh_instance.yml -e osh_node_delete=True
    echo "Delete Caasp nodes"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-delete_caasp.yml
    echo "Delete SES node"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-ses_aio_instance.yml -e ses_node_delete=True
    echo "Delete network stack"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-delete_network.yml
}
function clean_userfiles(){
    echo "DANGER ZONE. Set the env var 'DELETE_ANYWAY' to delete everything in your userspace."
    if [[ ${DELETE_ANYWAY:-"NO"} == "YES" ]]; then
        extra_arg="-e delete_anyway='yes'"
    fi
    run_ansible ${socok8s_absolute_dir}/playbooks/generic-clean_userfiles.yml ${extra_arg:-}
}

function gather_logs(){
    echo "Gathering kubernetes logs"
    run_ansible ${socok8s_absolute_dir}/playbooks/generic-collect-logs.yml
}
