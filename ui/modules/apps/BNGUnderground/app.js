/* Passive driving HUD. Interactive screens belong to the native Vue router. */
(function () {
  'use strict';
  angular.module('beamng.apps').directive('bngUnderground', function () {
    return {
      restrict: 'EA', replace: true, scope: true,
      templateUrl: '/ui/modules/apps/BNGUnderground/app.html',
      link: function (scope) {
        scope.vm = { active: false };
        scope.money = function (value) { return '$' + Math.floor(value || 0).toLocaleString('en-US'); };
        scope.open = function () { bngApi.engineLua('bngUnderground.open()'); };
        scope.inbox = function () { bngApi.engineLua("bngUnderground.showBoard('inbox')"); };
        scope.$on('BNGUState', function (_event, value) {
          scope.$evalAsync(function () { scope.vm = value; });
        });
        bngApi.engineLua("extensions.load('bngUnderground');bngUnderground.requestState()");
      }
    };
  });
}());
