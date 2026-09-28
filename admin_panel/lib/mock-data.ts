// Mock data used by every page until the Spring Boot backend is wired.
// Shapes should mirror the DB schema in docs/SPEC.md §3.

export type CampaignStatus = "ACTIVE" | "PAUSED" | "COMPLETED" | "PENDING";
export type PayoutStatus = "PENDING" | "APPROVED" | "REJECTED";

export interface Campaign {
  id: number;
  companyId: number;
  companyName: string;
  title: string;
  status: CampaignStatus;
  videoUrl: string;
  durationSeconds: number;
  targetGender: "ALL" | "MALE" | "FEMALE";
  minAge: number;
  maxAge: number;
  targetCity: string;
  totalBudget: number;
  remainingBudget: number;
  costPerView: number;
  rewardPerUser: number;
  views: number;
  completions: number;
  createdAt: string;
}

export interface User {
  id: number;
  phoneNumber: string;
  role: "VIEWER" | "COMPANY" | "ADMIN";
  gender?: "MALE" | "FEMALE";
  age?: number;
  city?: string;
  balance: number;
  isVerified: boolean;
  createdAt: string;
}

export interface Payout {
  id: number;
  userId: number;
  userPhone: string;
  amount: number;
  bank: string;
  accountNumber: string;
  accountName: string;
  nationalId: string;
  status: PayoutStatus;
  isFirstPayout: boolean;
  requestedAt: string;
}

export interface SurveyResponse {
  campaignId: number;
  questionId: number;
  prompt: string;
  breakdown: { label: string; count: number }[];
}

// ---------------------------------------------------------------------------

export const mockCampaigns: Campaign[] = [
  {
    id: 1,
    companyId: 100,
    companyName: "MobiCom",
    title: "Шинэ 5G багц - Танд хамгийн тохирсон",
    status: "ACTIVE",
    videoUrl: "",
    durationSeconds: 45,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "Улаанбаатар",
    totalBudget: 5_000_000,
    remainingBudget: 3_200_000,
    costPerView: 1000,
    rewardPerUser: 700,
    views: 1800,
    completions: 1620,
    createdAt: "2026-09-20T10:00:00Z",
  },
  {
    id: 2,
    companyId: 101,
    companyName: "Golomt Bank",
    title: "Оюутны зээл 0% хүүтэй",
    status: "ACTIVE",
    videoUrl: "",
    durationSeconds: 60,
    targetGender: "ALL",
    minAge: 17,
    maxAge: 24,
    targetCity: "Улаанбаатар",
    totalBudget: 3_000_000,
    remainingBudget: 1_450_000,
    costPerView: 800,
    rewardPerUser: 500,
    views: 1937,
    completions: 1780,
    createdAt: "2026-09-22T14:30:00Z",
  },
  {
    id: 3,
    companyId: 102,
    companyName: "UniTel",
    title: "Интернэт багцын шинэ хямдрал",
    status: "PAUSED",
    videoUrl: "",
    durationSeconds: 30,
    targetGender: "ALL",
    minAge: 20,
    maxAge: 60,
    targetCity: "ALL",
    totalBudget: 2_000_000,
    remainingBudget: 640_000,
    costPerView: 900,
    rewardPerUser: 600,
    views: 1511,
    completions: 1290,
    createdAt: "2026-09-15T09:15:00Z",
  },
  {
    id: 4,
    companyId: 100,
    companyName: "MobiCom",
    title: "Гэр бүлийн багц - Дуудлага чөлөөтэй",
    status: "PENDING",
    videoUrl: "",
    durationSeconds: 40,
    targetGender: "ALL",
    minAge: 25,
    maxAge: 55,
    targetCity: "Улаанбаатар",
    totalBudget: 4_000_000,
    remainingBudget: 4_000_000,
    costPerView: 1200,
    rewardPerUser: 800,
    views: 0,
    completions: 0,
    createdAt: "2026-09-27T18:45:00Z",
  },
  {
    id: 5,
    companyId: 103,
    companyName: "Khan Bank",
    title: "Дижитал банк - Апп татаж 5000₮ ав",
    status: "COMPLETED",
    videoUrl: "",
    durationSeconds: 50,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 60,
    targetCity: "ALL",
    totalBudget: 8_000_000,
    remainingBudget: 0,
    costPerView: 1100,
    rewardPerUser: 700,
    views: 7272,
    completions: 6980,
    createdAt: "2026-08-30T11:20:00Z",
  },
];

