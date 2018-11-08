REPO=https://github.com/mcanoy/angular-unit-testing.git
PROJECT_PREFIX=sample
S2I_BASE_IMAGE=httpd:2.4
APPLIER_VERSION=v2.0.3
NAME=my_app

usage()
{
    echo "usage: setup.sh [[[-n name] [-r repo] [-p project-prefix] [-b s2i-base-image]] | [-h]]"
}

while [ "$1" != "" ]; do
    case $1 in
        -r | --repo )           shift
                                REPO=$1
                                ;;
        -b | --s2i-base-image)  shift
                                S2I_BASE_IMAGE=$1
                                ;;
        -n | --name )           shift
                                NAME=$1
                                ;;
        -p | --project-prefix)  shift
                                PROJECT_PREFIX=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

echo "Name is $NAME"
echo "Base image is $S2I_BASE_IMAGE"
echo "Prefix is $PROJECT_PREFIX"
echo "Repo is $REPO"

mkdir -p .openshift-applier/inventory/host_vars
mkdir .openshift-applier/openshift-templates
mkdir .openshift-applier/params

touch .openshift-applier/openshift-templates/$NAME-deploy.yml

cat <<EOT>> .openshift-applier/inventory/hosts
[app]
$NAME-inventory ansible_connection=local

EOT


cat <<EOT >> .openshift-applier/requirements.yml
# This is the Ansible Galaxy requirements file to pull in the correct roles
# to support the operation of CASL provisioning/runs. 
# version 2 of the applier is newer than version 3

# From 'openshift-applier'
- src: https://github.com/redhat-cop/openshift-applier
  scm: git
  version: $APPLIER_VERSION
  name: openshift-applier

EOT

cat <<EOT>> .openshift-applier/inventory/host_vars/$NAME-inventory.yml
---
openshift_cluster_content:
- object: app-builds
  content:
  - name: $NAME-build
    template: "https://raw.githubusercontent.com/rht-labs/labs-ci-cd/master/openshift-templates/s2i-app-build/binary-template-no-secrets.yml"
    params_from_vars: "{{ build }}"
    namespace: "{{ ci_cd_namespace }}"
    tags:
    - build
- object: dev-stage
  content:
  - name: $NAME-dev-deploy
    template: "{{ playbook_dir }}/openshift-templates/$NAME-deploy.yml"
    params_from_vars: "{{ dev_deploy }}"
    namespace: "{{ dev_namespace }}"
    tags:
    - dev
    - dev-deploy
- object: demo-stage
  content:
  - name: $NAME-demo-deploy
    template: "{{ playbook_dir }}/openshift-templates/$NAME-deploy.yml"
    params_from_vars: "{{ demo_deploy }}"
    namespace: "{{ demo_namespace }}"
    tags:
    - demo
    - demo-deploy

EOT

cat <<EOT>> .openshift-applier/apply.yml
---
- name: $NAME
  hosts: app
  vars:
    ci_cd_namespace: $PROJECT_PREFIX-ci-cd
    dev_namespace: $PROJECT_PREFIX-dev
    demo_namespace: $PROJECT_PREFIX-demo
    app_name: $NAME
    build:
      PIPELINE_SOURCE_REPOSITORY_URL: $REPO
      PIPELINE_SOURCE_REPOSITORY_REF: master
      NAME: "{{ app_name }}" 
      S2I_BASE_IMAGE: $S2I_BASE_IMAGE
    dev_deploy:
      NAME: "{{ app_name }}"
      DEPLOY_IMAGE_STREAM_TAG_NAME: deployed
    demo_deploy:
      NAME: "{{ app_name }}" 
      DEPLOY_IMAGE_STREAM_TAG_NAME: deployed
  tasks:
    - include_role:
        name: openshift-applier/roles/openshift-applier

EOT

cat <<EOT >> .openshift-applier/README.md
# OpenShift Applier for Labs

https://github.com/redhat-cop/openshift-applier

# Usage

Install Requirements if not already installed.

\`[.openshift-applier]\$ ansible-galaxy install -r requirements.yml --roles-path=roles\`

Right now limited to using ansible on your localhost.

\`[.openshift-applier]\$ ansible-playbook apply.yml -i inventory/\`

See the inventory for the filter tag options.

EOT


echo "Ensure you edit your deployment config file - $NAME-deploy.yml"
