import type { Schema } from "@uziy/api-types";
import type { Me } from "../api/types";

// Pattern: Builder — every test starts from one complete, valid API shape and overrides only what it is about.
// A field the backend adds then needs a default here, not in every test.

export function aMe(over: Partial<Me> = {}): Me {
  return {
    id: 1,
    phoneNumber: "99112233",
    role: "COMPANY",
    gender: null,
    age: null,
    city: null,
    district: null,
    balance: 0,
    isVerified: true,
    companyName: "MobiCom",
    lastName: null,
    firstName: null,
    ...over,
  };
}

export function aCampaign(over: Partial<Schema<"CampaignDto">> = {}): Schema<"CampaignDto"> {
  return {
    id: 1,
    title: "Шинэ 5G багц",
    videoUrl: "https://cdn.example/v.mp4",
    durationSeconds: 30,
    hasVideo: true,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "ALL",
    totalBudget: 1_000_000,
    remainingBudget: 1_000_000,
    costPerView: 1_000,
    rewardPerUser: 700,
    targetViewers: 1_000,
    commissionPercent: 30,
    paidAt: null,
    status: "ACTIVE",
    createdAt: "2026-10-01T00:00:00Z",
    thumbnailUrl: null,
    ...over,
  };
}
