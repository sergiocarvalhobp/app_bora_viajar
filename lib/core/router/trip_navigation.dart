import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
