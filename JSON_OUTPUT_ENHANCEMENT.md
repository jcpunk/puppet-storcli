# JSON Output Mode Enhancement

## Issue

The problem statement asked: "Shouldn't commands be suffixed with `J` as well to ensure json output which is easier to parse?"

## Solution

Updated all custom providers to use JSON output mode (`J` flag) for `show` commands, consistent with the existing facter implementation.

## Changes Made

### 1. Modified Execute Command Method

Added a `use_json` parameter to the `execute_command` method in all providers:

```ruby
def execute_command(cmd, use_json: false)
  flags = use_json ? 'J nolog' : 'nolog'
  full_cmd = "#{storcli} #{controller_path} #{cmd} #{flags}"
  # ... execute command
end
```

### 2. Added JSON Parsing Helper

Implemented a `parse_json_response` method to handle JSON parsing consistently:

```ruby
def parse_json_response(json_str)
  data = JSON.parse(json_str)
  controllers = data.fetch('Controllers', [])
  return nil if controllers.empty?
  
  controller = controllers[0]
  return nil if controller.dig('Command Status', 'Status') == 'Failure'
  
  controller.dig('Response Data')
rescue JSON::ParserError, StandardError => e
  Puppet.warning("Failed to parse JSON response: #{e.message}")
  nil
end
```

### 3. Updated All Getter Methods

Replaced regex parsing with JSON parsing in all `get_*` methods:

**Before (regex parsing):**
```ruby
def get_boolean_setting(cmd, pattern)
  output = execute_command("show #{cmd}")
  if output.match(/#{Regexp.escape(pattern)}.*\bON\b/i)
    'on'
  elsif output.match(/#{Regexp.escape(pattern)}.*\bOFF\b/i)
    'off'
  end
end
```

**After (JSON parsing):**
```ruby
def get_boolean_setting(cmd, json_key)
  output = execute_command("show #{cmd}", use_json: true)
  data = parse_json_response(output)
  return :absent unless data
  
  properties = data['Controller Properties'] || []
  prop = properties.find { |p| p['Ctrl_Prop'] == json_key }
  return :absent unless prop
  
  value = prop['Value']
  if value =~ /\bON\b/i
    'on'
  elsif value =~ /\bOFF\b/i
    'off'
  end
end
```

## Affected Providers

1. **megaraid_controller_setting** - Controller-level settings
2. **megaraid_patrolread** - Patrol read configuration
3. **megaraid_consistency_check** - Consistency check configuration
4. **megaraid_vd_setting** - Virtual drive settings (infrastructure only)

## Benefits

1. **More Reliable Parsing** - JSON structure is more predictable than text output
2. **Consistent with Facter** - Uses the same approach as `lib/facter/megaraid.rb`
3. **Easier to Maintain** - JSON parsing is clearer than complex regex patterns
4. **Future-proof** - JSON structure is more stable across storcli/perccli versions

## Command Examples

**Show commands with JSON:**
- `storcli64 /c0 show autorebuild J nolog`
- `storcli64 /c0 show prrate J nolog`
- `storcli64 /c0 show ccrate J nolog`

**Set commands without JSON:**
- `storcli64 /c0 set autorebuild=on nolog`
- `storcli64 /c0 set prrate=30 nolog`
- `storcli64 /c0 set ccrate=30 nolog`

## Backward Compatibility

All return values and interfaces remain the same. This is an internal implementation change that makes parsing more robust without affecting the public API.
