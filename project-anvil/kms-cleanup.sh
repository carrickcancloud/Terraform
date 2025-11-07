#!/bin/bash

REGION="us-east-1"

# List of Customer Managed Keys (IDs only; you can also parse your JSON into this array)
KEYS=(
007f224a-eb83-4df1-bba9-ca78a008706a
263c21f7-e805-47f3-a02a-5bf4b51b102b
3bd40e5d-763e-46db-a3d8-0c4ecbca6a9a
4dfe73d2-ca9c-408e-b6b8-089977baab0f
4e780d8b-bf47-4386-8db9-7d151838224c
4ebf3ec7-5343-4923-897a-9cde1bf38e87
632b83d6-daac-4014-a26d-e9cecc2c2eca
6375d03b-7888-4098-a340-071e3269db74
63b90a40-df30-4d77-94c2-bbecb209afbc
6a03e5fc-59f5-4742-9a07-c59fd7c89478
6f153447-cf2f-4772-9937-7f55b3651f1c
77409d12-3f92-4a3e-a8a4-808ef2a846cc
80a32d38-dd4e-4915-b580-fff962b767ba
86d6f779-b1b5-40ab-b88a-5fd7bca27d67
9f032561-a6df-4978-a1b6-a25122cad098
a4ba280c-6cd6-4cc7-b929-2cb1b310fd53
a8588146-3f43-40f4-a97e-934cbcf3f578
b1b8e9a3-f6a1-466d-90fc-0ceddd24dd12
b1e08b60-305c-46ee-8aaf-c12aa6d3a05e
b4f82ad1-cbb6-48a8-82ee-a223624cc73e
b607d2d3-5c95-44f9-bbfd-c4a10194096b
b6d97ccc-4d37-44ce-8f44-5f1dd5dad674
bb419658-c64c-4cb0-83d9-d27f0150d474
c402f539-b7d6-480d-89ee-68288132e2f2
c89ac30a-ba2f-445a-a378-a5ac883a2480
c9c33041-102c-4afd-8ec3-175d5ef157a2
cafb7ef0-5791-4d69-ac34-2b4e50d8163f
d4dcbac1-5daa-4cf5-9592-be923c0f078d
ddf415f9-c291-424e-ab79-3cf97e347a1b
e484faed-558a-4be6-8803-0ed4dff83b7c
ea551964-c619-4d89-bec8-0698dbf75fcc
eec04cff-601b-42d3-8546-5dca72246f47
eef2c837-958b-4b5f-bdee-b39b569a2c9e
fedee238-fbff-4c0d-987b-c1359ab02ba5
fefe935c-7c6e-4689-835f-7bf14b25b5da
)

for key in "${KEYS[@]}"; do
  ARN="arn:aws:kms:us-east-1:047719623795:key/$key"
  IN_USE=0

  # Check Secrets Manager
  if aws secretsmanager list-secrets --region $REGION --query "SecretList[?KmsKeyId=='$ARN'].[Name]" --output text | grep -q .; then
    echo "$key is IN USE by Secrets Manager"
    IN_USE=1
  fi

  # Check S3 buckets
  for bucket in $(aws s3api list-buckets --query "Buckets[*].Name" --output text); do
    KMS_ID=$(aws s3api get-bucket-encryption --bucket "$bucket" --region $REGION 2>/dev/null | jq -r '.ServerSideEncryptionConfiguration.Rules[].ApplyServerSideEncryptionByDefault.KMSMasterKeyID // empty')
    if [[ "$KMS_ID" == "$ARN" ]]; then
      echo "$key is IN USE by S3 bucket $bucket"
      IN_USE=1
    fi
  done

  # Check DynamoDB tables
  for table in $(aws dynamodb list-tables --region $REGION --output text); do
    DDB_KMS=$(aws dynamodb describe-table --table-name "$table" --region $REGION | jq -r '.Table?.SSEDescription?.KMSMasterKeyArn // empty')
    if [[ "$DDB_KMS" == "$ARN" ]]; then
      echo "$key is IN USE by DynamoDB table $table"
      IN_USE=1
    fi
  done

  # Optionally, check RDS, EBS, etc.

  # If not in use, schedule for deletion
  if [[ $IN_USE -eq 0 ]]; then
    echo "$key is NOT in use. Scheduling deletion..."
    aws kms schedule-key-deletion --key-id "$key" --region $REGION --pending-window-in-days 7
  fi
done

