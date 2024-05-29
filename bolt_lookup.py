#!/usr/bin/env python3
from neo4j import GraphDatabase

QUERY = """
MATCH (result:result{id:"50|a21a1b1477ad::93648cc837d3a95091032260ae3aa29e"})
RETURN result
"""

driver = GraphDatabase.driver("bolt://localhost:7687")
session = driver.session()

result = session.run(QUERY)
for entry in result.data(*result.keys()):
    print(entry)
