{
    type: "relationship",
    start: {
        id: .source.id,
        labels: [ if .source.type == "context" then "community" else .source.type end ],
    },
    end: {
        id: .target.id,
        labels: [ if .target.type == "context" then "community" else .target.type end ],
    },
    label: .reltype.name,
    properties: {
        type: .reltype.type,
        provenance: .provenance,
        validated: .validated,
        validationDate: .validationDate,
    }
}
