/**
 * mobile-routes.ts
 *
 * Arquivo único de integração mobile para o Bora Viajar.
 *
 * COMO USAR:
 * No seu server/_core/index.ts, importe e registre ANTES do handler tRPC:
 *
 *   import { registerMobileRoutes } from "./mobile-routes";
 *   registerMobileRoutes(app);
 *
 * Para os procedures tRPC, adicione mobileViagensProcedures e
 * mobileMensagensProcedures ao seu appRouter existente.
 *
 * Dependências já no projeto: jose, zod, drizzle-orm, express
 * Nenhuma dependência nova necessária.
 */

import type { Express, Request, Response } from "express";
import { SignJWT } from "jose";
import { z } from "zod";
import { eq, and, gt, desc, or } from "drizzle-orm";
import { TRPCError } from "@trpc/server";

// ── Ajuste esses imports para bater com os caminhos do seu projeto ─────────────
// Exemplo: se o seu schema está em "../../drizzle/schema", deixe como está.
// Se está em "../db/schema", troque abaixo.
import {
  users,
  viagens,
  mensagens,
  participantes,
  notificacoes,
} from "../../drizzle/schema";                    // ← ajuste se necessário
import { db } from "../db";                         // ← ajuste se necessário
import { router, protectedProcedure, publicProcedure } from "./trpc"; // ← ajuste
import { COOKIE_NAME, ONE_YEAR_MS } from "@shared/const"; // ← ajuste
import { ENV } from "./env";                        // ← ajuste

// ═══════════════════════════════════════════════════════════════════════════════
// SEÇÃO 1 — Rota Express: POST /api/auth/token
// ═══════════════════════════════════════════════════════════════════════════════

/** Gera o JWT de sessão — idêntico ao que o web usa no cookie app_session_id. */
async function createSessionJwt(userId: number): Promise<string> {
  const secret = new TextEncoder().encode(ENV.jwtSecret);
  return new SignJWT({ sub: String(userId) })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("1y")
    .sign(secret);
}

