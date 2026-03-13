# PuppetDB Query Guide for MegaRAID Controllers

This guide provides PuppetDB queries to identify and inventory MegaRAID controllers across your infrastructure using the facts provided by the puppet-storcli module.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Queries](#quick-queries)
- [Detailed Queries](#detailed-queries)
- [Analysis Queries](#analysis-queries)
- [Command-Line Examples](#command-line-examples)
- [REST API Examples](#rest-api-examples)

## Prerequisites

1. PuppetDB must be installed and configured
2. The puppet-storcli module must be deployed to nodes with MegaRAID controllers
3. Facts must be synced to PuppetDB (happens automatically during Puppet runs)

## Quick Queries

### List All Hosts with MegaRAID Controllers

**PQL Query:**
```puppet
facts[certname, value] {
  name = "megaraid" and
  value.present? = true
}
```

**PuppetDB API (JSON):**
```json
["from", "facts",
  ["extract", ["certname", "value"],
    ["and",
      ["=", "name", "megaraid"],
      ["=", ["fact", "megaraid.present?"], true]
    ]
  ]
]
```

### List All Different Controller Models

**PQL Query:**
```puppet
facts[value] {
  name = "megaraid" and
  value.controllers ~ "%"
} | group_by(value.controllers.*.product_name)
```

**Simplified - Get Unique Product Names:**
```puppet
facts {
  name = "megaraid" and
  value.controllers ~ "%"
} | extract certname, value.controllers.*.product_name | unique()
```

### Count Hosts by Controller Model

**PQL Query:**
```puppet
facts[certname] {
  name = "megaraid" and
  value.controllers ~ "%"
} | group_by(certname, value.controllers.*.product_name)
```

## Detailed Queries

### All Controller Details Across Infrastructure

Get complete inventory of all controllers with their product names, serial numbers, and firmware versions:

**PQL Query:**
```puppet
facts[certname, value] {
  name = "megaraid" and
  value.number_of_controllers > 0
}
```

**With Extraction (more readable):**
```puppet
inventory[certname] {
  facts.megaraid.number_of_controllers > 0
} | extract certname,
    facts.megaraid.number_of_controllers,
    facts.megaraid.controllers
```

### Hosts with Specific Controller Model

Find all hosts with AVAGO 3108 MegaRAID controllers:

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.controllers.*.product_name ~ "3108"
}
```

### Hosts with Dell PERC Controllers

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.controllers.*.product_name ~ "PERC"
}
```

### Controllers by Firmware Version

Find all controllers and their firmware versions:

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.number_of_controllers > 0
} | extract certname,
    facts.megaraid.controllers.*.product_name,
    facts.megaraid.controllers.*.fw_version
```

### Find Outdated Firmware

Find controllers with firmware older than a specific version (example: 4.680.00):

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.number_of_controllers > 0 and
  facts.megaraid.controllers.*.fw_version < "4.680.00"
}
```

### Multi-Controller Systems

Find hosts with more than one controller:

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.number_of_controllers > 1
}
```

## Analysis Queries

### Hostname-to-Firmware Mapping

**Get a complete mapping of hostname to firmware version:**

```puppet
inventory[certname] {
  facts.megaraid.number_of_controllers > 0
} | extract certname, 
    facts.megaraid.controllers.*.product_name,
    facts.megaraid.controllers.*.fw_version,
    facts.megaraid.controllers.*.serial_number
```

**Expected output shows hostname first:**
```json
[
  {
    "certname": "server01.example.com",
    "facts.megaraid.controllers.*.product_name": ["AVAGO 3108 MegaRAID"],
    "facts.megaraid.controllers.*.fw_version": ["4.680.00-8290"],
    "facts.megaraid.controllers.*.serial_number": ["FW-BAMQTHEAARBWA"]
  },
  {
    "certname": "server02.example.com",
    "facts.megaraid.controllers.*.product_name": ["Dell PERC H730P"],
    "facts.megaraid.controllers.*.fw_version": ["25.5.5.0005"],
    "facts.megaraid.controllers.*.serial_number": ["CN0H730P12345"]
  }
]
```

### Group Hosts by Firmware Version

**See which hosts are running each firmware version:**

```puppet
inventory[certname] {
  facts.megaraid.number_of_controllers > 0
} | extract certname, facts.megaraid.controllers.*.fw_version
```

Then use jq to group:
```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.fw_version' \
--render-as json | jq 'group_by(.["facts.megaraid.controllers.*.fw_version"][0])'
```

### Group by Controller Type

Get a summary of controller types with hostnames in your infrastructure:

**PQL Query:**
```puppet
facts {
  name = "megaraid" and
  value.controllers ~ "%"
} | extract certname,
    value.controllers.0.product_name as controller_0,
    value.controllers.1.product_name as controller_1,
    value.controllers.2.product_name as controller_2
```

### Controllers with Patrol Read Enabled

Find all controllers with patrol read in auto mode:

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.controllers.*.patrol_read."PR Mode" ~ "Auto"
}
```

### Controllers with Consistency Check Enabled

Find all controllers with consistency check in concurrent mode:

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.controllers.*.consistency_check."CC Operation Mode" ~ "Concurrent"
}
```

### Virtual Drive Cache Policies

Find hosts with specific cache policies (e.g., write-back cache):

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.controllers.*.virtual_drives.*."Write Cache" = "wb"
}
```

### Controllers by Serial Number

Track specific controllers by serial number:

**PQL Query:**
```puppet
inventory[certname] {
  facts.megaraid.controllers.*.serial_number = "FW-BAMQTHEAARBWA"
}
```

## Command-Line Examples

### Using `puppet query`

List all hosts with MegaRAID controllers:
```bash
puppet query 'inventory[certname] { facts.megaraid.present? = true }'
```

Get controller models across infrastructure:
```bash
puppet query 'inventory[certname] { facts.megaraid.number_of_controllers > 0 } | 
  extract certname, facts.megaraid.controllers.*.product_name'
```

Count controllers by type:
```bash
puppet query 'facts { name = "megaraid" } | 
  extract value.controllers.*.product_name | unique()'
```

### Using `curl` with PuppetDB API

**Get all hosts with controllers:**
```bash
curl -X GET \
  https://puppetdb:8081/pdb/query/v4/inventory \
  -H 'Content-Type: application/json' \
  --data-urlencode 'query=["extract", "certname",
    ["=", ["fact", "megaraid.present?"], true]]' \
  --cert /etc/puppetlabs/puppet/ssl/certs/client.pem \
  --key /etc/puppetlabs/puppet/ssl/private_keys/client.pem \
  --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem
```

**Get controller details:**
```bash
curl -X GET \
  https://puppetdb:8081/pdb/query/v4/facts/megaraid \
  --cert /etc/puppetlabs/puppet/ssl/certs/client.pem \
  --key /etc/puppetlabs/puppet/ssl/private_keys/client.pem \
  --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem
```

## REST API Examples

### Query All Controller Facts

**Endpoint:** `GET /pdb/query/v4/facts/megaraid`

**Response:** Returns all megaraid facts from all nodes

### Query with Filtering

**Endpoint:** `POST /pdb/query/v4/facts`

**Body:**
```json
{
  "query": [
    "and",
    ["=", "name", "megaraid"],
    ["=", ["fact", "megaraid.present?"], true]
  ]
}
```

### Structured Query for Analysis

Get controller models grouped by count:

**Endpoint:** `POST /pdb/query/v4/facts`

**Body:**
```json
{
  "query": [
    "extract",
    ["certname", "value"],
    [
      "and",
      ["=", "name", "megaraid"],
      [">", ["fact", "megaraid.number_of_controllers"], 0]
    ]
  ]
}
```

## Common Use Cases

### 1. Inventory Report

Generate a CSV-style inventory report:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract 
  certname, 
  facts.megaraid.number_of_controllers as num_controllers,
  facts.megaraid.controllers.0.product_name as controller_0_model,
  facts.megaraid.controllers.0.serial_number as controller_0_serial,
  facts.megaraid.controllers.0.fw_version as controller_0_fw
' --render-as json | jq -r '.[] | [.certname, .num_controllers, .controller_0_model, .controller_0_serial, .controller_0_fw] | @csv'
```

### 2. Security Audit - Find Specific Firmware

Find controllers that may have a security vulnerability in a specific firmware version:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.fw_version = "4.680.00-8290"
}'
```

### 3. Maintenance Planning

Find all Dell PERC controllers for maintenance planning:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.product_name ~ "PERC"
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version'
```

### 4. Cache Policy Audit

Find all virtual drives not using write-through cache:

```bash
puppet query 'inventory[certname] {
  facts.megaraid.controllers.*.virtual_drives.*."Write Cache" != "wt"
}'
```

## Dashboard Integration

### Grafana/Prometheus

If you're using PuppetDB exporter for Prometheus, you can create dashboards showing:

- Count of controllers by model
- Firmware version distribution
- Cache policy distribution
- Patrol read status across fleet

### Custom Scripts

Use Python/Ruby scripts to query PuppetDB and generate reports:

**Python Example:**
```python
import requests
import json

