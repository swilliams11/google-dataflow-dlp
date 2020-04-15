# google-dataflow-dlp

This repository demonstrates how to create a **streaming** DataFlow job to read a CSV from GCP cloud storage, apply a 
DLP (Data Loss Prevention) template, and write the result to GCP BigQuery.  This particular example 
uses a small **tabular** sample data set to test.

## Summary
This code was taken directly from the [Google Cloud Platform template](https://cloud.google.com/dataflow/docs/guides/templates/provided-streaming#data-maskingtokenization-using-cloud-dlp-from-cloud-storage-to-bigquery-stream). 
The DataFlow job will extract the records from the sample csv file, apply the [DLP de-identification template](https://cloud.google.com/dlp/docs/creating-templates-deid),
then save the tokenized data into BigQuery.

The `deindentification-sensitive-data-with-key-template.json` template assumes you are using a tabular data (.i.e. csv with column headers).
It uses a key to tokenize your data, and you have the ability to [re-identify the original data with the DLP API](https://cloud.google.com/dlp/docs/reference/rest/v2/projects.content/reidentify).  

It will create a table in Big Query with the same name as the csv file that you upload; it also creates the 
columns with the header row in the CSV file.  If you decide to test a new
file then make sure that you follow the items listed below.  
* Follow [Big Query Naming Conventions](https://cloud.google.com/bigquery/docs/tables#table_naming) when you name your CSV file,
otherwise the job will fail. 
* Follow [Big Query Column Naming Conventions](https://cloud.google.com/bigquery/docs/schemas#column_names) when naming
your columns.  

## Source Files
* `dlp-templates/deindentification-sensitive-data-with-key-template.json` is the De-identification template that creates tokens with
a hard coded key.  This file requires that you use tabular data so the `Employee ID` column name is included in this file.
It uses the [format preserving encryption (FPE)](https://cloud.google.com/dlp/docs/transformations-reference#fpe) to encrypt
the data in the specified column.  
* `dlp-templates/deidentification-sensitive-template.json` - This template redacts the LAST_NAME and EMAIL if present in the data file.
However, it must be applied in the DataFlow job and your job must be restarted.   
* `dlp-templates/deidentification-sensitive-data-with-enckvm-template.json` is the de-identification template that uses a wrapped
key with [GCP's Key Management Service (KMS)](https://cloud.google.com/kms).  Its more secure because the key is encrypted with KMS.
* `dlp-templates/deidentification-sensitive-data-with-enckvm-template.json` is the de-identification template that uses
a deterministic config `cryptoDeterministicConfig` 
* `sample-data/employee_data.csv` - CSV file with column headers and sample data.
* `sample-data/employee_data2.csv` - a second CSV file with column headers and sample data.  
 
## Getting started  
#### 1. GCP Setup.
```shell script
export PROJECT=$(gcloud config get-value core/project)
export BUCKET=$PROJECT-dlp-example
export DLP_TEMPLATE_NAME=deidentification-sensitive-data-with-hardcoded-key
export DATASET_NAME=dataflow_dlp_example
```

* [Create a GCP bucket.](https://cloud.google.com/storage/docs/creating-buckets)
```shell script
gsutil mb gs://$BUCKET/
```

* [Enabled the APIs.](https://console.cloud.google.com/flows/enableapi?apiid=dataflow,logging,storage_component,storage_api,bigquery,datastore.googleapis.com,cloudresourcemanager.googleapis.com,dlp.googleapis.com)
* [Create a GCP Service Account](https://console.cloud.google.com/apis/credentials/serviceaccountkey) and download the credential to your local machine. 
  * From the Service account list, select New service account.
  * In the Service account name field, enter a name.
  * From the Role list, select Project > Owner.
  * Download the service account to your local machine as .json, then execute the following commands. 
```shell script
export MY_SVC_ACC_KEY=/path/toyour/credential.json
gcloud auth activate-service-account --key-file=$MY_SVC_ACC_KEY
export TOKEN=$(gcloud auth print-access-token)
```

* [Create a BigQuery dataset.](https://cloud.google.com/bigquery/docs/datasets#create-dataset)

```
bq mk $PROJECT:$DATASET_NAME
```
  
* [Create the DLP template](https://cloud.google.com/dlp/docs/reference/rest/v2/projects.deidentifyTemplates/create)
Execute this shell script.
```shell script
curl -X POST https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @/dlp-templates/deindentification-sensitive-data-with-key-template.json -i 
```

**[List existing templates](https://cloud.google.com/dlp/docs/reference/rest/v2/projects.deidentifyTemplates/list)**

```shell script
curl -X GET "https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates" \
-H "Authorization: Bearer $TOKEN"
```

**[Delete templates](https://cloud.google.com/dlp/docs/reference/rest/v2/projects.deidentifyTemplates/delete)**
```shell script
curl -X DELETE "https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates/{TEMPLATEID}" \
-H "Authorization: Bearer $TOKEN" -i
```

#### 2. Upload the sample data 
```
gcloud auth login
gsutil cp sample-data/*.csv gs://$BUCKET/
``` 

#### 3. Setup your local environment. 
Open your IDE (IntelliJ) and then open the terminal tab and execute the following commands.
* `export PROJECT=$(gcloud config get-value core/project)`
* `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/your/credential.json`
* `export BUCKET=parent_path_to_gcp_bucket_you_created_earlier`


#### 4. From your IDE (IntelliJ) terminal tab or your existing terminal window
##### De-identification Sensitive Data with Key Hardcoded in Template
This section describes how to apply the `deindentification-sensitive-data-with-key-template.json` file.

Clean and compile.
```shell script
mvn clean compile
```

This creates a batch job description named `dlp-sensitive-data-with-hardcoded-key.json`.
```shell script
 mvn compile exec:java -Dexec.mainClass=com.swilliams11.googlecloud.dataflow.dlp.DLPTextToBigQueryStreamingGenericExample -Dexec.cleanupDaemonThreads=false -Dexec.args=" \
 --project=$PROJECT \
 --stagingLocation=gs://$BUCKET/staging \
 --tempLocation=gs://$BUCKET/temp \
 --templateLocation=gs://$BUCKET/dlp-sensitive-data-with-hardcoded-key.json \
 --runner=DataflowRunner"
```

Execute the job with the required options.  This is a streaming job, so it will take a minute or two to create the 
infrastructure and start listening for GCS files.  Once the job processes the file then you can view the redacted data
in BigQuery.  
  
```shell script
gcloud dataflow jobs run dlp-sensitive-data-with-hardcoded-key \
--gcs-location=gs://$BUCKET/dlp-sensitive-data-with-hardcoded-key.json \
--zone=us-central1-f \
--parameters=inputFilePattern=gs://$BUCKET/\*.csv,\
dlpProjectId=$PROJECT,\
deidentifyTemplateName=projects/$PROJECT/deidentifyTemplates/$DLP_TEMPLATE_NAME,\
datasetName=$DATASET_NAME,\
batchSize=10
``` 

Login to Google Cloud console and view the job status and cancel it after it processes the file. 

### Redaction of Sensitive Data Template
This section describes how to include the `deindentification-sensitive-data-template.json`.  This template redacts the
data based on the pattern included in the template (Last Name and Email).  There is no way to recover the original data after it is redacted.
Therefore, you must save a copy of the original file if you need to look up the original values.

* This de-identification uses the InfoType template, which treats all the data as text to be searched.  
* TODO - update this to use record transformations instead.    

1. Change the DLP template name. 
```
export DLP_TEMPLATE_NAME=deidentification-sensitive-data
```

2. [Create the DLP templates](https://cloud.google.com/dlp/docs/reference/rest/v2/projects.deidentifyTemplates/create)
One is for the deidentification and the other is for inspection. Execute this shell script.
**Deidentify template**
```shell script
curl -X POST https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @dlp-templates/deindentification-sensitive-data-template.json -i 
```

**Inspect template**
```shell script
curl -X POST https://dlp.googleapis.com/v2/projects/$PROJECT/inspectTemplates \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @dlp-templates/inspect-sensitive-data-template.json -i 
```


3. This creates a new DataFlow job template named `dlp-sensitive-data-dfjob` and saves it to GCS.
```shell script
 mvn compile exec:java -Dexec.mainClass=com.swilliams11.googlecloud.dataflow.dlp.DLPTextToBigQueryStreamingGenericExample -Dexec.cleanupDaemonThreads=false -Dexec.args=" \
 --project=$PROJECT \
 --stagingLocation=gs://$BUCKET/staging \
 --tempLocation=gs://$BUCKET/temp \
 --templateLocation=gs://$BUCKET/dlp-sensitive-data-dfjob.json \
 --runner=DataflowRunner"
```

4. This creates a new DataFlow job named `dlp-sensitive-data` that is based on the template created in step 3. It
includes both the deidentify and inspect templates.  
**Note that the `*` is escaped below because I'm using zshell.**  
```shell script
gcloud dataflow jobs run dlp-sensitive-data \
--gcs-location=gs://$BUCKET/dlp-sensitive-data-dfjob.json \
--zone=us-central1-f \
--parameters=inputFilePattern=gs://$BUCKET/\*_name_email.csv,\
dlpProjectId=$PROJECT,\
deidentifyTemplateName=projects/$PROJECT/deidentifyTemplates/$DLP_TEMPLATE_NAME,\
inspectTemplateName=projects/$PROJECT/inspectTemplates/inspect-sensitive-data,\
datasetName=$DATASET_NAME,\
batchSize=10
```

### Redaction of Sensitive Data with KMS Wrapped Key
This section describes the `deidentification-sensitive-data-with-enckvm-key-template.json`, which uses the 
[CryptoReplaceFfxFpeConfig](https://cloud.google.com/dlp/docs/reference/rest/v2/organizations.deidentifyTemplates#cryptoreplaceffxfpeconfig)
with a [KMS Wrapped Crypto Key](https://cloud.google.com/dlp/docs/reference/rest/v2/organizations.deidentifyTemplates#DeidentifyTemplate.KmsWrappedCryptoKey).
This approach is more secure because the cryptographic key that is used to encrypt your data is not hard-coded in the
template as in the first approach.  

You will need to update your service account key that you created earlier to include the following permissions.
* Cloud KMS Admin
* Cloud KMS Decrypter
* Cloud KMS Encrypter

You may need to refresh your token. 
```shell script
gcloud auth activate-service-account --key-file=$MY_SVC_ACC_KEY
export TOKEN=$(gcloud auth print-access-token)
```

1. Enabled the Google Cloud Services API

```shell script
gcloud services enable cloudkms.googleapis.com
export LOCATION=global
```

2. Create the [Key Ring](https://cloud.google.com/kms/docs/reference/rest/v1/projects.locations.keyRings/create) 
in the `global` location.

```shell script
curl -X POST "https://cloudkms.googleapis.com/v1/projects/$PROJECT/locations/$LOCATION/keyRings?keyRingId=dlp-encryption-keys" \
-H "Authorization: Bearer $TOKEN"
export KEYRING=dlp-encryption-keys
```

3. Create the [Crypto Key](https://cloud.google.com/kms/docs/reference/rest/v1/projects.locations.keyRings.cryptoKeys/create) 
in the key ring.

```shell script
curl -X POST https://cloudkms.googleapis.com/v1/projects/$PROJECT/locations/$LOCATION/keyRings/$KEYRING/cryptoKeys?cryptoKeyId=DlpCryptoKey&skipInitialVersionCreation=false&crypto_key.purpose=ENCRYPT_DECRYPT \
-H "Authorization: Bearer $TOKEN"
export CRYPTOKEY=DlpCryptoKey
```

4. Create the [KMS Wrapped Key](https://cloud.google.com/dlp/docs/transformations-reference#fpe) by sending the 
[cryptoKeys.encrypt API request](https://cloud.google.com/kms/docs/reference/rest/v1/projects.locations.keyRings.cryptoKeys/encrypt).
This payload is the base64 encode string `hello`.  

I generated 256 random bits with the command listed below.  The [openssl command](https://www.openssl.org/docs/man1.0.2/man1/openssl-rand.html)
generates bytes - 32 random bytes (256 bits).  
  
```shell script
openssl rand 32 -base64
```

```shell script
curl -X POST "https://cloudkms.googleapis.com/v1/projects/$PROJECT/locations/$LOCATION/keyRings/$KEYRING/cryptoKeys/$CRYPTOKEY\:encrypt" \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @kms-request-data/kms-encrypt-payload.json
```

The result should be as shown below.
```json
{
  "name": "projects/YOUR_PROJECT/locations/global/keyRings/dlp-encryption-keys/cryptoKeys/DlpCryptoKey/cryptoKeyVersions/1",
  "ciphertext": "CiQAQS6oVtm6ovmEEZ/bwFfrIlRVAgiqdQziSAmYk7085ui/NyUSSABOEXzsyYS2LXBqbP4vIUUKTRZ4uEPJ+/KW9Z38a75cRFcDpPfDY2dDRe4G9rGYP+aazYJ7BCnpumqCg/rq+6ELzXl1lDNSRQ=="
}
```

You can also fetch the key that you just created. 
```shell script
curl -X GET "https://cloudkms.googleapis.com/v1/projects/$PROJECT/locations/$LOCATION/keyRings/$KEYRING/cryptoKeys/$CRYPTOKEY" \
-H "Authorization: Bearer $TOKEN"
```

You can [**decrypt**](https://cloud.google.com/kms/docs/reference/rest/v1/projects.locations.keyRings.cryptoKeys/decrypt)
the text using the following command. 
```shell script
curl -X POST "https://cloudkms.googleapis.com/v1/projects/$PROJECT/locations/$LOCATION/keyRings/$KEYRING/cryptoKeys/$CRYPTOKEY\:decrypt?name=projects/$PROJECT/locations/$LOCATION/keyRings/dlp-encryption-keys/cryptoKeys/DlpCryptoKey" \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @kms-request-data/kms-decrypt-payload.json -i
``` 
 
5. Update the CryptoKey name in the template before you upload it.  Execute the following script.  This script will 
replace `REPLACE_WITH_YOUR_CRYPTO_KEY_NAME` with the cryptoKeyName `projects/PROJECT/locations/global/keyRings/KEY_RING_NAME/cryptoKeys/CRYPTO_KEY_NAME`. 
```shell script
chmod +X scripts/update-deidentification-template.sh
./scripts/update-deidentification-template.sh
```
 
6. Create the template.
 Use this script to setup a template for the `CryptoReplaceFfxFpeConfig`.
 ```shell script
curl -X POST https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @dlp-templates/deindentification-sensitive-data-with-enckvm-key-template.json -i 
 ```

Use this script to setup a template for the `cryptoDeterministicConfig`. 
TODO - update documentation on this; I have tested this flow.  
```shell script
curl -X POST https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d @dlp-templates/deindentification-sensitive-data-with-enckvm-deterministic-key-template.json -i 
 ``` 

**You can also delete the `CryptoReplaceFfxFpeConfig` template with the following command.**
```shell script
curl -X DELETE https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates/deidentification-sensitive-data-with-kms-key \
-H "Authorization: Bearer $TOKEN"
```

**You can also delete the `cryptoDeterministicConfig` template with the following command.**
```shell script
curl -X DELETE https://dlp.googleapis.com/v2/projects/$PROJECT/deidentifyTemplates/deidentification-sensitive-data-with-kms-key-deterministic \
-H "Authorization: Bearer $TOKEN"
```


7. Update the DataFlow job to include the new template.  

I use `zshell` so I have to escape the `*` below. 

```shell script
gcloud auth login

export DLP_TEMPLATE_NAME=deidentification-sensitive-data-with-kms-key

mvn compile exec:java -Dexec.mainClass=com.swilliams11.googlecloud.dataflow.dlp.DLPTextToBigQueryStreamingGenericExample -Dexec.cleanupDaemonThreads=false -Dexec.args=" \
 --project=$PROJECT \
 --stagingLocation=gs://$BUCKET/staging \
 --tempLocation=gs://$BUCKET/temp \
 --templateLocation=gs://$BUCKET/dlp-sensitive-data-with-kms-key.json \
 --runner=DataflowRunner"

gcloud dataflow jobs run dlp-sensitive-data-with-kms-key \
--gcs-location gs://$BUCKET/dlp-sensitive-data-with-kms-key.json \
--zone=us-central1-f \
--parameters=inputFilePattern=gs://$BUCKET/\*.csv,\
dlpProjectId=$PROJECT,\
deidentifyTemplateName=projects/$PROJECT/deidentifyTemplates/$DLP_TEMPLATE_NAME,\
datasetName=$DATASET_NAME,\
batchSize=10
``` 

## Run your code in IntelliJ IDEA
Follow this section if you want to execute this code on your local machine.  Create a new configuration under 
**Application** so you can debug and trace the code locally. It's easier to troubleshoot this way.  
 
Set the following environment variables in the run/debug configuration.
* PROJECT = YOUR_GCP_PROJECT
* BUCKET = $PROJECT-dlp-example
* DLP_TEMPLATE_NAME = deidentification-sensitive-data-with-kms-key
* DATASET_NAME = dataflow_dlp_example
* GOOGLE_APPLICATION_CREDENTIALS=/your/path/to/service/account.json - you must set this environment variable to 
a service account that can access GCS, DLP, KMS and BigQuery if you want to access GCP resources locally.

Copy the following into `Program Arguments` section and make sure to replace the ${} values with your hard coded values.
**I tried to use command below in IntelliJ, but it did not replace the ${} with the environment variables as 
[per their docs](https://www.jetbrains.com/help/idea/run-debug-configuration-application.html#vm_options).** So you have 
replace all the environment variables with hard coded values.  

```shell script
--project=${PROJECT}
--runner=DirectRunner
--zone=us-central1-f
--inputFilePattern=gs://${BUCKET}/\*.csv
--dlpProjectId=$PROJECT
--deidentifyTemplateName=projects/${PROJECT}/deidentifyTemplates/${DLP_TEMPLATE_NAME}
--datasetName=${DATASET_NAME}
--batchSize=10
--defaultWorkerLogLevel=DEBUG
```

Include the `output` property if you want to write logging information to a file.  
```shell script
--output=./local-output
```

**TestDataflowRunner**
```shell script
--project=$PROJECT
--runner=TestDataflowRunner
--zone=us-central1-f
--inputFilePattern=gs://$BUCKET/\*.csv
--dlpProjectId=$PROJECT
--deidentifyTemplateName=projects/$PROJECT/deidentifyTemplates/$DLP_TEMPLATE_NAME
--datasetName=$DATASET_NAME
--batchSize=10
```


## Re-identify your Data
TODO - demo how to do this with this api https://cloud.google.com/dlp/docs/reference/rest/v2/projects.content/reidentify
TODO - include GCP CLI command as well.

## Results
### DataFlow Job
#### DLPTextToBigQueryStreamingGenericExample pipeline
This is the job graph.
![DLP streaming job](/images/dlp-streaming-job.png)

## TODOS
* Update `Redaction of Sensitive Data with KMS Wrapped Key` section to use python code or shell script instead of manually 
copying and pasting API requests. 
* Update with screen shots of using a KMS Wrapped Key after support resolves my Unknown CryptoKey error.  

