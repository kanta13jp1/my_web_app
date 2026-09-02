import type {
  NormalizedXPostMetrics,
  XMetricWindowSample,
} from "./x_metric_windows.ts";

export const FIRST_USER_FUNNEL_STAGES = [
  "view",
  "trial",
  "signup_submit",
  "signup_complete",
  "first_action_completed",
  "billing_view",
  "supporter_checkout",
] as const;

export type FirstUserFunnelStage = typeof FIRST_USER_FUNNEL_STAGES[number];

export type FirstUserAcquisitionEvent = {
  visitor_id: string;
  stage: string;
  first_occurred_at: string;
};

export type FirstUserPayment = {
  amountJpy: number;
  createdAt: string;
};

export type FirstUserXPost = {
  sourceLogId: string;
  tweetId: string;
  postedAt: string;
  latestImpressions: number | null;
  latestUrlClicks: number | null;
  normalized: NormalizedXPostMetrics | null;
};

type FirstUserFunnelInput = {
  utmSource: string;
  utmMedium: string;
  utmContent: string;
  campaignStartedAt?: string | null;
  post: FirstUserXPost | null;
  events: readonly FirstUserAcquisitionEvent[];
  payments: readonly FirstUserPayment[];
  nowMs?: number;
};

const countUnique = (
  events: readonly FirstUserAcquisitionEvent[],
  stage: FirstUserFunnelStage,
): number =>
  new Set(
    events
      .filter((event) => event.stage === stage)
      .map((event) => event.visitor_id),
  ).size;

const rate = (numerator: number, denominator: number): number | null =>
  denominator > 0 ? Number((numerator / denominator).toFixed(4)) : null;

function latestWindow(post: FirstUserXPost | null): {
  key: "i3h" | "i24h" | "latest" | null;
  label: string | null;
  impressions: number | null;
  sample: XMetricWindowSample | null;
} {
  if (!post) {
    return { key: null, label: null, impressions: null, sample: null };
  }
  const normalized = post.normalized;
  if (normalized?.i24h !== null && normalized?.i24h !== undefined) {
    return {
      key: "i24h",
      label: "24h",
      impressions: normalized.i24h,
      sample: normalized.windows.i24h,
    };
  }
  if (normalized?.i3h !== null && normalized?.i3h !== undefined) {
    return {
      key: "i3h",
      label: "3h",
      impressions: normalized.i3h,
      sample: normalized.windows.i3h,
    };
  }
  return {
    key: "latest",
    label: "latest",
    impressions: post.latestImpressions,
    sample: null,
  };
}

function decision(
  utmSource: string,
  campaignStarted: boolean,
  post: FirstUserXPost | null,
  ageHours: number | null,
  impressions: number | null,
  urlClicks: number,
  counts: Record<FirstUserFunnelStage, number>,
  paidPayments: number,
): {
  stage: string;
  nextVariable: string;
  nextAction: string;
} {
  if (!post && !campaignStarted) {
    return {
      stage: "awaiting_publish",
      nextVariable: "publish",
      nextAction:
        "Obtain explicit owner approval, publish the prepared X candidate once, and keep every other variable fixed.",
    };
  }
  if (utmSource === "x" && (ageHours ?? 0) < 3) {
    return {
      stage: "collecting_3h",
      nextVariable: "none",
      nextAction:
        "Keep the post unchanged until the first comparable 3-hour X window is available.",
    };
  }
  if (
    utmSource !== "x" &&
    (ageHours ?? 0) < 24 &&
    counts.view === 0
  ) {
    return {
      stage: "collecting_24h",
      nextVariable: "none",
      nextAction:
        "Keep the published article and measured CTA unchanged until the 24-hour organic acquisition window is available.",
    };
  }
  if (utmSource === "x" && (impressions ?? 0) < 100) {
    return {
      stage: "reach_bottleneck",
      nextVariable: "hook",
      nextAction:
        "For the next approved post, change only the opening hook and retain the image, CTA, and landing URL.",
    };
  }
  if (utmSource !== "x" && counts.view === 0) {
    return {
      stage: "reach_bottleneck",
      nextVariable: "article_distribution",
      nextAction:
        "Change only the article distribution surface or headline while preserving the CTA and landing URL.",
    };
  }
  if (utmSource === "x" && urlClicks === 0 && counts.view === 0) {
    return {
      stage: "click_bottleneck",
      nextVariable: "link_placement",
      nextAction:
        "For the next approved post, change only link placement and keep the hook, image, and offer unchanged.",
    };
  }
  if (counts.view > 0 && counts.trial === 0) {
    return {
      stage: "trial_bottleneck",
      nextVariable: "trial_prompt",
      nextAction:
        "Change only the above-the-fold trial prompt; preserve the campaign post and signup flow.",
    };
  }
  if (counts.trial > 0 && counts.signup_submit === 0) {
    return {
      stage: "signup_submit_bottleneck",
      nextVariable: "signup_cta",
      nextAction:
        "Change only the save-and-register CTA copy after the trial result.",
    };
  }
  if (counts.signup_submit > 0 && counts.signup_complete === 0) {
    return {
      stage: "signup_completion_bottleneck",
      nextVariable: "magic_link_handoff",
      nextAction:
        "Change only the Magic Link completion handoff and inbox guidance.",
    };
  }
  if (
    counts.signup_complete > 0 &&
    counts.first_action_completed === 0
  ) {
    return {
      stage: "activation_bottleneck",
      nextVariable: "trial_carryover",
      nextAction:
        "Change only the trial-to-onboarding carryover so the saved result becomes the first action.",
    };
  }
  if (
    counts.first_action_completed > 0 &&
    counts.supporter_checkout === 0
  ) {
    return {
      stage: "checkout_bottleneck",
      nextVariable: "support_offer",
      nextAction:
        "Change only the supporter offer framing shown after first value.",
    };
  }
  if (counts.supporter_checkout > 0 && paidPayments === 0) {
    return {
      stage: "payment_bottleneck",
      nextVariable: "checkout_trust",
      nextAction:
        "Change only the checkout trust cue; keep price, product value, and traffic source fixed.",
    };
  }
  if (paidPayments > 0) {
    return {
      stage: "payment_received",
      nextVariable: "bank_payout_verification",
      nextAction:
        "Keep the winning acquisition path unchanged and verify at least JPY 1 in the linked bank account.",
    };
  }
  return {
    stage: "collecting_funnel",
    nextVariable: "none",
    nextAction:
      "Collect more unique-user funnel evidence before changing the campaign.",
  };
}