puppetdb_url = "https://puppetdb:8081/pdb/query/v4"
cert = ("/etc/puppetlabs/puppet/ssl/certs/client.pem", 
        "/etc/puppetlabs/puppet/ssl/private_keys/client.pem")
verify = "/etc/puppetlabs/puppet/ssl/certs/ca.pem"

query = {
    "query": [
        "extract",
        ["certname", "value"],
        ["=", "name", "megaraid"]
    ]
}

response = requests.post(
    f"{puppetdb_url}/facts",
    json=query,
    cert=cert,
    verify=verify
)

controllers = {}
for item in response.json():
    certname = item['certname']
    megaraid = item['value']
    
    if megaraid.get('controllers'):
        for ctrl_id, ctrl_data in megaraid['controllers'].items():
            model = ctrl_data.get('product_name')
            if model not in controllers:
                controllers[model] = []
            controllers[model].append({
                'host': certname,
                'controller': ctrl_id,
                'serial': ctrl_data.get('serial_number'),
                'firmware': ctrl_data.get('fw_version')
            })

# Print summary
for model, instances in controllers.items():
    print(f"\n{model}: {len(instances)} instances")
    for instance in instances[:5]:  # Show first 5
        print(f"  - {instance['host']} (ctrl {instance['controller']}): "
              f"SN {instance['serial']}, FW {instance['firmware']}")
