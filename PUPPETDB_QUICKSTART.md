# Quick PuppetDB Queries for MegaRAID Controllers

## Most Common Queries

### 1. List All Different Controller Models in Your Infrastructure

This is likely what you need most - to see all the different card types:

```bash
puppet query 'facts { name = "megaraid" } | extract value.controllers.*.product_name | unique()'
```

**Expected output:**
```
AVAGO 3108 MegaRAID
LSI 9560
Dell PERC H730P
LSI 3008-IR
```

### 2. Count Hosts by Controller Model

See how many hosts have each controller type:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.product_name' | \
jq -r '.[] | .["facts.megaraid.controllers.*.product_name"][]' | \
sort | uniq -c
```

### 3. Get Complete Inventory

List every host with its controller details:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract 
  certname, 
  facts.megaraid.number_of_controllers,
  facts.megaraid.controllers.*.product_name,
  facts.megaraid.controllers.*.serial_number,
  facts.megaraid.controllers.*.fw_version'
```

### 4. Find Hosts with Specific Controller

Find all hosts with AVAGO 3108 controllers:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.product_name ~ "3108"
}'
```

Find all hosts with Dell PERC controllers:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.product_name ~ "PERC"
}'
```

### 5. Find Multi-Controller Systems

See which hosts have more than one controller:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 1
}'
```

## Web UI Queries

If using the PuppetDB web interface or Puppet Enterprise Console:

### Query Builder

1. Go to PuppetDB Query page
2. Select "Inventory" or "Facts"
3. Add filter: `facts.megaraid.present? = true`
4. Extract fields you want to see

### Console Query

In PE Console's Inventory page, use the fact filter:
```
megaraid.present? = true
```

Then view the structured fact data in the node details.

## Generate Reports

### CSV Export

Create a CSV report of all controllers:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract 
  certname, 
  facts.megaraid.controllers.0.product_name,
  facts.megaraid.controllers.0.serial_number,
  facts.megaraid.controllers.0.fw_version
' --render-as json | \
jq -r '["Host","Model","Serial","Firmware"], 
  (.[] | [.certname, .["facts.megaraid.controllers.0.product_name"], 
  .["facts.megaraid.controllers.0.serial_number"], 
  .["facts.megaraid.controllers.0.fw_version"]]) | @csv'
```

### Summary Report

Generate a summary by model:

```bash
#!/bin/bash
echo "MegaRAID Controller Inventory Summary"
echo "====================================="
echo ""

puppet query 'facts { name = "megaraid" } | 
  extract value.controllers.*.product_name | unique()' --render-as json | \
jq -r '.[] | .["value.controllers.*.product_name"][]' | \
while read model; do
  count=$(puppet query "inventory[certname] { 
    facts.megaraid.controllers.*.product_name = \"$model\"
  }" --render-as json | jq 'length')
  echo "$model: $count hosts"
done
```

## REST API Curl

If you prefer curl:

```bash
# Set your PuppetDB server
PUPPETDB="https://puppetdb.example.com:8081"
CERT="/etc/puppetlabs/puppet/ssl/certs/$(hostname -f).pem"
KEY="/etc/puppetlabs/puppet/ssl/private_keys/$(hostname -f).pem"
CA="/etc/puppetlabs/puppet/ssl/certs/ca.pem"

# Query for all controller models
curl -X GET "${PUPPETDB}/pdb/query/v4/facts/megaraid" \
  --cert $CERT --key $KEY --cacert $CA \
  --data-urlencode 'query=["extract", "value",
    ["and",
      ["=", "name", "megaraid"],
      [">", ["fact", "megaraid.number_of_controllers"], 0]
    ]
  ]' | jq -r '.[].value.controllers[].product_name' | sort -u
```

## Troubleshooting

**No results?**
1. Verify puppet-storcli module is installed
2. Check nodes have had recent Puppet runs
3. Ensure storcli/perccli binary is installed on nodes

**Need more details?**

See the complete guide: [PUPPETDB_QUERIES.md](PUPPETDB_QUERIES.md)

## Quick PQL Reference

```
# All hosts with controllers
inventory[certname] { facts.megaraid.present? = true }

# Unique models
facts { name = "megaraid" } | extract value.controllers.*.product_name | unique()

# Specific model
inventory[certname] { facts.megaraid.controllers.*.product_name ~ "3108" }

# By firmware
inventory[certname] { facts.megaraid.controllers.*.fw_version = "4.680.00-8290" }

# Multi-controller
inventory[certname] { facts.megaraid.number_of_controllers > 1 }

# With extraction
inventory[certname] { facts.megaraid.present? = true } | 
  extract certname, facts.megaraid.controllers.*.product_name
```
