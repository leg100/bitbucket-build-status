SHELL := /bin/bash
GOOGLE_CLOUD_PROJECT := $(shell gcloud config get-value project)

init:
	@gcloud services enable \
		cloudfunctions.googleapis.com \
  		secretmanager.googleapis.com || true
	@gcloud iam service-accounts create cloud-build-status || true
	@gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
		--member="serviceAccount:cloud-build-status@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com" \
		--role="roles/secretmanager.secretAccessor" || true

delete-sa:
	@gcloud projects remove-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
		--member="serviceAccount:cloud-build-status@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com" \
		--role="roles/secretmanager.secretAccessor" || true
	@gcloud iam service-accounts delete cloud-build-status@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com || true

create:
	@read -p "Provider [github or bitbucket]: " provider; \
	read -p "Username: " username; \
	read -s -p "Password: " password; \
	echo "{\"username\": \"$$username\", \"password\": \"$$password\"}" | \
		gcloud secrets create $$provider --data-file=-

delete:
	@read -p "Provider [github or bitbucket]: " provider; \
	gcloud secrets delete $$provider || true

rotate:
	@read -p "Provider [github or bitbucket]: " provider; \
	read -p "Username: " username; \
	read -s -p "Password: " password; \
	echo "{\"username\": \"$$username\", \"password\": \"$$password\"}" | \
		gcloud secrets versions add $$provider --data-file=-

decrypt:
	@read -p "Provider [github or bitbucket]: " provider; \
	gcloud secrets versions access latest --secret $$provider

deploy:
	gcloud functions deploy \
		cloud-build-status \
		--source . \
		--runtime python37 \
		--entry-point build_status \
		--service-account cloud-build-status@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com \
		--trigger-topic=cloud-builds

unit:
	python -m pytest -W ignore::DeprecationWarning -v

integration: integration-github integration-bitbucket

integration-github:
	source tests/integration.sh && \
		run_github_test "WORKING" "pending" && \
		run_github_test "FAILURE" "error" && \
		run_github_test "SUCCESS" "success"

integration-bitbucket:
	source tests/integration.sh && \
		run_bitbucket_test "WORKING" "INPROGRESS" && \
		run_bitbucket_test "FAILURE" "FAILED" && \
		run_bitbucket_test "SUCCESS" "SUCCESSFUL"
