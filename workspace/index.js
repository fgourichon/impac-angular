var module = angular.module('impacWorkspace', ['maestrano.impac']);

// Configuration impac-angular lib on module impacWorkSpace run.
module.run(function ($log, $window, $q, $http, ImpacLinking, ImpacRoutes) {

  // TODO: set-up server to enable local $http calls to setting.json
  var settings = {
    mno_url: 'http://localhost:3000',
    impac_url: 'http://localhost:4000',
    api_key: '7149f0c91d7e995c10be79ed4881c035d662632995e852f550313345e0f0b982',
    api_secret: '4a776ea4-8134-4f38-b632-85cbe951524e'
  };

  // encodes a base64 string
  var credentials = $window.btoa(settings.api_key + ':' + settings.api_secret);
  // attaches basic auth onto $http default, which configures all impacWorkspace & maestrano.impac
  // angular modules $http requests.
  $http.defaults.headers.common.Authorization = 'Basic ' + credentials;

  ImpacLinking.linkData({
    organizations: function () {
      return getOrganizations();
    },
    user: function () {
      return $q.when({ name: 'Developer' });
    }
  });

  ImpacRoutes.configureRoutes({
    // mno paths
    dhbBasePath: settings.mno_url + '/api/v2/impac/dashboards',
    widgetBasePath: settings.mno_url + '/api/v2/impac/widgets',
    kpiBasePath: settings.mno_url + '/api/v2/impac/kpis',
    // impac paths
    showWidgetPath: settings.impac_url + '/api/v1/get_widget',
    impacKpisBasePath: settings.impac_url + '/api/v2/kpis'
  });

  function getOrganizations() {
    return $http.get(settings.mno_url + '/api/v2/impac/organizations')
      .then(function (response) {
        var organizations = (response.data || []);
        return { organizations: organizations, currentOrgId: (organizations[0].id || null) };
      },
      fail
    );
  }

  function fail(err) {
    $log.error('workspace/index.js ERROR: ', err);
  }

});
