/*
  Copyright 2020 The K8s-m8g Authors. All Rights Reserved.
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/* K8s python flask dashboard */
local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local prometheus = grafana.prometheus;
local loki = grafana.loki;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local logPanel = grafana.logPanel;
local row = grafana.row;

{
  grafanaDashboards+:: {
    'python-flask':
      local datasourceTemplate =
        template.datasource(
          name='datasource',
          label='Datasource',
          query='prometheus',
          current=null,
        );

      local datasourceLogsTemplate =
        template.datasource(
          name='datasource_logs',
          label='Logs datasource',
          query='loki',
          current=null,
        );

      local jobTemplate =
        template.new(
          name='job',
          label='Job',
          datasource='$datasource',
          query='label_values(flask_exporter_info, job)',
          current=null,
          sort=$._config.dashboardCommon.templateSort,
          refresh=$._config.dashboardCommon.templateRefresh,
        );

      local viewByTemplate =
        template.custom(
          name='view',
          label='View by',
          query='pod,container',
          current='container',
        );

      local namespaceTemplate =
        template.new(
          name='namespace',
          label='Namespace',
          datasource='$datasource',
          query='label_values(flask_exporter_info{job="$job"}, namespace)',
          refresh=$._config.dashboardCommon.templateRefresh,
          sort=$._config.dashboardCommon.templateSort,
          includeAll=true,
          multi=true,
        );

      local podTemplate =
        template.new(
          name='pod',
          label='Pod',
          datasource='$datasource',
          query='label_values(flask_exporter_info{job="$job", namespace=~"$namespace"}, pod)',
          refresh=$._config.dashboardCommon.templateRefresh,
          sort=$._config.dashboardCommon.templateSort,
          includeAll=true,
          multi=true,
        );

      local containerTemplate =
        template.new(
          name='container',
          label='Container',
          datasource='$datasource',
          query='label_values(flask_exporter_info{job="$job", namespace=~"$namespace"}, container)',
          refresh=$._config.dashboardCommon.templateRefresh,
          sort=$._config.dashboardCommon.templateSort,
          includeAll=true,
          multi=true,
        );

      local searchTemplate =
        template.text(
          name='search',
          label='Logs Search',
        );

     local cpu =
        graphPanel.new(
          title='CPU Usage',
          datasource='$datasource',
          format='core',
          min=0,
          stack=true,
          linewidth=2,
          fill=2,
        )
        .addTargets(
           [
            prometheus.target(expr='sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{namespace=~"$namespace", pod=~"$pod", container!="POD", container=~"$container"}) by ($view)',legendFormat='{{$view}}'),
            prometheus.target(expr='sum(\nkube_pod_container_resource_requests_cpu_cores{namespace=~"$namespace", pod=~"$pod", container=~"$container"}) by ($view)\n',legendFormat='PodRequests - {{$view}}'),
            prometheus.target(expr='sum(\nkube_pod_container_resource_limits_cpu_cores{namespace=~"$namespace", pod=~"$pod", container=~"$container"}) by ($view)\n',legendFormat='PodLimits - {{$view}}'),
           ],
          ),
        .addSeriesOverride({ alias: '/PodRequests/', color: $._config.dashboardCommon.color.red, dashes: true, fill: 0, legend: true, linewidth: 2, stack: false })
        .addSeriesOverride({ alias: '/PodLimits/', color: $._config.dashboardCommon.color.orange, dashes: true, fill: 0, legend: true, linewidth: 2, stack: false });

     local memory =
        graphPanel.new(
          title='Memory Usage',
          datasource='$datasource',
          format='bytes',
          min=0,
          stack=true,
          linewidth=2,
          fill=2,
        )
        .addTargets(
           [
            prometheus.target(expr='sum(container_memory_working_set_bytes{namespace=~"$namespace", pod=~"$pod", id!="", container!="POD", container=~"$container"}) by ($view)',legendFormat='{{$view}}'),
            prometheus.target(expr='sum(\nkube_pod_container_resource_requests_memory_bytes{namespace=~"$namespace", pod=~"$pod", container=~"$container"}) by ($view)\n',legendFormat='PodRequests - {{$view}}'),
            prometheus.target(expr='sum(\nkube_pod_container_resource_limits_memory_bytes{namespace=~"$namespace", pod=~"$pod", container=~"$container"}) by ($view)\n',legendFormat='PodLimits - {{$view}}'),
           ],
          ),
        .addSeriesOverride({ alias: '/PodRequests/', dashes: true, fill: 0, legend: true, linewidth: 2, stack: false })
        .addSeriesOverride({ alias: '/PodLimits/', dashes: true, fill: 0, legend: true, linewidth: 2, stack: false });


     local bandwidth =
        graphPanel.new(
          title='Transmit/Receive Bandwidth',
          datasource='$datasource',
          format='Bps',
          stack=true,
          linewidth=2,
          fill=2,
        )
        .addTargets(
           [
            prometheus.target(expr='sum(irate(container_network_transmit_bytes_total{namespace=~"$namespace", pod=~"$pod"}[5m])) by (pod)',legendFormat='Tx_{{pod}}'),
            prometheus.target(expr='sum(irate(container_network_receive_bytes_total{namespace=~"$namespace", pod=~"$pod"}[5m])) by (pod)',legendFormat='Rx_{{pod}}'),
           ],
          ),
        .addSeriesOverride({ alias: '/Rx_/', stack: 'B', transform: 'negative-Y' })
        .addSeriesOverride({ alias: '/Tx_/', stack: 'A' });

     local drops =
        graphPanel.new(
          title='Transmit/Receive Drops',
          datasource='$datasource',
          format='Bps',
          stack=true,
          linewidth=2,
          fill=2,
        )
        .addTargets(
           [
            prometheus.target(expr='sum(irate(container_network_transmit_packets_dropped_total{namespace=~"$namespace", pod=~"$pod"}[5m])) by (pod)',legendFormat='Tx_{{pod}}'),
            prometheus.target(expr='sum(irate(container_network_receive_packets_dropped_total{namespace=~"$namespace", pod=~"$pod"}[5m])) by (pod)',legendFormat='Rx_{{pod}}'),
           ],
          ),
        .addSeriesOverride({ alias: '/Rx_/', stack: 'B', transform: 'negative-Y' })
        .addSeriesOverride({ alias: '/Tx_/', stack: 'A' });


     local count =
        graphPanel.new(
          title='Count (avg for 10s intervals)',
          datasource='$datasource_logs',
          format='logs',
          min=0,
          stack=true,
          legend_alignAsTable=true,
          legend_current=true,
          legend_rightSide=true,
        )
        .addSeriesOverride({ alias: 'Value #A', legend: false, hiddenSeries: true})
        .addTarget(
            prometheus.target(expr='sum(count_over_time( ({namespace=~"$namespace", pod=~"$pod", container=~"$container"} |~ "(?i)$search" )[10s] )) by ($view)'),
        );

      local logs =
        logPanel.new(
          title='Logs',
          datasource='$datasource_logs',
          showLabels=true,
        )
        .addTarget(loki.target('{namespace=~"$namespace", pod=~"$pod", container=~"$container"} |~ "(?i)$search"'));

     local requestPerMinute =
        graphPanel.new(
          title='Total requests per minute',
          datasource='$datasource',
          stack=true,
          linewidth=2,
          fill=2,
          legend_alignAsTable=true,
          legend_current=true,
          legend_rightSide=true,
          legend_max=true,
          legend_values=true,
        )
        .addTarget(
            prometheus.target(expr='sum(increase(\n  flask_http_request_total{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container"}[1m]\n) / 2) by (status, $view)',
            legendFormat='HTTP {{status}} - {{$view}}',
            ),
        );

     local errorsPerMinute =
        graphPanel.new(
          title='Errors per minute',
          datasource='$datasource',
          linewidth=2,
          fill=2,
          legend_alignAsTable=true,
          legend_current=true,
          legend_rightSide=true,
          legend_max=true,
          legend_values=true,
        )
        .addTarget(
            prometheus.target(expr='sum(\n  rate(\n    flask_http_request_duration_seconds_count{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status!="200"}[1m]\n)\n) by (status, $view)',
            legendFormat='HTTP {{status}} - {{$view}}',
            ),
          ),
        .addSeriesOverride({ alias: 'errors', color: $._config.dashboardCommon.color.orange});

     local averageResponseTime =
        graphPanel.new(
          title='Average response time [1m]',
          datasource='$datasource',
          linewidth=2,
          fill=2,
          format='s',
          legend_avg=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
          legend_max=true,
          legend_min=true,
          legend_values=true,
          legend_sort='avg',
          legend_sortDesc= true,
        )
        .addTarget(
            prometheus.target(expr='avg(rate(\n  flask_http_request_duration_seconds_sum{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status="200"}[1m]\n)\n /\nrate(\n  flask_http_request_duration_seconds_count{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status="200"}[1m]\n) >= 0)  by (status, $view)',
            legendFormat='HTTP 200 - {{$view}}',
            ),
        );

     local requestUnder =
        graphPanel.new(
          title='Requests under 250ms',
          datasource='$datasource',
          linewidth=2,
          fill=2,
          format='none',
          legend_avg=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
          legend_max=true,
          legend_min=true,
          legend_values=true,
          legend_sort='avg',
          legend_sortDesc= true,
        )
        .addTarget(
            prometheus.target(expr='sum(increase(\n  flask_http_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status="200",le="0.25"}[1m]\n)\n / ignoring (le)\nincrease(\n  flask_http_request_duration_seconds_count{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status="200"}[1m]\n) >= 0) by (status, $view)',
            legendFormat='HTTP 200 - {{$view}}',
            ),
        );

     local requestDurationP50 =
        graphPanel.new(
          title='Request duration [s] - p50',
          datasource='$datasource',
          description='The 50th percentile of request durations over the last 60 seconds. In other words, half of the requests finish in (min/max/avg) these times.',
          linewidth=2,
          fill=2,
          legend_avg=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
          legend_max=true,
          legend_min=true,
          legend_values=true,
          legend_sort='avg',
          legend_sortDesc= true,
        )
        .addTarget(
            prometheus.target(expr='avg(histogram_quantile(\n  0.5,\n  rate(\n    flask_http_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status="200"}[1m]\n  )\n)>=0) by (status, $view)',
            legendFormat='HTTP 200 - {{$view}}',
            ),
        );

     local requestDurationP90 =
        graphPanel.new(
          title='Request duration [s] - p90',
          datasource='$datasource',
          description='The 90th percentile of request durations over the last 60 seconds. In other words, 90 percent of the requests finish in (min/max/avg) these times.',
          linewidth=2,
          fill=2,
          legend_avg=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
          legend_max=true,
          legend_min=true,
          legend_values=true,
          legend_sort='avg',
          legend_sortDesc= true,
        )
        .addTarget(
            prometheus.target(expr='avg(histogram_quantile(\n  0.9,\n  rate(\n    flask_http_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace", pod=~"$pod", container=~"$container", status="200"}[1m]\n  )\n)>=0) by (status, $view)',
            legendFormat='HTTP 200 - {{$view}}',
            ),
        );

      local templates = [
                          datasourceTemplate,
                        ]
                        + (if $._config.isLoki then [datasourceLogsTemplate] else [])
                        + [
                          jobTemplate,
                          viewByTemplate,
                          namespaceTemplate,
                          podTemplate,
                          containerTemplate,
                        ]
                        + if $._config.isLoki then [searchTemplate] else [];

      local logsPanels = [
        row.new('Logs', collapse=true) { gridPos: { x: 0, y: 4, w: 24, h: 1 } },
        count { tooltip+: { sort: 2 }, gridPos: { x: 0, y: 5, w: 24, h: 5 } },
        logs { gridPos: { x: 0, y: 10, w: 24, h: 13 } },
      ];

      local panels = [
        row.new('CPU Usage', collapse=true) { gridPos: { x: 0, y: 0, w: 24, h: 1 } },
        cpu { tooltip+: { sort: 2 }, gridPos: { x: 0, y: 1, w: 24, h: 7 } },
        row.new('Memory Usage', collapse=true) { gridPos: { x: 0, y: 1, w: 24, h: 1 } }
        .addPanel(memory { tooltip+: { sort: 2 } }, { x: 0, y: 2, w: 24, h: 7 }),
        row.new('Network Bandwidth', collapse=true) { gridPos: { x: 0, y: 2, w: 24, h: 1 } }
        .addPanel(bandwidth { tooltip+: { sort: 2 } }, { x: 0, y: 3, w: 24, h: 7 }),
        row.new('Network Drops', collapse=true) { gridPos: { x: 0, y: 3, w: 24, h: 1 } }
        .addPanel(drops { tooltip+: { sort: 2 } }, { x: 0, y: 4, w: 24, h: 7 }),
        row.new('Server') { gridPos: { x: 0, y: 5, w: 24, h: 1 } },
        .addPanel(requestPerMinute { tooltip+: { sort: 2 } }, { x: 0, y: 6, w: 12, h: 7 }),
        .addPanel(errorsPerMinute { tooltip+: { sort: 2 } }, { x: 12, y: 6, w: 12, h: 7 }),
        .addPanel(averageResponseTime { tooltip+: { sort: 2 } }, { x: 0, y: 13, w: 12, h: 7 }),
        .addPanel(requestUnder { tooltip+: { sort: 2 } }, { x: 12, y: 13, w: 12, h: 7 }),
        .addPanel(requestDurationP50 { tooltip+: { sort: 2 } }, { x: 0, y: 20, w: 12, h: 7 }),
        .addPanel(requestDurationP90 { tooltip+: { sort: 2 } }, { x: 12, y: 20, w: 12, h: 7 }),
      ] + if $._config.isLoki then logsPanels else [];

      dashboard.new(
        'Python Flask',
        editable=$._config.dashboardCommon.editable,
        graphTooltip=$._config.dashboardCommon.tooltip,
        refresh=$._config.dashboardCommon.refresh,
        time_from=$._config.dashboardCommon.time_from,
        uid=$._config.dashboardIDs.pythonFlask,
      )
      .addTemplates(templates),
      .addPanels(panels),
  },
}