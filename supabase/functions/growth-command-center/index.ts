import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface GrowthCommandCenterRequest {
  totalRegisteredUsers?: number;
  todayRegistrations?: number;
  activeUsersToday?: number;
  liveViewers?: number;
  todayLandingViews?: number;
  monthLandingViews?: number;
  todayShares?: number;
  gapToBeatNotion?: number;
  gapToBeatEvernote?: number;
  progressToBeatNotion?: number;
  progressToBeatEvernote?: number;
  successfulReferrals?: number;
  totalReferrals?: number;
}

interface DepartmentBrief {
  id: string;
  label: string;
  owner: string;
  priority: string;
  objective: string;
  actions: string[];
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as GrowthCommandCenterRequest;
    const totalRegisteredUsers = toNumber(body.totalRegisteredUsers);
    const todayRegistrations = toNumber(body.todayRegistrations);
    const todayShares = toNumber(body.todayShares);

    const stageLabel = totalRegisteredUsers < 100
      ? "Pre-PMF"
      : totalRegisteredUsers < 1000
      ? "Early traction"
      : "Scale-up";
    const stageReason = totalRegisteredUsers < 100
      ? "The product still needs repeatable acquisition and faster activation."
      : totalRegisteredUsers < 1000
      ? "The product is showing traction and needs repeatable growth loops."
      : "The product needs stronger process, channel scaling, and hiring discipline.";

    const focusTags = [
      "public-memo-seo",
      "notion-evernote-import",
      "referral-loop",
      ...(todayRegistrations === 0 ? ["registration-bottleneck"] : []),
      ...(todayShares === 0 ? ["share-bottleneck"] : []),
    ];

    const departments: DepartmentBrief[] = [
      {
        id: "development",
        label: "Development",
        owner: "Engineering",
        priority: "P0",
        objective:
          "Keep lint at zero and continue moving growth-critical logic into Supabase Edge Functions.",
        actions: [
          "Instrument route-level acquisition signals across landing, import, referral, and public memo flows.",
          "Keep competitor migration flows backend-first from preview through commit.",
          "Keep growth-facing screens analyzable with zero lint issues.",
        ],
      },
      {
        id: "product",
        label: "Product",
        owner: "Product",
        priority: "P0",
        objective:
          "Tighten activation from landing page to first imported note or first public memo.",
        actions: [
          "Add a clearer sign-up CTA after import preview.",
          "Connect public memo reading to account creation prompts.",
          "Reduce first-value time from visit to first saved note.",
        ],
      },
      {
        id: "advertising",
        label: "Advertising",
        owner: "Growth",
        priority: "P1",
        objective:
          "Spend only after conversion instrumentation is stable enough to protect CAC.",
        actions: [
          "Prepare small-budget search and social tests for replacement keywords.",
          "Gate paid spend on working sign-up and import funnels.",
          "Refresh ad creative once public memo share data starts accumulating.",
        ],
      },
      {
        id: "pr",
        label: "PR",
        owner: "Founder",
        priority: "P1",
        objective:
          "Tell a credible underdog story tied to product progress and user wins.",
        actions: [
          "Publish weekly product-shipping summaries.",
          "Turn public memos into founder updates that can be shared externally.",
          "Prepare a Product Hunt / indie launch narrative with proof points.",
        ],
      },
      {
        id: "sales",
        label: "Sales",
        owner: "Founder",
        priority: "P1",
        objective:
          "Win early design partners instead of waiting for broad self-serve demand.",
        actions: [
          "Reach out to small teams using Notion or Evernote with import-based demos.",
          "Offer migration help for the first pilot accounts.",
          "Track objections and feed them back into the product roadmap.",
        ],
      },
      {
        id: "marketing",
        label: "Marketing",
        owner: "Growth",
        priority: "P0",
        objective:
          "Use public memos, comparison content, and import messaging to create recurring organic traffic.",
        actions: [
          "Ship comparison pages and public memo content for replacement keywords.",
          "Use public memo shares as reusable social content.",
          "Publish how-to content around switching from Notion and Evernote.",
        ],
      },
      {
        id: "hr",
        label: "HR",
        owner: "Operations",
        priority: "P2",
        objective:
          "Delay full-time hiring until repeatable acquisition exists, but define fractional roles now.",
        actions: [
          "Define contractor scopes for growth design, content, and backend operations.",
          "Set hiring triggers tied to registrations, active users, and revenue.",
          "Prepare onboarding docs so the first hires can ship quickly.",
        ],
      },
      {
        id: "finance",
        label: "Finance",
        owner: "Finance",
        priority: "P1",
        objective:
          "Protect runway while funding only the channels and tools that improve acquisition or retention.",
        actions: [
          "Set a weekly growth spending cap.",
          "Track CAC assumptions against actual sign-up and retention data.",
          "Review infrastructure and tool costs before adding new paid vendors.",
        ],
      },
      {
        id: "procurement",
        label: "Procurement",
        owner: "Operations",
        priority: "P2",
        objective:
          "Buy only the tools required to measure or accelerate the next growth bottleneck.",
        actions: [
          "Prefer Supabase and the current stack before adding new SaaS tools.",
          "Document required vendors for analytics, ads, and design support.",
          "Delay non-essential purchases until activation improves.",
        ],
      },
      {
        id: "business-planning",
        label: "Business Planning",
        owner: "Founder",
        priority: "P0",
        objective:
          "Turn the gap to Notion and Evernote into staged milestones instead of a vague aspiration.",
        actions: [
          "Track the path to 100 users, 1,000 users, and 10,000 users first.",
          "Update the roadmap with cross-functional owners and dates every week.",
          "Tie growth goals to revenue, hiring, and infrastructure scenarios.",
        ],
      },
    ];

    return jsonResponse({
      success: true,
      brief: {
        stageLabel,
        stageReason,
        focusTags,
        departments,
        generatedAt: new Date().toISOString(),
      },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function toNumber(value: unknown): number {
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}
