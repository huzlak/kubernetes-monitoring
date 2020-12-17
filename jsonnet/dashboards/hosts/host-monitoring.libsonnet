/*
  Copyright 2020 The dNation Kubernetes Monitoring Authors. All Rights Reserved.
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

/* Host main dashboard */

local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local prometheus = grafana.prometheus;
local statPanel = grafana.statPanel;
local template = grafana.template;
local row = grafana.row;
local link = grafana.link;
local text = grafana.text;

{
  grafanaDashboards+::
    local hostDashboard(hostUid, dashboardName, hostTemplates, hostApps=[]) = {
      local k8sMonitoringLink =
        link.dashboards(
          title='Kubernetes Monitoring',
          tags=[],
          url='/d/%s' % $._config.grafanaDashboards.ids.k8sMonitoring,
          type='link',
        ),
      local dNationLink =
        link.dashboards(
          title='dNation - Making Cloud Easy',
          tags=[],
          icon='cloud',
          url='https://www.dNation.cloud/',
          type='link',
          targetBlank=true,
        ),
      local alertPanel(title, expr) =
        statPanel.new(
          title=title,
          datasource='$alertmanager',
          graphMode='none',
          colorMode='background',
        )
        .addTarget({ type: 'single', expr: expr }),
      local criticalPanel =
        alertPanel(
          title='Critical',
          expr='ALERTS{alertname!="Watchdog", severity="critical", alertgroup=~"%s|%s"}' % [$._config.prometheusRules.alertGroupHost, $._config.prometheusRules.alertGroupHostApp],
        )
        .addDataLink({ title: 'Detail', url: '/d/%s?var-alertmanager=$alertmanager&var-severity=critical&var-job=$job&var-alertgroup=%s&var-alertgroup=%s&%s' % [$._config.grafanaDashboards.ids.alertOverview, $._config.prometheusRules.alertGroupHost, $._config.prometheusRules.alertGroupHostApp, $._config.grafanaDashboards.dataLinkCommonArgs] })
        .addThresholds($.grafanaThresholds($._config.templates.commonThresholds.criticalPanel)),
      local warningPanel =
        alertPanel(
          title='Warning',
          expr='ALERTS{alertname!="Watchdog", severity="warning", alertgroup=~"%s|%s"}' % [$._config.prometheusRules.alertGroupHost, $._config.prometheusRules.alertGroupHostApp],
        )
        .addDataLink({ title: 'Detail', url: '/d/%s?var-alertmanager=$alertmanager&var-severity=warning&var-job=$job&var-alertgroup=%s&var-alertgroup=%s&%s' % [$._config.grafanaDashboards.ids.alertOverview, $._config.prometheusRules.alertGroupHost, $._config.prometheusRules.alertGroupHostApp, $._config.grafanaDashboards.dataLinkCommonArgs] })
        .addThresholds($.grafanaThresholds($._config.templates.commonThresholds.warningPanel)),
      local hostStatsPanels = [
        statPanel.new(
          title=tpl.panel.title,
          description='%s\n\nHost monitoring template: _%s_' % [tpl.panel.description, tpl.templateName],
          datasource=tpl.panel.datasource,
          colorMode=tpl.panel.colorMode,
          graphMode=tpl.panel.graphMode,
          unit=tpl.panel.unit,
        )
        .addTarget(prometheus.target(tpl.panel.expr))
        .addMappings(tpl.panel.mappings)
        .addDataLinks(tpl.panel.dataLinks)
        .addThresholds($.grafanaThresholds(tpl.panel.thresholds))
        {
          gridPos: {
            x: tpl.panel.gridPos.x,
            y: tpl.panel.gridPos.y,
            w: tpl.panel.gridPos.w,
            h: tpl.panel.gridPos.h,
          },
        }
        for tpl in hostTemplates
      ],
      local hostAppStatsPanels(index, app) = [
        local appGridX =
          if std.type(tpl.panel.gridPos.x) == 'number' then
            tpl.panel.gridPos.x
          else
            index * 4;  // `4` -> default stat panel width
        local appGridY =
          if std.type(tpl.panel.gridPos.y) == 'number' then
            tpl.panel.gridPos.y
          else
            12;  // `12` -> init Y position in application row;
        statPanel.new(
          title='Health %s' % app.name,
          description='%s\n\nApplication monitoring template: _%s_' % [app.description, tpl.templateName],
          datasource=tpl.panel.datasource,
          colorMode=tpl.panel.colorMode,
          graphMode=tpl.panel.graphMode,
          unit=tpl.panel.unit,
        )
        .addTarget(prometheus.target(tpl.panel.expr % { job: 'job=~"%s"' % app.jobName }))
        .addMappings(tpl.panel.mappings)
        .addDataLinks(
          if std.length(tpl.panel.dataLinks) > 0 then
            tpl.panel.dataLinks
          else if std.objectHas($._config.grafanaDashboards.ids, tpl.templateName) then
            [{ title: 'Detail', url: '/d/%s?var-job=%s&%s' % [$._config.grafanaDashboards.ids[tpl.templateName], app.jobName, $._config.grafanaDashboards.dataLinkCommonArgs] }]
          else
            []
        )
        .addThresholds($.grafanaThresholds(tpl.panel.thresholds))
        {
          gridPos: {
            x: appGridX,
            y: appGridY,
            w: tpl.panel.gridPos.w,
            h: tpl.panel.gridPos.h,
          },
        }
        for tpl in app.templates
      ],
      local applicationPanels(apps) =
        if std.length(apps) > 0 then
          [
            row.new('Applications') { gridPos: { x: 0, y: 11, w: 24, h: 1 } },
          ] +
          std.flattenArrays([
            hostAppStatsPanels(app.index, app.item)
            for app in $.zipWithIndex(apps)
          ])
        else
          [],
      local datasourceTemplate =
        template.datasource(
          query='prometheus',
          name='datasource',
          current=null,
          label='Datasource',
        ),
      local jobTemplate =
        template.new(
          name='job',
          query='label_values(node_uname_info, job)',
          label='Job',
          datasource='$datasource',
          sort=$._config.grafanaDashboards.templateSort,
          refresh=$._config.grafanaDashboards.templateRefresh,
        ),
      local alertManagerTemplate =
        template.datasource(
          query='camptocamp-prometheus-alertmanager-datasource',
          name='alertmanager',
          current=null,
          label='AlertManager',
          hide='variable',
        ),
      local clusterTemplate =
        template.new(
          name='cluster',
          label='Cluster',
          datasource='$datasource',
          query='label_values(kube_node_info, cluster)',
          sort=$._config.grafanaDashboards.templateSort,
          refresh=$._config.grafanaDashboards.templateRefresh,
          hide='variable',
        ),
      dashboard: dashboard.new(
        dashboardName,
        editable=$._config.grafanaDashboards.editable,
        graphTooltip=$._config.grafanaDashboards.tooltip,
        refresh=$._config.grafanaDashboards.refresh,
        time_from=$._config.grafanaDashboards.time_from,
        tags=$._config.grafanaDashboards.tags.k8sHostsMain,
        uid=hostUid,
      )
                 .addLinks(
        [
          k8sMonitoringLink,
          dNationLink,
        ]
      )
                 .addTemplates([datasourceTemplate, jobTemplate, alertManagerTemplate, clusterTemplate])
                 .addPanels(
        [
          row.new('Alerts') { gridPos: { x: 0, y: 0, w: 24, h: 1 } },
          criticalPanel { gridPos: { x: 0, y: 1, w: 12, h: 3 } },
          warningPanel { gridPos: { x: 12, y: 1, w: 12, h: 3 } },
          row.new('Host') { gridPos: { x: 0, y: 4, w: 24, h: 1 } },
          text.new('CPU') { gridPos: { x: 0, y: 5, w: 6, h: 1 } },
          text.new('RAM') { gridPos: { x: 6, y: 5, w: 6, h: 1 } },
          text.new('Disk') { gridPos: { x: 12, y: 5, w: 6, h: 1 } },
          text.new('Network') { gridPos: { x: 18, y: 5, w: 6, h: 1 } },
        ] + hostStatsPanels + applicationPanels(hostApps)
      ),
    };
    if $._config.hostMonitoring.enabled && std.length($._config.hostMonitoring.hosts) > 0 then
      {
        local getUid(obj) = '%s%s' % [$._config.grafanaDashboards.ids.hostMonitoring, std.asciiLower(obj.name)],
        local getName(obj) = 'Host Monitoring %s' % obj.name,

        ['host-monitoring-%s' % host.name]: hostDashboard(getUid(host), getName(host), $.getTemplates($._config.templates.host, host), $.getApps($._config.templates.hostApps, host)).dashboard
        for host in $._config.hostMonitoring.hosts
        if (std.objectHas(host, 'apps') || std.objectHas(host, 'templates'))
      } +
      if $.isAnyDefault($._config.hostMonitoring.hosts) then
        {
          'host-monitoring': hostDashboard($._config.grafanaDashboards.ids.hostMonitoring, 'Host Monitoring', $.getTemplates($._config.templates.host)).dashboard,
        }
      else
        {}
    else
      {},
}
