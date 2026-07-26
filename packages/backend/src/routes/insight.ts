import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { type TokenInsightResult, fetchCoingeckoCoinDetail } from "@crypto-analyzer/shared";
import { prisma } from "../db.js";
import { config } from "../config.js";

const idParam = z.object({ id: z.coerce.number() });

export async function insightRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get(
    "/tokens/:id/insight",
    { schema: { params: idParam } },
    async (request, reply): Promise<TokenInsightResult> => {
      const token = await prisma.token.findUnique({ where: { id: request.params.id } });
      if (!token) {
        reply.code(404);
        return { available: false, reason: "Token not found." };
      }
      if (!token.coingeckoId) {
        return { available: false, reason: "No CoinGecko id on this token, so there's no project data to show." };
      }

      const detail = await fetchCoingeckoCoinDetail(token.coingeckoId, config.coingeckoApiKey);
      if (!detail) {
        return {
          available: false,
          reason:
            "CoinGecko did not return project details for this token (may just be rate-limited -- try again shortly).",
        };
      }

      const twitterHandle = detail.links?.twitter_screen_name;
      const telegramHandle = detail.links?.telegram_channel_identifier;

      return {
        available: true,
        description: detail.description?.en?.trim() || null,
        categories: detail.categories ?? [],
        genesisDate: detail.genesis_date,
        marketCapRank: detail.market_cap_rank,
        sentimentUpPct: detail.sentiment_votes_up_percentage,
        sentimentDownPct: detail.sentiment_votes_down_percentage,
        links: {
          homepage: (detail.links?.homepage ?? []).filter(Boolean),
          twitter: twitterHandle ? `https://twitter.com/${twitterHandle}` : null,
          telegram: telegramHandle ? `https://t.me/${telegramHandle}` : null,
          subreddit: detail.links?.subreddit_url || null,
          github: (detail.links?.repos_url?.github ?? []).filter(Boolean),
          chat: (detail.links?.chat_url ?? []).filter(Boolean),
        },
        community: {
          redditSubscribers: detail.community_data?.reddit_subscribers ?? null,
          telegramUserCount: detail.community_data?.telegram_channel_user_count ?? null,
        },
        developer: {
          stars: detail.developer_data?.stars ?? null,
          forks: detail.developer_data?.forks ?? null,
          subscribers: detail.developer_data?.subscribers ?? null,
          totalIssues: detail.developer_data?.total_issues ?? null,
          closedIssues: detail.developer_data?.closed_issues ?? null,
          pullRequestsMerged: detail.developer_data?.pull_requests_merged ?? null,
          pullRequestContributors: detail.developer_data?.pull_request_contributors ?? null,
          commitCount4Weeks: detail.developer_data?.commit_count_4_weeks ?? null,
        },
      };
    }
  );
}
