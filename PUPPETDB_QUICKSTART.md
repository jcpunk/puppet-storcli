# Quick PuppetDB Queries for MegaRAID Controllers

## Most Common Queries

### 1. List All Controllers WITH HOSTNAMES and Firmware Versions

**This shows HOSTNAME → MODEL → FIRMWARE for easy tracking:**

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version'
```

**Expected output format:**
```json
[
  {
    "certname": "server01.example.com",
    "facts.megaraid.controllers.*.product_name": ["AVAGO 3108 MegaRAID"],
    "facts.megaraid.controllers.*.fw_version": ["4.680.00-8290"]
  },
  {
    "certname": "server02.example.com",
    "facts.megaraid.controllers.*.product_name": ["Dell PERC H730P"],
    "facts.megaraid.controllers.*.fw_version": ["25.5.5.0005"]
  }
]
```

**For cleaner table format, pipe through jq:**
```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version' \
--render-as json | jq -r '.[] | [.certname, .["facts.megaraid.controllers.*.product_name"][0], .["facts.megaraid.controllers.*.fw_version"][0]] | @tsv'
```

**Output:**
```
server01.example.com    AVAGO 3108 MegaRAID    4.680.00-8290
server02.example.com    Dell PERC H730P        25.5.5.0005
server03.example.com    LSI 9560               4.680.00-8418
```

### 2. List Different Controller Models (No Hostname)

If you just want to see the unique models without hostnames:

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

### 3. Full Inventory Report with Hostname, Model, Serial, and Firmware

Complete details for each host:

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

### 4. Find Hosts with Specific Firmware Version

Find which hosts have a specific firmware (e.g., 4.680.00-8290):

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.fw_version = "4.680.00-8290"
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version'
```

### 5. Find Hosts with Specific Controller Model

Find all hosts with AVAGO 3108 controllers (includes hostname):

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.product_name ~ "3108"
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version'
```

Find all hosts with Dell PERC controllers (includes hostname):

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.product_name ~ "PERC"
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version'
```

### 6. Find Multi-Controller Systems with Details

See which hosts have more than one controller (with full details):

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 1
} | extract certname, facts.megaraid.number_of_controllers, facts.megaraid.controllers.*.product_name'
```

## Hostname-Focused Queries

### Show Hostname → Firmware Version Mapping

**Get a clean list showing which host has which firmware:**

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.fw_version' \
--render-as json | jq -r '.[] | "\(.certname): \(.["facts.megaraid.controllers.*.fw_version"] | join(", "))"'
```

**Output:**
```
server01.example.com: 4.680.00-8290
server02.example.com: 25.5.5.0005
server03.example.com: 4.680.00-8418
server04.example.com: 4.680.00-8290, 4.680.00-8290
```

### Show Hostname → Model → Firmware

**Three-column output for easy tracking:**

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version' \
--render-as json | jq -r '.[] | "\(.certname)\t\(.["facts.megaraid.controllers.*.product_name"][0])\t\(.["facts.megaraid.controllers.*.fw_version"][0])"'
```

**Output:**
```
server01.example.com    AVAGO 3108 MegaRAID    4.680.00-8290
server02.example.com    Dell PERC H730P        25.5.5.0005
server03.example.com    LSI 9560               4.680.00-8418
```

### Group Hosts by Firmware Version

**See which hosts share the same firmware:**

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.fw_version' \
--render-as json | jq -r 'group_by(.["facts.megaraid.controllers.*.fw_version"][0]) | .[] | "\(.[0]["facts.megaraid.controllers.*.fw_version"][0]):\n  \([.[].certname] | join("\n  "))\n"'
```

**Output:**
```
4.680.00-8290:
  server01.example.com
  server04.example.com

25.5.5.0005:
  server02.example.com

4.680.00-8418:
  server03.example.com
```

### Find Hosts Needing Firmware Update

**Find hosts with firmware older than specific version:**

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.controllers.*.fw_version < "4.700.00"
} | extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version'
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

### CSV Export with Hostname

Create a CSV report with HOSTNAME as the first column:

