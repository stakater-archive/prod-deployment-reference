#!/bin/bash
###############################################################################
# Copyright 2016 Aurora Solutions
#
#    http://www.aurorasolutions.io
#
# Aurora Solutions is an innovative services and product company at
# the forefront of the software industry, with processes and practices
# involving Domain Driven Design(DDD), Agile methodologies to build
# scalable, secure, reliable and high performance products.
#
# Stakater is an Infrastructure-as-a-Code DevOps solution to automate the
# creation of web infrastructure stack on Amazon. Stakater is a collection
# of Blueprints; where each blueprint is an opinionated, reusable, tested,
# supported, documented, configurable, best-practices definition of a piece
# of infrastructure. Stakater is based on Docker, CoreOS, Terraform, Packer,
# Docker Compose, GoCD, Fleet, ETCD, and much more.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

KEY_NAME=""
AWS_REGION=""
BUCKET_NAME=""

# Flags to make sure all options are given
rOptionFlag=false;
kOptionFlag=false;
bOptionFlag=false;
while getopts ":k:r:b:" OPTION
do
  case $OPTION in
    k)
      kOptionFlag=true;
      KEY_NAME=$OPTARG
      ;;
    r)
      rOptionFlag=true;
      AWS_REGION=$OPTARG
      ;;
    b)
      bOptionFlag=true;
      BUCKET_NAME=$OPTARG
      ;;
    *)
      echo "Usage: $(basename $0) -k <keyname> -r <aws region> -b <bucket name>"
      exit 1
      ;;
  esac
done

if ! $kOptionFlag || ! $rOptionFlag || ! $bOptionFlag;
then
  echo "Usage: $(basename $0) -k <keyname> -r <aws region> -b <bucket name>"
  exit 0;
fi

TMP_DIR="../keypair"
if  aws --region ${AWS_REGION} ec2 describe-key-pairs --key-name ${KEY_NAME} > /dev/null 2>&1 ;
then
  echo "keypair ${KEY_NAME} already exists."
else
  mkdir -p ${TMP_DIR}
  chmod 700 ${TMP_DIR}
  echo "Creating keypair ${KEY_NAME} and uploading to s3"
  aws --region ${AWS_REGION} ec2 create-key-pair --key-name ${KEY_NAME} --query 'KeyMaterial' --output text > ${TMP_DIR}/${KEY_NAME}.pem
  aws --region ${AWS_REGION} s3 cp ${TMP_DIR}/${KEY_NAME}.pem s3://${BUCKET_NAME}/keypairs/${KEY_NAME}.pem

  # Clean up
  rm -rf ${TMP_DIR}
fi