#
# Component generated by Impac! Widget Generator!
#
module = angular.module('impac.components.widgets.<%= data.componentNames.mod %>', [])
module.controller('Widget<%= data.componentNames.ctrl %>Ctrl', (<%= data.deps %>) ->

  w = $scope.widget

  # Define settings
  # --------------------------------------
  <%_ data.settingsPromises.forEach(function (name) { _%>
  $scope.<%= name + 'Deferred' %> = $q.defer();
  <%_ }) _%>

  settingsPromises = [
    <%_ data.settingsPromises.forEach(function (name) { _%>
    $scope.<%= name + 'Deferred' %>.promise,
    <%_ }) _%>
  ]

  # Widget specific methods
  # --------------------------------------
  w.initContext = ->
    $scope.isDataFound = w.content?

  <%_ if (data.hasChart) { %>
  # Chart formating function
  # --------------------------------------
  $scope.drawTrigger = $q.defer()
  # Format the widget content data for ChartJS.
  w.format = ->
    if $scope.isDataFound
      # Data displayed in the chart.
      inputData = <%= data.defaultInputData -%>
      <% if (data.chartName === 'bar') { %>
      # maximum capacity for chartjs bar-chart
      inputData.labels.length = 15 if inputData.labels.length > 15
      inputData.values.length = 15 if inputData.values.length > 15
      <% } %>
      # Options for configuring the ChartFormatterSvc formatting & the chartJs lib itself.
      options = {}
      # Standard formatting required dependant on chart type.
      chartData = ChartFormatterSvc.<%= data.chartName %>Chart(inputData, options)
      # Notifies the impac-chart directive's drawTrigger promise of data format complete,
      # which then draws the chart.
      $scope.drawTrigger.notify(chartData)
  <% } %>

  # Widget is ready: can trigger the "wait for settings to be ready"
  # --------------------------------------
  $scope.widgetDeferred.resolve(settingsPromises)
)
module.directive('widget<%= data.componentNames.drct %>', ->
  return {
    restrict: 'A',
    controller: 'Widget<%= data.componentNames.ctrl %>Ctrl'
  }
)