```

## Tips and Best Practices

1. **Use `inventory` endpoint** - More efficient than `facts` for large queries
2. **Filter early** - Use `where` clauses to reduce data transfer
3. **Index on certname** - PuppetDB automatically indexes this for fast lookups
4. **Cache results** - For dashboard queries, cache results for a few minutes
5. **Use `unique()`** - When you just need distinct values
6. **Extract specific fields** - Don't pull entire fact structure if you only need specific fields

## Troubleshooting

### No Results Returned

1. Verify the module is installed and applied to nodes
2. Check that Puppet has run recently on the nodes
3. Verify facts are syncing to PuppetDB: `puppet facts upload`
4. Check PuppetDB logs for sync issues

### Incomplete Data

- Ensure storcli/perccli binary is installed on nodes
- Check that the megaraid_sas kernel module is loaded
- Verify nodes have appropriate permissions to run storcli commands

### Performance Issues

- Limit results with `limit` clause
- Use `extract` to get only needed fields
- Consider using PuppetDB's query timeout settings
- For large infrastructures, run queries during off-peak hours

## Additional Resources

- [PuppetDB Query Tutorial](https://puppet.com/docs/puppetdb/latest/api/query/tutorial-pql.html)
- [PQL Language Reference](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html)
- [PuppetDB API Documentation](https://puppet.com/docs/puppetdb/latest/api/query/v4/query.html)

## Quick Reference Card

```
# List all hosts with controllers
puppet query 'inventory[certname] { facts.megaraid.present? = true }'

# Count by model
puppet query 'facts { name = "megaraid" } | extract value.controllers.*.product_name | unique()'

# Get firmware versions
puppet query 'inventory[certname] { facts.megaraid.number_of_controllers > 0 } | extract certname, facts.megaraid.controllers.*.fw_version'

# Find specific model
puppet query 'inventory[certname] { facts.megaraid.controllers.*.product_name ~ "3108" }'

# Multi-controller systems
puppet query 'inventory[certname] { facts.megaraid.number_of_controllers > 1 }'
```