export const mockUsers: User[] = [
  {
    id: 1001,
    phoneNumber: "+976 8811 2233",
    role: "VIEWER",
    gender: "MALE",
    age: 24,
    city: "Улаанбаатар",
    balance: 3400,
    isVerified: true,
    createdAt: "2026-08-14T09:00:00Z",
  },
  {
    id: 1002,
    phoneNumber: "+976 9911 4455",
    role: "VIEWER",
    gender: "FEMALE",
    age: 29,
    city: "Улаанбаатар",
    balance: 8200,
    isVerified: true,
    createdAt: "2026-07-21T12:00:00Z",
  },
  {
    id: 1003,
    phoneNumber: "+976 8877 1122",
    role: "VIEWER",
    gender: "MALE",
    age: 19,
    city: "Дархан",
    balance: 1200,
    isVerified: false,
    createdAt: "2026-09-25T15:30:00Z",
  },
  {
    id: 1004,
    phoneNumber: "+976 9955 6677",
    role: "VIEWER",
    gender: "FEMALE",
    age: 34,
    city: "Эрдэнэт",
    balance: 15600,
    isVerified: true,
    createdAt: "2026-06-11T08:15:00Z",
  },
  {
    id: 1005,
    phoneNumber: "+976 8899 7766",
    role: "VIEWER",
    gender: "MALE",
    age: 41,
    city: "Улаанбаатар",
    balance: 2100,
    isVerified: false,
    createdAt: "2026-09-27T20:10:00Z",
  },
];

export const mockPayouts: Payout[] = [
  {
    id: 5001,
    userId: 1003,
    userPhone: "+976 8877 1122",
    amount: 5000,
    bank: "Khan Bank",
    accountNumber: "5001234567",
    accountName: "БОЛД-ЭРДЭНЭ БАТ",
    nationalId: "УУ98761234",
    status: "PENDING",
    isFirstPayout: true,
    requestedAt: "2026-09-28T13:22:00Z",
  },
  {
    id: 5002,
    userId: 1002,
    userPhone: "+976 9911 4455",
    amount: 12000,
    bank: "Golomt Bank",
    accountNumber: "1401998877",
    accountName: "САРАНГЭРЭЛ ДОРЖ",
    nationalId: "УБ98871234",
    status: "PENDING",
    isFirstPayout: false,
    requestedAt: "2026-09-28T10:05:00Z",
  },
  {
    id: 5003,
    userId: 1005,
    userPhone: "+976 8899 7766",
    amount: 2000,
    bank: "TDB",
    accountNumber: "4009887766",
    accountName: "МӨНХБАТ ПҮРЭВ",
    nationalId: "УА85451122",
    status: "PENDING",
    isFirstPayout: true,
    requestedAt: "2026-09-28T09:44:00Z",
  },
  {
    id: 5004,
    userId: 1001,
    userPhone: "+976 8811 2233",
    amount: 3000,
    bank: "Xac Bank",
    accountNumber: "5100112233",
    accountName: "ТӨРБАТ БОЛД",
    nationalId: "УБ01121234",
    status: "APPROVED",
    isFirstPayout: false,
    requestedAt: "2026-09-25T18:30:00Z",
  },
];

export const mockSurveyResponses: SurveyResponse[] = [
  {
    campaignId: 1,
    questionId: 1,
    prompt: "Энэ реклам танд сонирхолтой санагдсан уу?",
    breakdown: [
      { label: "Тийм", count: 980 },
      { label: "Дунд зэрэг", count: 480 },
      { label: "Үгүй", count: 160 },
    ],
  },
  {
    campaignId: 1,
    questionId: 2,
    prompt: "Та энэ бүтээгдэхүүнийг өмнө нь ашиглаж байсан уу?",
    breakdown: [
      { label: "Тогтмол ашигладаг", count: 640 },
      { label: "Хааяа", count: 720 },
      { label: "Үгүй", count: 260 },
    ],
  },
];

// ---------------------------------------------------------------------------

export const platformStats = {
  totalUsers: 24_580,
  activeUsers7d: 8_912,
  totalCampaigns: 147,
  activeCampaigns: 38,
  totalGmv: 128_450_000, // ₮ paid by companies all-time
  commissionRate: 0.35,
  pendingPayouts: 3,
  pendingCampaigns: 5,
};

export const companyStats = {
  activeCampaigns: 2,
  totalSpent: 5_290_000,
  totalReach: 3_290,
  avgCompletionRate: 0.92,
  accountBalance: 1_800_000,
};
