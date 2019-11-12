local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local grafana = ((import 'grafana/grafana.libsonnet') + {
                   _config+:: {
                     namespace: 'monitoring-grafana',
                   },
                   grafana+: {
                     dashboardSources:
                       local configMap = k.core.v1.configMap;
                       local dashboardSources = import 'grafana/configs/dashboard-sources/dashboards.libsonnet';
                       local sources = dashboardSources
                                       { providers: dashboardSources.providers +
                                                    [{
                                                      name: 'baked',
                                                      orgId: 1,
                                                      folder: '',
                                                      type: 'file',
                                                      options: {
                                                        path: '/grafana-dashboard-definitions/baked',
                                                      },
                                                    }] };
                       configMap.new('grafana-dashboards',
                                     { 'dashboards.yaml': std.manifestJsonEx(sources, '    ') }) +
                       configMap.mixin.metadata.withNamespace($._config.namespace),
                     deployment+: {
                       spec+: {
                         template+: {
                           spec+: {
                             containers: [
                               c { imagePullPolicy+: 'Always' }
                               for c in super.containers
                             ],
                           },
                         },
                       },
                     },
                   },
                 }).grafana;

k.core.v1.list.new(
  grafana.dashboardDefinitions +
  [
    grafana.dashboardSources,
    grafana.dashboardDatasources,
    grafana.deployment,
    grafana.serviceAccount,
    grafana.service +
    service.mixin.spec.withPorts(servicePort.newNamed('http', 3000, 'http') + servicePort.withNodePort(30910)) +
    service.mixin.spec.withType('NodePort'),
  ]
)
