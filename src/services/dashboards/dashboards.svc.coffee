angular
  .module('impac.services.dashboards', [])
  .service 'ImpacDashboardsSvc', ($q, $http, $log, $timeout, ImpacMainSvc, ImpacRoutes, ImpacTheming, ImpacDeveloper) ->
    #====================================
    # Initialization and getters
    #====================================

    _self = @
    @config = {}

    @config.dashboards = []
    @getDashboards = ->
      return _self.config.dashboards

    @config.currentDashboard = {}
    @getCurrentDashboard = ->
      return _self.config.currentDashboard

    @config.widgetsTemplates = []
    @getWidgetsTemplates = ->
      return _self.config.widgetsTemplates

    #====================================
    # Callbacks
    #====================================

    @callbacks = {}

    @callbacks.dashboardChanged = $q.defer()
    @dashboardChanged = ->
      return _self.callbacks.dashboardChanged.promise

    @callbacks.widgetAdded = $q.defer()
    @widgetAdded = ->
      return _self.callbacks.widgetAdded.promise

    @callbacks.pdfModeEnabled = $q.defer()
    @pdfModeEnabled = ->
      return _self.callbacks.pdfModeEnabled.promise
    @callbacks.pdfModeCanceled = $q.defer()
    @pdfModeCanceled = ->
      return _self.callbacks.pdfModeCanceled.promise

    @togglePdfMode = (enabled) ->
      if enabled
        _self.callbacks.pdfModeEnabled.notify()
      else
        _self.callbacks.pdfModeCanceled.notify()

    @callbacks.ticked = $q.defer()
    @ticked = ->
      return _self.callbacks.ticked.promise
    @tick = ->
      _self.callbacks.ticked.notify()

    @callbacks.dhbLoader = $q.defer()
    @dhbLoader = ->
      return _self.callbacks.dhbLoader.promise
    @triggerDhbLoader = (bool=false)->
      _self.callbacks.dhbLoader.notify(bool)

    #====================================
    # Context helpers (return booleans: can be called but can't be bound!)
    #====================================

    needConfigurationLoad = ->
      return  _.isEmpty(_self.config.dashboards) || _.isEmpty(_self.config.currentDashboard)

    @isThereADashboard = ->
      !_.isEmpty _self.config.currentDashboard

    @areThereSeveralDashboards = ->
      _self.config.dashboards.length > 1

    @isCurrentDashboardEmpty = ->
      _self.isThereADashboard() && _.isEmpty(_self.config.currentDashboard.widgets)

    @areKpisEnabled = ->
      ImpacTheming.get().dhbKpisConfig.enableKpis && ImpacMainSvc.userIsKpiEnabled()


    #====================================
    # Loaders and setters
    #====================================

    # Method used for reloading an already loaded dashboard, will reload it properly
    # while also triggering the dhbLoader spinner.
    @reload = (force=false) ->
      deferred = $q.defer()
      _self.triggerDhbLoader(true)
      _self.load(force).then(
        -> deferred.resolve()
        -> deferred.reject()
      ).finally(->
        _self.triggerDhbLoader(false)
      )
      return deferred.promise

    @loadLocked=false
    @load = (force=false) ->
      deferred = $q.defer()

      # Singleton prevents concurrent calls of _self.load
      if !_self.loadLocked
        _self.loadLocked=true

        if (needConfigurationLoad() || force)

          ImpacMainSvc.load(force).then(
            (success)->
              orgId = success.currentOrganization.id

              $http.get(ImpacRoutes.dashboards.index(orgId)).then(
                (dashboards)->
                  _self.setDashboards(dashboards.data).then(->
                    _self.setCurrentDashboard()
                    deferred.resolve(_self.config)
                    $log.info("Impac! - DashboardsSvc: loaded (force=#{force})")

                  ).finally( -> _self.loadLocked=false )
                (error)->
                  $log.error("Impac! - DashboardsSvc: cannot retrieve dashboards list for org: #{orgId}")
                  _self.loadLocked=false
                  deferred.reject(error)
              )
            (error)->
              $log.error("Impac! - DashboardsSvc: cannot retrieve current organization")
              _self.loadLocked=false
              deferred.reject(error)
          )
        else
          _self.loadLocked=false
          deferred.resolve(_self.config)
      else
        $log.warn("Impac! - DashboardsSvc: Load locked. Trying again in 1s")
        $timeout(->
          _self.load(force).then(
            (success) -> deferred.resolve(success)
            (errors) -> deferred.reject(errors)
          )
        , 1000)

      return deferred.promise


    setDefaultCurrentDashboard = ->
      if _self.config.dashboards? && _self.config.dashboards.length > 0
        $log.info("Impac! - DashboardsSvc: first dashboard set as current by default")
        ImpacMainSvc.override _self.config.currentDashboard, _self.config.dashboards[0]
        _self.setWidgetsTemplates(_self.config.currentDashboard.widgets_templates)
        _self.initializeActiveTabs()
        _self.callbacks.dashboardChanged.notify(_self.config.currentDashboard)
        return true
      else
        $log.warn("Impac! - DashboardsSvc: cannot set default current dashboard")
        ImpacMainSvc.override _self.config.currentDashboard, {}
        _self.callbacks.dashboardChanged.notify(false)
        return false

    @setCurrentDashboard = (id=null) ->
      if id?
        fetchedDhb = _.find _self.config.dashboards, ((dhb) -> id == dhb.id)

        if !_.isEmpty(fetchedDhb)
          ImpacMainSvc.override _self.config.currentDashboard, fetchedDhb
          _self.setWidgetsTemplates(fetchedDhb.widgets_templates)
          _self.initializeActiveTabs()
          _self.callbacks.dashboardChanged.notify(_self.config.currentDashboard)
          return true
        else
          $log.error("Impac! - DashboardsSvc: Dashboard #{id} not found in dashboards list")
          return setDefaultCurrentDashboard()

      else
        return setDefaultCurrentDashboard()


    # TODO: refactor backend controller: dashboards(orgId) should return only the dashboards linked to the organization
    # and not all the dashboards belonging to the user...
    belongsToCurrentOrganization = (dashboard, org) ->
      return _.includes(_.pluck(dashboard.data_sources, 'id'), org.id)


    @setDashboards = (dashboardsArray=[]) ->
      ImpacMainSvc.loadOrganizations().then(
        (config) ->
          curOrg = config.currentOrganization
          # Clear array
          _.remove _self.config.dashboards, (-> true)
          for dhb in dashboardsArray
            if belongsToCurrentOrganization(dhb, curOrg)
              _self.config.dashboards.push dhb
        (error) ->
          $log.error("Impac! - DashboardsSvc: Cannot load user's organizations")
      )


    @setWidgetsTemplates = (templatesArray) ->
      # Will be filled only once
      return false if _.isEmpty(templatesArray) || !_.isEmpty(_self.config.widgetsTemplates)

      templatesArray = ImpacDeveloper.stubWidgetsTemplates(templatesArray) if ImpacDeveloper.isEnabled()

      for template in templatesArray
        _self.config.widgetsTemplates.push template

      return true

    @initializeActiveTabs = ->
      for dhb in _self.config.dashboards
        _.merge dhb, {active: _self.config.currentDashboard.id == dhb.id}


    #====================================
    # CRUD methods
    #====================================

    @create = (dashboard) ->
      _self.load().then ->
        deferred = $q.defer()

        org = ImpacMainSvc.config.currentOrganization

        unless dashboard.currency?
          dashboard.currency = org.currency || 'USD'

        data = { dashboard: dashboard }

        $http.post(ImpacRoutes.dashboards.create(org.id), data).then (success) ->
          _self.config.dashboards.push(success.data)
          _self.setCurrentDashboard(success.data.id)
          deferred.resolve(success.data)
        ,(error) ->
          $log.error("Impac! - DashboardsSvc: Cannot create dashboard with parameters: #{angular.toJson(dashboard)}", error)
          deferred.reject(error)

        return deferred.promise


    @delete = (id) ->
      deferred = $q.defer()

      $http.delete(ImpacRoutes.dashboards.delete(id)).then (success) ->
        _.remove _self.config.dashboards, (dhb) ->
          id == dhb.id
        _self.setCurrentDashboard()
        deferred.resolve(success)
      ,(error) ->
        $log.error("Impac! - DashboardsSvc: Cannot delete dashboard: #{id}")
        deferred.reject(error)

      return deferred.promise


    @update = (id, opts) ->
      deferred = $q.defer()
      data = { dashboard: opts }

      $http.put(ImpacRoutes.dashboards.update(id), data).then (success) ->
        angular.merge( _.find(_self.config.dashboards, (dhb) ->
          id == dhb.id
        ), success.data)

        if id == _self.config.currentDashboard.id
          angular.merge _self.config.currentDashboard, success.data

        deferred.resolve(success.data)
      ,(error) ->
        $log.error("Impac! - DashboardsSvc: Cannot update dashboard: #{id} with parameters: #{opts}")
        deferred.reject(error)

      return deferred.promise


    return _self
