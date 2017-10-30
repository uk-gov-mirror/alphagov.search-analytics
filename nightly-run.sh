#!/bin/bash
set -e
set -o pipefail

if [ \! -d ENV ]; then virtualenv ENV; fi
. ENV/bin/activate
pip install -r requirements.txt
rm -f page-traffic.dump
PYTHONPATH=. python scripts/fetch.py page-traffic.dump 14
SEARCH_NODE=$(/usr/local/bin/govuk_node_list -c search --single-node)
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; govuk_setenv rummager bundle exec ./bin/page_traffic_load)' < page-traffic.dump

ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; PROCESS_ALL_DATA=true RUMMAGER_INDEX=mainstream CONFIRM_INDEX_MIGRATION_START=true govuk_setenv rummager bundle exec rake rummager:migrate_schema)'
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; PROCESS_ALL_DATA=true RUMMAGER_INDEX=detailed CONFIRM_INDEX_MIGRATION_START=true govuk_setenv rummager bundle exec rake rummager:migrate_schema)'
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; PROCESS_ALL_DATA=true RUMMAGER_INDEX=government CONFIRM_INDEX_MIGRATION_START=true govuk_setenv rummager bundle exec rake rummager:migrate_schema)'
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; RUMMAGER_INDEX=govuk CONFIRM_INDEX_MIGRATION_START=true govuk_setenv rummager bundle exec rake rummager:migrate_schema)'

ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; govuk_setenv rummager bundle exec rake rummager:sync_govuk)'

ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; RUMMAGER_INDEX=all govuk_setenv rummager bundle exec rake rummager:clean)'
