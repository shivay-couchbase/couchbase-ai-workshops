# otel.nu
# Nushell OTLP/HTTP JSON helpers: logs, spans, metrics (batch + stdin)
# Usage examples are at the bottom of this file.

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

export def now_ns [] {
  date now | date to-timezone GMT | into int
}

export def gen_hex [n: int]: string -> string {
  let base = (random uuid | str replace -a '-' '')
  let twice = $"($base)($base)"
  $twice | str substring ..($n - 1)
}

# Convert a Nu value into an OTLP AnyValue {stringValue|intValue|doubleValue|boolValue}
export def to_otlp_any_value [v: any] {
  match ($v | describe) {
    "string" => { stringValue: ($v | into string) }
    "int" => { intValue: ($v | into int) }
    "float" => { doubleValue: ($v | into float) }
    "bool" => { boolValue: ($v | into bool) }
    _ => { stringValue: ($v | to json) }
  }
}

# Parse "k=v,k2=v2" into OTLP KeyValue list. Guesses types (int/float/bool/string).
export def parse_kv_attrs [attrs: string]: list<any> -> list<any> {
  if ($attrs | is-empty) { return [] }
  $attrs | split row ","
  | each {|pair|
      let kv = ($pair | split row "=")
      let k = ($kv.0 | str trim)
      let raw = ($kv.1 | default "" | str trim)
      let val = (do -i {
        if ($raw | str downcase) in ["true" "false"] { $raw | into bool }
        else if ($raw | str contains ".") { $raw | into float }
        else { $raw | into int }
      } | default $raw)
      { key: $k, value: (to_otlp_any_value $val) }
    }
}

# Merge additional attributes into an existing list
export def merge_attrs [base: list<any>, extra: list<any>] {
  if ($base | is-empty) { return $extra }
  if ($extra | is-empty) { return $base }
  $base | append $extra
}

# Build a standard OTLP resource with service/env + user attrs
export def make_resource [
  --service: string = "nushell-demo",
  --environment: string = "dev",
  --attrs: string = "",          # "k=v,k2=v2"
] {
  let base = [
    { key: "service.name", value: { stringValue: $service } }
    { key: "deployment.environment", value: { stringValue: $environment } }
  ]
  let extra = (parse_kv_attrs $attrs)
  { attributes: (merge_attrs $base $extra) }
}

# ─────────────────────────────────────────────────────────────────────────────
# LOGS
# ─────────────────────────────────────────────────────────────────────────────