```bash
puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract 
  certname, 
  facts.megaraid.controllers.0.product_name,
  facts.megaraid.controllers.0.serial_number,
  facts.megaraid.controllers.0.fw_version
' --render-as json | \
jq -r '["Hostname","Model","Serial","Firmware"], 
  (.[] | [.certname, .["facts.megaraid.controllers.0.product_name"], 
  .["facts.megaraid.controllers.0.serial_number"], 
  .["facts.megaraid.controllers.0.fw_version"]]) | @csv'
```

**Output:**
```csv
"Hostname","Model","Serial","Firmware"
"server01.example.com","AVAGO 3108 MegaRAID","FW-BAMQTHEAARBWA","4.680.00-8290"
"server02.example.com","Dell PERC H730P","CN0H730P12345","25.5.5.0005"
"server03.example.com","LSI 9560","SV12345678","4.680.00-8418"
```

### Summary Report by Firmware with Hostnames

Show which hosts are running each firmware version:

```bash
#!/bin/bash
echo "Firmware Version Distribution"
echo "=============================="
echo ""

puppet query 'inventory[certname] { 
  facts.megaraid.number_of_controllers > 0 
} | extract certname, facts.megaraid.controllers.*.fw_version' --render-as json | \
jq -r 'group_by(.["facts.megaraid.controllers.*.fw_version"][0]) | .[] | 
  "\(.[] | .["facts.megaraid.controllers.*.fw_version"][0]) (\(length) hosts):\n  \([.[].certname] | join("\n  "))\n"'
```

**Output:**
```
4.680.00-8290 (2 hosts):
  server01.example.com
  server04.example.com

25.5.5.0005 (1 hosts):
  server02.example.com
```

### Summary Report by Model with Hostnames

Generate a summary showing hostnames for each controller model:

```bash
#!/bin/bash
echo "MegaRAID Controller Inventory by Model"
echo "======================================="
echo ""

puppet query 'facts { name = "megaraid" } | 
  extract value.controllers.*.product_name | unique()' --render-as json | \
jq -r '.[] | .["value.controllers.*.product_name"][]' | \
while read model; do
  echo "$model:"
  puppet query "inventory[certname] { 
    facts.megaraid.controllers.*.product_name = \"$model\"
  } | extract certname, facts.megaraid.controllers.*.fw_version" --render-as json | \
  jq -r '.[] | "  \(.certname) - FW: \(.["facts.megaraid.controllers.*.fw_version"][0])"'
  echo ""
done
```

**Output:**
```
AVAGO 3108 MegaRAID:
  server01.example.com - FW: 4.680.00-8290
  server04.example.com - FW: 4.680.00-8290

Dell PERC H730P:
  server02.example.com - FW: 25.5.5.0005

LSI 9560:
  server03.example.com - FW: 4.680.00-8418
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
# HOSTNAME with firmware versions (MOST USEFUL)
inventory[certname] { facts.megaraid.number_of_controllers > 0 } | 
  extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version

# HOSTNAME with model and firmware (clean table output)
inventory[certname] { facts.megaraid.number_of_controllers > 0 } | 
  extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version | 
  --render-as json | jq -r '.[] | [.certname, .["facts.megaraid.controllers.*.product_name"][0], .["facts.megaraid.controllers.*.fw_version"][0]] | @tsv'

# All hosts with controllers
inventory[certname] { facts.megaraid.present? = true }

# Unique models (no hostname)
facts { name = "megaraid" } | extract value.controllers.*.product_name | unique()

# Specific model (with hostname)
inventory[certname] { facts.megaraid.controllers.*.product_name ~ "3108" } | 
  extract certname, facts.megaraid.controllers.*.product_name, facts.megaraid.controllers.*.fw_version

# By firmware version (with hostname)
inventory[certname] { facts.megaraid.controllers.*.fw_version = "4.680.00-8290" } | 
  extract certname, facts.megaraid.controllers.*.product_name

# Multi-controller systems (with hostname)
inventory[certname] { facts.megaraid.number_of_controllers > 1 } | 
  extract certname, facts.megaraid.number_of_controllers, facts.megaraid.controllers.*.product_name
```
