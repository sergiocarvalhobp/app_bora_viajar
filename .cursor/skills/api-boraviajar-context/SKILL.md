---
name: api-boraviajar-context
description: Considera o backend relacionado deste app em C:/PROJETOS/api_boraviajar ao investigar, implementar ou depurar fluxos que envolvam API, autenticação, perfil, viagens e contratos entre app Flutter e backend.
disable-model-invocation: true
---

# API BoraViajar Context

nesse projeto tenha acesso tbm ao projeto de api dele em c://PROJETOS/api_boraviajar.

## Instruções

Quando o pedido envolver integração app/backend, autenticação, perfil, viagens, upload, ou qualquer endpoint HTTP:

1. Considere este app Flutter (`C:/PROJETOS/app_bora_viajar`) e também a API Java em `C:/PROJETOS/api_boraviajar`.
2. Verifique alinhamento de:
   - rotas/paths (`/api/v1/...`)
   - payloads request/response
   - status codes de erro
   - campos/nomes (`camelCase` vs `snake_case`)
   - regras de segurança/autenticação
3. Ao relatar causa/solução, deixe claro se a ação é no app, na API, ou em ambos.

## Quando usar

- Usuário menciona API, backend, endpoint, autenticação, token, 401/403/404, profile, trips, upload de avatar.
- Existe bug de integração entre app Flutter e API Java.
