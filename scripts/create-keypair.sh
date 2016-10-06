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