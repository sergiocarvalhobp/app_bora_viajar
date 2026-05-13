# Bora Viajar — App Flutter

App mobile do Bora Viajar. Conecte-se com pessoas que planejam a mesma viagem pelo Brasil.

## Stack
- **Flutter 3.x** + Dart 3.3+
- **Riverpod 2** (estado)
- **GoRouter 14** (navegação)
- **Dio 5** (HTTP)
- **flutter_appauth** (Auth0/Google OAuth)
- **flutter_secure_storage** (JWT)
- **Firebase Messaging** (push notifications)

## Pré-requisitos
- Flutter SDK >= 3.3.0
- Dart SDK >= 3.3.0
- Android Studio ou Xcode
- Conta Auth0 configurada
- Backend Bora Viajar rodando

## Setup

### 1. Instalar dependências
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Fontes (obrigatório)
Baixar e colocar em `assets/fonts/`:
- **DM Serif Display**: https://fonts.google.com/specimen/DM+Serif+Display
  - DMSerifDisplay-Regular.ttf
  - DMSerifDisplay-Italic.ttf
- **Nunito**: https://fonts.google.com/specimen/Nunito
  - Nunito-Regular.ttf (400)
  - Nunito-Medium.ttf (500)
  - Nunito-SemiBold.ttf (600)
  - Nunito-Bold.ttf (700)
  - Nunito-ExtraBold.ttf (800)

### 3. Android — Deep links Auth0
Copiar o conteúdo de `android/app/src/main/AndroidManifest_mobile_snippet.xml`
para dentro da `<activity>` no `AndroidManifest.xml`.

### 4. iOS — URL Schemes
Copiar o conteúdo de `ios/Runner/InfoPlist_mobile_snippet.xml`
para dentro do `<dict>` raiz no `Info.plist`.

### 5. Auth0 Dashboard
Em Applications → seu app → **Allowed Callback URLs**, adicionar:
```
br.com.boraviajar://callback
```

### 6. Backend — Integrar mobile-routes.ts
Ver instruções em `server/mobile-routes.ts`.

### 7. Rodar
```bash
# Emulador Android (localhost do host = 10.0.2.2)
flutter run \
  --dart-define=BACKEND_URL=http://10.0.2.2:3000 \
  --dart-define=AUTH0_DOMAIN=seu-tenant.us.auth0.com

# Simulador iOS
flutter run \
  --dart-define=BACKEND_URL=http://localhost:3000 \
  --dart-define=AUTH0_DOMAIN=seu-tenant.us.auth0.com

# Produção
flutter run \
  --dart-define=BACKEND_URL=https://boraviajar.com.br \
  --dart-define=AUTH0_DOMAIN=seu-tenant.us.auth0.com
```

## Estrutura
```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MaterialApp + GoRouter + ThemeData
├── core/
│   ├── app_constants.dart       # Constantes (COOKIE_NAME, Auth0, etc)
│   ├── app_env.dart             # Variáveis de ambiente (--dart-define)
│   ├── network/
│   │   ├── api_client.dart      # Dio configurado
│   │   └── auth_interceptor.dart # Injeta JWT em cada request
│   ├── storage/
│   │   └── secure_storage.dart  # JWT no Keychain/Keystore
│   ├── errors/
│   │   ├── app_exception.dart   # Exceções tipadas
│   │   └── error_handler.dart   # Converte DioException → AppException
│   ├── router/
│   │   └── app_router.dart      # Todas as rotas + redirect de auth
│   └── theme/
│       ├── app_colors.dart      # Paleta Terra Brasileira
│       └── app_theme.dart       # ThemeData light + dark
└── features/
    ├── auth/                    # Login, sessão, usuário atual
    ├── trips/                   # Busca, detalhes, criar, histórico
    ├── chat/                    # Chat em tempo real (polling → WebSocket)
    ├── notifications/           # Notificações in-app
    └── profile/                 # Editar perfil, perfil público
```

## Telas
| Rota | Tela |
|------|------|
| `/login` | LoginScreen |
| `/` | SearchTripsScreen |
| `/trips/:id` | TripDetailsScreen |
| `/trips/:id/chat` | ChatTripScreen |
| `/trips/create` | CreateTripScreen |
| `/my-history` | MyHistoryScreen |
| `/notifications` | NotificationsScreen |
| `/profile/edit` | EditProfileScreen |
| `/profile/:userId` | PublicProfileScreen |

## Firebase (push notifications)
1. Criar projeto em https://console.firebase.google.com
2. Adicionar app Android (br.com.boraviajar) e iOS
3. Baixar `google-services.json` → `android/app/`
4. Baixar `GoogleService-Info.plist` → `ios/Runner/`
5. Adicionar `FCM_SERVER_KEY` no `.env` do backend