export function buildFirstUserFunnelReport(
  input: FirstUserFunnelInput,
): Record<string, unknown> {
  const counts = Object.fromEntries(
    FIRST_USER_FUNNEL_STAGES.map((stage) => [
      stage,
      countUnique(input.events, stage),
    ]),
  ) as Record<FirstUserFunnelStage, number>;
  const campaignStartedAt = input.post?.postedAt ?? input.campaignStartedAt ??
    null;
  const postDateMs = campaignStartedAt
    ? Date.parse(campaignStartedAt)
    : Number.NaN;
  const nowMs = input.nowMs ?? Date.now();
  const ageHours = Number.isFinite(postDateMs)
    ? Number(((nowMs - postDateMs) / 3_600_000).toFixed(2))
    : null;
  const window = latestWindow(input.post);
  const urlClicks = window.sample?.urlClicks ??
    input.post?.latestUrlClicks ??
    0;
  const revenueJpy = input.payments.reduce(
    (sum, payment) => sum + Math.max(0, payment.amountJpy),
    0,
  );
  const next = decision(
    input.utmSource,
    campaignStartedAt !== null && Number.isFinite(postDateMs),
    input.post,
    ageHours,
    window.impressions,
    urlClicks,
    counts,
    input.payments.length,
  );

  return {
    success: true,
    target: {
      unknownUserSignupCompletes: 1,
      firstRevenueJpy: 1,
      xImpressionsPerPost: input.utmSource === "x" ? 10000 : null,
    },
    attribution: {
      utmSource: input.utmSource,
      utmMedium: input.utmMedium,
      utmCampaign: "first_user_growth",
      utmContent: input.utmContent,
    },
    campaign: {
      source: input.utmSource,
      startedAt: campaignStartedAt,
      ageHours,
    },
    x: input.post
      ? {
        sourceLogId: input.post.sourceLogId,
        tweetId: input.post.tweetId,
        postedAt: input.post.postedAt,
        ageHours,
        metricWindow: window.key,
        metricWindowLabel: window.label,
        impressions: window.impressions,
        urlClicks,
        profileClicks: window.sample?.profileClicks ?? null,
        engagements: window.sample?.engagements ?? null,
      }
      : null,
    funnel: {
      counts,
      rates: {
        trialPerView: rate(counts.trial, counts.view),
        signupSubmitPerTrial: rate(counts.signup_submit, counts.trial),
        signupCompletePerSubmit: rate(
          counts.signup_complete,
          counts.signup_submit,
        ),
        firstActionPerSignup: rate(
          counts.first_action_completed,
          counts.signup_complete,
        ),
        checkoutPerFirstAction: rate(
          counts.supporter_checkout,
          counts.first_action_completed,
        ),
        paidPerCheckout: rate(
          input.payments.length,
          counts.supporter_checkout,
        ),
      },
    },
    revenue: {
      paidPayments: input.payments.length,
      revenueJpy,
    },
    decision: next,
    privacy: {
      aggregateOnly: true,
      containsEmail: false,
      containsName: false,
      containsPromptText: false,
      containsRawVisitorIds: false,
    },
    paymentCaptured: revenueJpy >= 1,
    bankPayoutVerified: false,
    sessionGoalComplete: false,
  };
}
