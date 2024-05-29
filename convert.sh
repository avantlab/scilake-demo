#!/bin/bash
set -e

apply_jq() {
    zcat "$2"/*.*.gz | jq --compact-output -f "$1" -
}

CONVERTERS="$(dirname -- "$0")/converters"

(
    rm -rf ag/mapped
    mkdir -p ag/mapped
    apply_jq "${CONVERTERS}/community2vertex.jq" communities_infrastructures \
            | gzip > ag/mapped/01-community.json.gz \
            && echo "Finished converting communities ..." &
    apply_jq "${CONVERTERS}/datasource2vertex.jq" datasource \
            | gzip > ag/mapped/02-datasource.json.gz \
            && echo "Finished converting datasource ..." &
    apply_jq "${CONVERTERS}/organization2vertex.jq" organization \
            | gzip > ag/mapped/03-organization.json.gz \
            && echo "Finished converting organization ..." &
    apply_jq "${CONVERTERS}/project2vertex.jq" project \
            | gzip > ag/mapped/04-project.json.gz \
            && echo "Finished converting project ..." &
    apply_jq "${CONVERTERS}/result2vertex.jq" publication \
            | gzip > ag/mapped/05-publication.json.gz \
            && echo "Finished converting publication ..." &
    apply_jq "${CONVERTERS}/result2vertex.jq" dataset \
            | gzip > ag/mapped/06-dataset.json.gz \
            && echo "Finished converting dataset ..." &
    apply_jq "${CONVERTERS}/result2vertex.jq" software \
            | gzip > ag/mapped/07-software.json.gz \
            && echo "Finished converting software ..." &
    apply_jq "${CONVERTERS}/result2vertex.jq" otherresearchproduct \
            | gzip > ag/mapped/08-otherresearchproduct.json.gz \
            && echo "Finished converting otherresearchproducts ..." &
    apply_jq "${CONVERTERS}/relation2edge.jq" relation \
            | gzip > ag/mapped/10-relation.json.gz \
            && echo "Finished converting relations ..." &

    wait
)