/** Busca perfil do usuário no Auth0 via /userinfo. */
async function fetchAuth0UserInfo(
  domain: string,
  accessToken: string
): Promise<{
  sub: string;
  name?: string;
  nickname?: string;
  email?: string;
  picture?: string;
}> {
  const res = await fetch(`https://${domain}/userinfo`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new Error(`Auth0 userinfo HTTP ${res.status}`);
  return res.json();
}

/**
 * Registra as rotas Express exclusivas para o app mobile.
 * Chamar ANTES do handler tRPC no index.ts.
 */
export function registerMobileRoutes(app: Express) {
  // ── POST /api/auth/token ───────────────────────────────────────────────────
  // Recebe o access_token do Auth0 (via flutter_appauth/PKCE),
  // valida, busca/cria o usuário e retorna o JWT de sessão do Bora Viajar.
  app.post("/api/auth/token", async (req: Request, res: Response) => {
    const accessToken = req.body?.access_token;

    if (!accessToken || typeof accessToken !== "string") {
      res.status(400).json({ error: "Campo access_token é obrigatório." });
      return;
    }

    if (!ENV.auth0Domain) {
      res.status(503).json({ error: "Auth0 não configurado no servidor." });
      return;
    }

    try {
      // 1. Valida o token com o Auth0
      let profile: Awaited<ReturnType<typeof fetchAuth0UserInfo>>;
      try {
        profile = await fetchAuth0UserInfo(ENV.auth0Domain, accessToken);
      } catch {
        res.status(401).json({ error: "Token inválido ou expirado." });
        return;
      }

      if (!profile.sub) {
        res.status(400).json({ error: "sub ausente no perfil Auth0." });
        return;
      }

      // 2. Busca ou cria o usuário no banco (mesmo upsert do callback web)
      const displayName =
        profile.name?.trim() ||
        profile.nickname?.trim() ||
        (profile.email ? profile.email.split("@")[0] : null) ||
        "Viajante";

      // Tenta encontrar pelo openId
      let [user] = await db
        .select()
        .from(users)
        .where(eq(users.openId, profile.sub))
        .limit(1);

      if (!user) {
        // Cria novo usuário
        const [inserted] = await db
          .insert(users)
          .values({
            openId:      profile.sub,
            name:        displayName,
            email:       profile.email ?? null,
            loginMethod: "auth0-mobile",
            avatarUrl:   profile.picture ?? null,
          })
          .returning();
        user = inserted;
      } else {
        // Atualiza lastSignedIn e dados do perfil se vazios
        await db
          .update(users)
          .set({
            lastSignedIn: new Date(),
            name:         user.name || displayName,
            avatarUrl:    user.avatarUrl || profile.picture || null,
          })
          .where(eq(users.id, user.id));
      }

      if (!user) {
        res.status(500).json({ error: "Erro ao criar/buscar usuário." });
        return;
      }

      // 3. Gera o JWT de sessão
      const sessionToken = await createSessionJwt(user.id);

      // 4. Retorna o token — o app salva no SecureStorage
      res.json({
        sessionToken,
        expiresIn: ONE_YEAR_MS / 1000,
        user: {
          id:    user.id,
          name:  user.name,
          email: user.email,
          foto:  user.avatarUrl ?? null,
          role:  user.role,
        },
      });
    } catch (err) {
      console.error("[MobileAuth] Erro:", err);
      res.status(500).json({ error: "Erro interno do servidor." });
    }
  });

  // ── POST /api/auth/logout-mobile ───────────────────────────────────────────
  // Logout simples — o app apaga o token localmente.
  // Futuramente: adicionar lista negra de tokens se necessário.
  app.post("/api/auth/logout-mobile", (_req: Request, res: Response) => {
    res.json({ ok: true });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEÇÃO 2 — Procedures tRPC: viagens (novos)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Adicione ao seu appRouter assim:
 *
 *   viagens: router({
 *     ...seuViagensProceduresExistentes,
 *     ...mobileViagensProcedures,
 *   }),
 */
export const mobileViagensProcedures = {

  // viagens.minhas — viagens onde o usuário é líder ou participante
  minhas: protectedProcedure.query(async ({ ctx }) => {
    const userId = ctx.user.id;

    // Viagens como líder
    const comoLider = await db
      .select()
      .from(viagens)
      .where(eq(viagens.liderId, userId))
      .orderBy(desc(viagens.dataInicio));

    // Viagens como participante
    const comoParticipante = await db
      .select({
        viagem:  viagens,
        status:  participantes.status,
      })
      .from(participantes)
      .innerJoin(viagens, eq(participantes.viagemId, viagens.id))
      .where(eq(participantes.userId, userId))
      .orderBy(desc(viagens.dataInicio));

    const liderIds = new Set(comoLider.map(v => v.id));

    return [
      ...comoLider.map(v => ({
        ...v,
        myStatus: null as string | null,
        isLider: true,
        participantesCount: 0,
      })),
      ...comoParticipante
        .filter(r => !liderIds.has(r.viagem.id))
        .map(r => ({
          ...r.viagem,
          myStatus: r.status,
          isLider: false,
          participantesCount: 0,
        })),
    ];
  }),

  // viagens.criar
  criar: protectedProcedure
    .input(z.object({
      destino:    z.string().min(2).max(255),
      descricao:  z.string().min(5),
      tipo:       z.enum(["Lider", "Viajante"]),
      dataInicio: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      dataFim:    z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      estado:     z.string().length(2).optional(),
      cidade:     z.string().max(150).optional(),
      atrativo:   z.string().max(255).optional(),
      maxVagas:   z.number().int().positive().optional(),
    }))
    .mutation(async ({ ctx, input }) => {
      const [viagem] = await db
        .insert(viagens)
        .values({
          liderId:    ctx.user.id,
          destino:    input.destino,
          descricao:  input.descricao,
          tipo:       input.tipo,
          dataInicio: input.dataInicio,
          dataFim:    input.dataFim,
          estado:     input.estado,
          cidade:     input.cidade,
          atrativo:   input.atrativo,
          maxVagas:   input.maxVagas,
        })
        .returning();
      return viagem;
    }),

  // viagens.listarParticipantes — com dados do user aninhados
  listarParticipantes: protectedProcedure
    .input(z.object({ viagemId: z.number().int().positive() }))
    .query(async ({ input }) => {
      return db
        .select({
          id:        participantes.id,
          viagemId:  participantes.viagemId,
          userId:    participantes.userId,
          status:    participantes.status,
          createdAt: participantes.createdAt,
          user: {
            id:       users.id,
            name:     users.name,
            foto:     users.avatarUrl,
            bio:      users.bio,
            estado:   users.estadoResidencia,
            cidade:   users.cidadeResidencia,
            role:     users.role,
            openId:   users.openId,
            email:    users.email,
          },
        })
        .from(participantes)
        .innerJoin(users, eq(participantes.userId, users.id))
        .where(eq(participantes.viagemId, input.viagemId))
        .orderBy(desc(participantes.createdAt));
    }),

  // viagens.participar
  participar: protectedProcedure
    .input(z.object({ viagemId: z.number().int().positive() }))
    .mutation(async ({ ctx, input }) => {
      const [existing] = await db
        .select()
        .from(participantes)
        .where(and(
          eq(participantes.viagemId, input.viagemId),
          eq(participantes.userId, ctx.user.id),
        ))
        .limit(1);

      if (existing) {
        throw new TRPCError({ code: "CONFLICT",
          message: "Você já está participando desta viagem." });
      }

      const [p] = await db
        .insert(participantes)
        .values({ viagemId: input.viagemId, userId: ctx.user.id, status: "interessado" })
        .returning();

      // Cria notificação para o líder
      const [viagem] = await db.select().from(viagens)
        .where(eq(viagens.id, input.viagemId)).limit(1);

      if (viagem && viagem.liderId !== ctx.user.id) {
        await db.insert(notificacoes).values({
          userId:   viagem.liderId,
          tipo:     "participante",
          titulo:   "Novo interessado na sua viagem!",
          mensagem: `${ctx.user.name ?? "Alguém"} quer participar de "${viagem.destino}".`,
          viagemId: input.viagemId,
        });
      }

      return p;
    }),

  // viagens.cancelarParticipacao
  cancelarParticipacao: protectedProcedure
    .input(z.object({ viagemId: z.number().int().positive() }))
    .mutation(async ({ ctx, input }) => {
      await db.delete(participantes).where(and(
        eq(participantes.viagemId, input.viagemId),
        eq(participantes.userId, ctx.user.id),
      ));
      return { ok: true };
    }),

  // viagens.atualizarParticipante — líder confirma/recusa
  atualizarParticipante: protectedProcedure
    .input(z.object({
      viagemId:       z.number().int().positive(),
      participanteId: z.number().int().positive(),
      status:         z.enum(["confirmado", "recusado", "interessado"]),
    }))
    .mutation(async ({ ctx, input }) => {
      const [viagem] = await db.select().from(viagens)
        .where(eq(viagens.id, input.viagemId)).limit(1);

      if (!viagem || viagem.liderId !== ctx.user.id) {
        throw new TRPCError({ code: "FORBIDDEN",
          message: "Apenas o líder pode confirmar participantes." });
      }

      await db.update(participantes)
        .set({ status: input.status })
        .where(eq(participantes.id, input.participanteId));

      return { ok: true };
    }),

  // viagens.listarPorUsuario — perfil público
  listarPorUsuario: publicProcedure
    .input(z.object({ userId: z.number().int().positive() }))
    .query(async ({ input }) => {
      return db.select().from(viagens)
        .where(eq(viagens.liderId, input.userId))
        .orderBy(desc(viagens.dataInicio))
        .limit(20);
    }),
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEÇÃO 3 — Procedures tRPC: mensagens (novos/atualizados)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Adicione ao seu appRouter assim:
 *
 *   mensagens: router({
 *     ...seuMensagensProceduresExistentes,
 *     ...mobileMensagensProcedures,   // sobrescreve 'listar' se já existir
 *   }),
 *
 * ATENÇÃO: se já tiver um procedure 'listar' de mensagens, substitua pelo
 * deste arquivo — a diferença é o suporte ao afterId para polling incremental.
 */
export const mobileMensagensProcedures = {

  // mensagens.listar — com suporte a afterId para polling incremental
  listar: protectedProcedure
    .input(z.object({
      viagemId: z.number().int().positive(),
      afterId:  z.number().int().optional(),
      limit:    z.number().int().max(100).default(50),
    }))
    .query(async ({ input }) => {
      const where = input.afterId
        ? and(eq(mensagens.viagemId, input.viagemId), gt(mensagens.id, input.afterId))
        : eq(mensagens.viagemId, input.viagemId);

      return db
        .select({
          id:        mensagens.id,
          viagemId:  mensagens.viagemId,
          senderId:  mensagens.senderId,
          conteudo:  mensagens.conteudo,
          timestamp: mensagens.timestamp,
          sender: {
            id:     users.id,
            name:   users.name,
            foto:   users.avatarUrl,
            openId: users.openId,
            email:  users.email,
            role:   users.role,
          },
        })
        .from(mensagens)
        .innerJoin(users, eq(mensagens.senderId, users.id))
        .where(where)
        .orderBy(mensagens.id)
        .limit(input.limit);
    }),

  // mensagens.enviar
  enviar: protectedProcedure
    .input(z.object({
      viagemId: z.number().int().positive(),
      conteudo: z.string().min(1).max(2000),
    }))
    .mutation(async ({ ctx, input }) => {
      // Verifica acesso: deve ser líder ou participante confirmado/interessado
      const [viagem] = await db.select().from(viagens)
        .where(eq(viagens.id, input.viagemId)).limit(1);

      if (!viagem) {
        throw new TRPCError({ code: "NOT_FOUND", message: "Viagem não encontrada." });
      }

      const isLider = viagem.liderId === ctx.user.id;

      if (!isLider) {
        const [part] = await db.select().from(participantes)
          .where(and(
            eq(participantes.viagemId, input.viagemId),
            eq(participantes.userId, ctx.user.id),
          ))
          .limit(1);

        if (!part) {
          throw new TRPCError({ code: "FORBIDDEN",
            message: "Participe da viagem para enviar mensagens." });
        }
      }

      const [msg] = await db.insert(mensagens)
        .values({
          viagemId: input.viagemId,
          senderId: ctx.user.id,
          conteudo: input.conteudo.trim(),
        })
        .returning();

      return {
        ...msg,
        sender: {
          id:     ctx.user.id,
          name:   ctx.user.name,
          foto:   ctx.user.avatarUrl ?? null,
          openId: ctx.user.openId,
          email:  ctx.user.email,
          role:   ctx.user.role,
        },
      };
    }),
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEÇÃO 4 — Procedures tRPC: users (novos)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Adicione ao seu appRouter assim:
 *
 *   users: router({
 *     ...seuUsersProceduresExistentes,
 *     ...mobileUsersProcedures,
 *   }),
 */
export const mobileUsersProcedures = {

  // users.buscarPorId — perfil público
  buscarPorId: publicProcedure
    .input(z.object({ userId: z.number().int().positive() }))
    .query(async ({ input }) => {
      const [user] = await db
        .select({
          id:        users.id,
          openId:    users.openId,
          name:      users.name,
          foto:      users.avatarUrl,
          bio:       users.bio,
          instagram: users.instagram,
          estado:    users.estadoResidencia,
          cidade:    users.cidadeResidencia,
          role:      users.role,
          // email omitido propositalmente em perfil público
        })
        .from(users)
        .where(eq(users.id, input.userId))
        .limit(1);

      if (!user) {
        throw new TRPCError({ code: "NOT_FOUND", message: "Usuário não encontrado." });
      }

      return user;
    }),

  // users.atualizarPerfil
  atualizarPerfil: protectedProcedure
    .input(z.object({
      name:      z.string().min(1).max(200).optional(),
      bio:       z.string().max(500).nullable().optional(),
      instagram: z.string().max(100).nullable().optional(),
      estado:    z.string().length(2).nullable().optional(),
      cidade:    z.string().max(150).nullable().optional(),
    }))
    .mutation(async ({ ctx, input }) => {
      const updates: Record<string, unknown> = {};
      if (input.name      !== undefined) updates.name             = input.name;
      if (input.bio       !== undefined) updates.bio              = input.bio;
      if (input.instagram !== undefined) updates.instagram        = input.instagram;
      if (input.estado    !== undefined) updates.estadoResidencia = input.estado;
      if (input.cidade    !== undefined) updates.cidadeResidencia = input.cidade;

      if (Object.keys(updates).length > 0) {
        await db.update(users).set(updates).where(eq(users.id, ctx.user.id));
      }

      const [updated] = await db.select().from(users)
        .where(eq(users.id, ctx.user.id)).limit(1);

      return updated;
    }),
};
