import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Abre notificações no [rootNavigatorKey] (por cima do menu de abas).
void openNotifications(BuildContext context) {
  GoRouter.of(context).pushNamed('notifications');
}

/// Fecha notificações e volta ao Explorar.
void closeNotifications(BuildContext context) {
  final rootNav = rootNavigatorKey.currentState;
  if (rootNav != null && rootNav.canPop()) {
    rootNav.pop();
    return;
  }
  GoRouter.of(context).go(Routes.home);
}

/// Abre detalhes da viagem no [rootNavigatorKey] (por cima do menu de abas).
void openTripDetails(BuildContext context, int tripId) {
  GoRouter.of(context).pushNamed(
    'tripDetails',
    pathParameters: {'id': '$tripId'},
  );
}

/// Abre o chat da viagem no navigator raiz.
void openTripChat(BuildContext context, int tripId) {
  GoRouter.of(context).pushNamed(
    'tripChat',
    pathParameters: {'id': '$tripId'},
  );
}