# Send a single log (convenience)
export def send_log [
  message: string,
  --service: string = "nushell-demo",
  --environment: string = "dev",
  --endpoint: string = "http://localhost:4318",
  --path: string = "/v1/logs",
  --severity-text: string = "INFO",
  --severity-number: int = 9,
  --attrs: string = ""               # extra resource attrs (k=v,...)
] {
  let t = (now_ns)
  let payload = {
    resourceLogs: [
      {
        resource: (make_resource --service $service --environment $environment --attrs $attrs)
        scopeLogs: [
          {
            scope: { name: "nu.script", version: "0.2.0" }
            logRecords: [
              {
                timeUnixNano: $"($t)"
                severityText: $severity_text
                severityNumber: $severity_number
                body: { stringValue: $message }
                attributes: [
                  { key: "client.language", value: { stringValue: "nushell" } }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  let jsonpayload = $payload | to json -r
  http post -H [Content-Type application/json] $"($endpoint)($path)" $jsonpayload
}

# Batch logs from stdin.
# Modes:
#  - Plain text: each line -> one log with given severity
#  - JSONL: each line is an object with fields:
#      message (string), severityText?, severityNumber?, timeUnixNano?, attributes? (object),
#      resourceAttributes? (object merged into resource)
export def send_logs_from_stdin [
  --service: string = "nushell-demo",
  --environment: string = "dev",
  --endpoint: string = "http://localhost:4318",
  --path: string = "/v1/logs",
  --severity-text: string = "INFO",
  --severity-number: int = 9,
  --resource-attrs: string = "",  # "k=v,k2=v2"
  --jsonl                       # interpret stdin as JSONL instead of text lines
] {
  let base_resource = (make_resource --service $service --environment $environment --attrs $resource_attrs)
  let input = $in | lines | where {|l| not ($l | is-empty)}
  let records = if $jsonl {
    $input | each {|l|
        let o = $l | from json  # parse the line
        let t = ($o.timeUnixNano? | default (now_ns) | into string)
        let sevText = ($o.severityText? | default $severity_text)
        let sevNum  = ($o.severityNumber? | default $severity_number | into int)
        let body    = ($o.message? | default ($o.body? | default "" | into string))
        let attrs_obj = ($o.attributes? | default {})
        let attrs = ($attrs_obj | transpose key value | each {|x| { key: $x.key, value: (to_otlp_any_value $x.value) } })
        let res_extra_obj = ($o.resourceAttributes? | default {})
        let res_extra = ($res_extra_obj | transpose key value | each {|x| { key: $x.key, value: (to_otlp_any_value $x.value) } })
        {
          timeUnixNano: $"($t)"
          severityText: $sevText
          severityNumber: $sevNum
          body: { stringValue: ($body | into string) }
          attributes: (if ($attrs | is-empty) { [] } else { $attrs })
          __res_extra: $res_extra
        }
      }
  } else {
    $input | each {|line|
        {
          timeUnixNano: $"(now_ns)"
          severityText: $severity_text
          severityNumber: $severity_number
          body: { stringValue: $line }
          attributes: [
            { key: "input.format", value: { stringValue: "text" } }
          ]
          __res_extra: []
        }
      }
  }

  # Merge any per-record resource attrs into the base resource:
  let merged_resource = {
    attributes: (
      $base_resource.attributes
      | append (
          $records
          | reduce -f [] {|it, acc| $acc | append ($it.__res_extra | default []) }
        )
    )
  }

  let payload = {
    resourceLogs: [
      {
        resource: $merged_resource
        scopeLogs: [
          { scope: { name: "nu.script", version: "0.2.0" }, logRecords: (
              $records | each {|r| $r | reject __res_extra }
            )
          }
        ]
      }
    ]
  }

  let jsonpayload = $payload | to json -r 
  http post -H [Content-Type application/json] $"($endpoint)($path)" $jsonpayload
}

# ─────────────────────────────────────────────────────────────────────────────
# TRACES
# ─────────────────────────────────────────────────────────────────────────────

# Send a single minimal span
export def send_span [
  name: string,
  --service: string = "nushell-demo",
  --endpoint: string = "http://localhost:4318",
  --path: string = "/v1/traces",
  --duration-ms: int = 25,
  --kind: string = "Internal",
  --resource-attrs: string = "",
  --span-attrs: string = ""  # "k=v,..."
] {
  let start_ns = (now_ns)
  let end_ns   = $start_ns + ($duration_ms * 1000000)
  let trace_id = (gen_hex 32)
  let span_id  = (gen_hex 16)
  let payload = {
    resourceSpans: [
      {
        resource: (make_resource --service $service --attrs $resource_attrs)
        scopeSpans: [
          {
            scope: { name: "nu.script", version: "0.2.0" }
            spans: [
              {
                traceId: $trace_id
                spanId: $span_id
                name: $name
                kind: $kind
                startTimeUnixNano: $"($start_ns)"
                endTimeUnixNano: $"($end_ns)"
                attributes: (parse_kv_attrs $span_attrs)
              }
            ]
          }
        ]
      }
    ]
  }
  let jsonpayload = $payload | to json -r

print ( $jsonpayload )
  http post -H [Content-Type application/json] $"($endpoint)($path)" $jsonpayload 
}

# Batch spans from JSONL stdin.
# Each line object can include:
#  name (string, required)
#  durationMs? (int), startTimeUnixNano?, endTimeUnixNano?, kind?, traceId?, spanId?,
#  attributes? (object), resourceAttributes? (object)
export def send_spans_from_stdin [
  --service: string = "nushell-demo",
  --endpoint: string = "http://localhost:4318",
  --path: string = "/v1/traces",
  --resource-attrs: string = ""
] {
  let base_resource = (make_resource --service $service --attrs $resource_attrs)
  let spans = (
    $in
    | lines
    | where {|l| not ($l | is-empty)}
    | each {|l|
        let o = $l | from json
        let start = ($o.startTimeUnixNano? | default (now_ns) | into string)
        let end   = (if ($o.endTimeUnixNano? | is-empty) {
                       ( ($start | into int) + ( ($o.durationMs | default 25 | into int) * 1000000 ) ) | into string
                     } else { ($o.endTimeUnixNano | into string) })
        let tid   = ($o.traceId? | default (gen_hex 32))
        let sid   = ($o.spanId? | default (gen_hex 16))
        let attrs = ($o.attributes? | default {} | transpose key value | each {|x| { key: $x.key, value: (to_otlp_any_value $x.value) }})
        {
          traceId: $tid
          spanId: $sid
          name: ($o.name | into string)
          kind: ($o.kind? | default "SPAN_KIND_INTERNAL")
          startTimeUnixNano: $"($start)"
          endTimeUnixNano: $"($end)"
          attributes: $attrs
          __res_extra: ($o.resourceAttributes? | default {} | transpose key value | each {|x| { key: $x.key, value: (to_otlp_any_value $x.value) }})
        }
      }
  )

  let merged_resource = {
    attributes: (
      $base_resource.attributes
      | append (
          $spans
          | reduce -f [] {|it, acc| $acc | append ($it.__res_extra | default []) }
        )
    )
  }

  let payload = {
    resourceSpans: [
      {
        resource: $merged_resource
        scopeSpans: [
          { scope: { name: "nu.script", version: "0.2.0" }, spans: (
              $spans | each {|s| $s | reject __res_extra }
            )
          }
        ]
      }
    ]
  }

  let jsonpayload = $payload | to json -r
  http post -H [Content-Type application/json] $"($endpoint)($path)" $jsonpayload
}

# ─────────────────────────────────────────────────────────────────────────────
# METRICS (Gauge & Sum via JSONL)
# ─────────────────────────────────────────────────────────────────────────────
# JSONL schema per line:
#  {
#    "name": "queue_depth",
#    "value": 42.1,
#    "unit": "items",
#    "attributes": {"queue":"primary"},
#    "timeUnixNano": "1730000000000000000"
#  }
#
# For Sum, you may also pass:
#    "isMonotonic": true,
#    "aggregationTemporality": "AGGREGATION_TEMPORALITY_CUMULATIVE" | "AGGREGATION_TEMPORALITY_DELTA",
#    "startTimeUnixNano": "1729999999000000000"

def metric_datapoint_from_obj [o] {
  let t = ($o.timeUnixNano? | default (now_ns) | into string)
  let v = ($o.value? | default 0)
  let attr_list = ($o.attributes? | default {} | transpose key value | each {|x| { key: $x.key, value: (to_otlp_any_value $x.value) }})
  {
    timeUnixNano: $"($t)"
    attributes: $attr_list
  }
  | merge (if ($v | describe) == "int" { { asInt: ($v | into int) } } else { { asDouble: ($v | into float) } })
}

# Batch metrics from JSONL stdin; one metric per line.
# --type gauge|sum
export def send_metrics_from_stdin [
  --service: string = "nushell-demo",
  --environment: string = "dev",
  --endpoint: string = "http://localhost:4318",
  --path: string = "/v1/metrics",
  --resource-attrs: string = "",
  --type: string = "gauge",   # or "sum"
  --default-unit: string = "1",
  --default-agg: string = "AGGREGATION_TEMPORALITY_CUMULATIVE",
  --default-monotonic
] {
  let resource = (make_resource --service $service --environment $environment --attrs $resource_attrs)

  let metric_rows = (
    $in
    | lines
    | where {|l| not ($l | is-empty)}
    | each {|l| $l | from json }
  )

  let metrics = (
    $metric_rows
    | each {|o|
        let name = ($o.name | into string)
        let unit = ($o.unit? | default ($default_unit | into string))
        let dp   = (metric_datapoint_from_obj $o)
        if ($type == "sum") {
          let agg = ($o.aggregationTemporality? | default $default_agg)
          let mono = ($o.isMonotonic? | default $default_monotonic | into bool)
          let start = ($o.startTimeUnixNano? | default ($dp.timeUnixNano | into int) | into string)
          {
            name: $name
            unit: $unit
            sum: {
              dataPoints: [ ($dp | merge { startTimeUnixNano: $"($start)" }) ]
              aggregationTemporality: $agg
              isMonotonic: $mono
            }
          }
        } else {
          {
            name: $name
            unit: $unit
            gauge: { dataPoints: [ $dp ] }
          }
        }
      }
  )

  let payload = {
    resourceMetrics: [
      {
        resource: $resource
        scopeMetrics: [
          { scope: { name: "nu.script", version: "0.2.0" }, metrics: $metrics }
        ]
      }
    ]
  }
  let jsonpayload = $payload | to json -r
  http post -H [Content-Type application/json] $"($endpoint)($path)" $jsonpayload
}

# ─────────────────────────────────────────────────────────────────────────────
# Quick examples
# ─────────────────────────────────────────────────────────────────────────────
# Logs (single):
#   use otel.nu *
#   send_log "Hello from Nushell" --service myapp --env dev --endpoint http://localhost:4318
#
# Logs (batch from text):
#   printf "one\nTwo\nthree" | send_logs_from_stdin --service myapp --severity-text INFO
#
# Logs (batch from JSONL):
#   printf '{"message":"hi","severityNumber":9}\n{"message":"oops","severityText":"ERROR","severityNumber":17,"attributes":{"code":500}}\n' \
#     | send_logs_from_stdin --jsonl --service myapp --resource-attrs "region=eu,host=dev01"
#
# Spans (single):
#   send_span "nu quick span" --duration-ms 42 --resource-attrs "region=eu"
#
# Spans (batch JSONL):
#   printf '{"name":"work item","durationMs":30,"attributes":{"step":"load"}}\n' \
#     | send_spans_from_stdin --service myapp
#
# Metrics (gauge JSONL):
#   printf '{"name":"queue_depth","value":7,"unit":"items","attributes":{"queue":"primary"}}\n' \
#     | send_metrics_from_stdin --type gauge --service myapp
#
# Metrics (sum JSONL, cumulative monotonic):
#   printf '{"name":"requests_total","value":1,"attributes":{"route":"/api"}}\n' \
#     | send_metrics_from_stdin --type sum --service myapp --default-agg AGGREGATION_TEMPORALITY_CUMULATIVE --default-monotonic 
