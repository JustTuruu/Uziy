// GENERATED from docs/api/openapi.json by `pnpm -C packages/api-types generate`. Do not edit.
// The backend rewrites the spec with `./gradlew updateOpenApi`.

export type paths = {
    "/admin/admins": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["list_2"];
        put?: never;
        post: operations["create_2"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/campaigns": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["listCampaigns"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/campaigns/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["getCampaign"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/campaigns/{id}/image": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["upload_1"];
        delete: operations["remove_1"];
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/campaigns/{id}/moderate": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch: operations["moderate"];
        trace?: never;
    };
    "/admin/companies": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["list_1"];
        put?: never;
        post: operations["create_1"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/insights/access-log": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["accessLog"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/insights/overview": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["overview"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/insights/questions": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["questions_1"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/insights/questions/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["distribution"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/insights/questions/{id}/export.csv": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["export"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/insights/questions/{id}/segments": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["segments"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/payouts": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["pending"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/payouts/{id}/decision": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch: operations["decide_1"];
        trace?: never;
    };
    "/admin/payouts/history": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["history_1"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/platform-settings": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch: operations["update"];
        trace?: never;
    };
    "/admin/stats": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["stats"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/users": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["listUsers"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/users/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["getUser"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/users/{id}/trusted-devices/forget": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["forget"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/admin/users/{id}/verify": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch: operations["verify_1"];
        trace?: never;
    };
    "/auth/login": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["login"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/auth/login/verify": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["verify"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/auth/password/reset": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["reset"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/auth/phone-verifications": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["start"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/auth/phone-verifications/{verificationId}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["check_1"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/auth/phone-verifications/simulated-sms/{sessionId}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["receive"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/auth/register/viewer": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["registerViewer"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/company/analytics": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["get_2"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/company/campaigns": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["list"];
        put?: never;
        post: operations["create"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/company/campaigns/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["get_1"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/company/campaigns/{id}/image": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["upload"];
        delete: operations["remove"];
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/company/campaigns/{id}/pay": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["pay"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/company/campaigns/{id}/status": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch: operations["setStatus"];
        trace?: never;
    };
    "/company/payments": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["payments"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/platform-settings": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["get"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/public/campaigns/{id}/image": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["image"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/public/feed": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["feed_1"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/campaigns/{id}/questions": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["questions"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/campaigns/{id}/questions/{questionId}/check": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["check"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/campaigns/{id}/submit": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["submit"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/consents/statistics": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["current"];
        put: operations["decide"];
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/devices": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        post: operations["register"];
        delete: operations["unregister"];
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/feed": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["feed"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/history": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["history"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/me": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["me"];
        put?: never;
        post?: never;
        delete: operations["delete"];
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/me/name": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put: operations["set"];
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/viewer/payouts": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get: operations["mine"];
        put?: never;
        post: operations["request"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
};
export type webhooks = Record<string, never>;
export type components = {
    schemas: {
        AccessLogEntry: {
            action: string;
            adminPhone: string;
            /** Format: date-time */
            at: string;
            detail: string;
            /** Format: int64 */
            id: number;
        };
        AdminAccountDto: {
            /** Format: date-time */
            createdAt: string;
            /** Format: int64 */
            id: number;
            phoneNumber: string;
        };
        AdminStats: {
            /** Format: int64 */
            activeCampaigns: number;
            /** Format: int64 */
            awaitingPaymentCampaigns: number;
            /** Format: int32 */
            commissionPercent: number;
            /** Format: double */
            commissionRate: number;
            /** Format: int64 */
            pendingCampaigns: number;
            /** Format: int64 */
            pendingPayouts: number;
            /** Format: int64 */
            totalCampaigns: number;
            /** Format: int64 */
            totalUsers: number;
        };
        AnalyticsResponse: {
            audience: components["schemas"]["Audience"] | null;
            campaigns: components["schemas"]["CampaignPerformance"][];
            daily: components["schemas"]["DailyViews"][];
            /** Format: int32 */
            days: number;
            questions: components["schemas"]["QuestionBreakdown"][];
            segments: components["schemas"]["SegmentBreakdown"][];
            totals: components["schemas"]["Totals"];
        };
        Answer: {
            answerJson?: string;
            /** Format: int64 */
            questionId?: number;
        };
        Audience: {
            ageBands: components["schemas"]["Slice"][];
            cities: components["schemas"]["Slice"][];
            gender: components["schemas"]["Slice"][];
        };
        AuthResponse: {
            token: string;
            user: components["schemas"]["Me"];
        };
        CampaignDetailDto: {
            campaign: components["schemas"]["CampaignDto"];
            /** Format: int64 */
            companyId: number;
            companyName: string | null;
            /** Format: int64 */
            completedViews: number;
            /** Format: double */
            spentBudget: number;
        };
        CampaignDto: {
            /** Format: int32 */
            commissionPercent: number | null;
            /** Format: double */
            costPerView: number;
            /** Format: date-time */
            createdAt: string;
            /** Format: int32 */
            durationSeconds: number;
            hasVideo: boolean;
            /** Format: int64 */
            id: number;
            /** Format: int32 */
            maxAge: number;
            /** Format: int32 */
            minAge: number;
            /** Format: date-time */
            paidAt: string | null;
            /** Format: double */
            remainingBudget: number;
            /** Format: double */
            rewardPerUser: number;
            /** @enum {string} */
            status: "AWAITING_PAYMENT" | "PENDING" | "ACTIVE" | "PAUSED" | "COMPLETED" | "REJECTED";
            targetCity: string;
            /** @enum {string} */
            targetGender: "ALL" | "MALE" | "FEMALE";
            /** Format: int32 */
            targetViewers: number | null;
            thumbnailUrl: string | null;
            title: string;
            /** Format: double */
            totalBudget: number;
            videoUrl: string;
        };
        CampaignPerformance: {
            /** Format: int64 */
            campaignId: number;
            /** Format: double */
            costPerResponse: number | null;
            /** Format: int32 */
            daysLeft: number | null;
            hasVideo: boolean;
            /** Format: double */
            reachPercent: number | null;
            /** Format: int64 */
            remainingResponses: number;
            /** Format: int64 */
            responses: number;
            /** Format: int64 */
            responsesLast7Days: number;
            /** Format: double */
            rewardsPaid: number;
            /** Format: double */
            spent: number;
            /** @enum {string} */
            status: "AWAITING_PAYMENT" | "PENDING" | "ACTIVE" | "PAUSED" | "COMPLETED" | "REJECTED";
            /** Format: int32 */
            targetViewers: number | null;
            title: string;
        };
        CheckQuizAnswerReq: {
            answer: string;
        };
        CompanyAccountDto: {
            /** Format: int64 */
            campaignCount: number;
            companyName: string;
            /** Format: date-time */
            createdAt: string;
            /** Format: int64 */
            id: number;
            phoneNumber: string;
        };
        ConsoleLoginVerifiedRes: {
            deviceToken: string;
            /** Format: date-time */
            deviceTrustedUntil: string;
            token: string;
            user: components["schemas"]["Me"];
        };
        ConsoleLoginVerifyReq: {
            phoneNumber: string;
            /** Format: uuid */
            verificationId: string;
        };
        CreateAdminReq: {
            password: string;
            phoneNumber: string;
        };
        CreateCampaignReq: {
            /** Format: int32 */
            durationSeconds?: number;
            hasVideo?: boolean;
            /** Format: int32 */
            maxAge?: number;
            /** Format: int32 */
            minAge?: number;
            questions?: components["schemas"]["NewQuestion"][];
            /** Format: double */
            rewardPerUser?: number;
            targetCity?: string;
            /** @enum {string} */
            targetGender?: "ALL" | "MALE" | "FEMALE";
            /** Format: int32 */
            targetViewers?: number;
            title: string;
            /** Format: double */
            totalBudget?: number;
            videoUrl?: string;
        };
        CreateCompanyReq: {
            companyName: string;
            password: string;
            phoneNumber: string;
        };
        CreatePayoutReq: {
            accountName: string;
            accountNumber: string;
            /** Format: double */
            amount?: number;
            bank: string;
        };
        DailyViews: {
            /** Format: date */
            date: string;
            /** Format: int64 */
            responses: number;
        };
        DecideStatisticsConsentReq: {
            granted: boolean;
        };
        DeleteAccountReq: {
            password: string;
        };
        Distribution: {
            filter: components["schemas"]["Filter"];
            /** Format: int64 */
            people: number | null;
            prompt: string;
            /** Format: int64 */
            questionId: number;
            shares: components["schemas"]["OptionShare"][];
            suppressed: boolean;
            type: string;
        };
        FeedItemDto: {
            companyName: string;
            /** Format: int32 */
            durationSeconds: number;
            hasVideo: boolean;
            /** Format: int64 */
            id: number;
            /** Format: double */
            rewardPerUser: number;
            thumbnailUrl: string | null;
            title: string;
            videoUrl: string;
        };
        Filter: {
            ageBand: string | null;
            city: string | null;
            gender: string | null;
        };
        Group: {
            label: string;
            /** Format: int64 */
            people: number | null;
        };
        ImageResponse: {
            thumbnailUrl: string | null;
        };
        LoginReq: {
            deviceToken?: string;
            password: string;
            phoneNumber: string;
        };
        Me: {
            /** Format: int32 */
            age: number | null;
            /** Format: double */
            balance: number;
            city: string | null;
            companyName: string | null;
            district: string | null;
            firstName: string | null;
            /** @enum {string|null} */
            gender: "MALE" | "FEMALE" | null;
            /** Format: int64 */
            id: number;
            isVerified: boolean;
            lastName: string | null;
            phoneNumber: string;
            /** @enum {string} */
            role: "VIEWER" | "COMPANY" | "ADMIN";
        };
        NewQuestion: {
            correctAnswer?: string;
            options?: string[];
            prompt: string;
            required?: boolean;
            type: string;
        };
        OptionBySegment: {
            counts: number[];
            label: string;
        };
        OptionShare: {
            option: string;
            /** Format: int32 */
            percent: number;
        };
        Overview: {
            byAgeBand: components["schemas"]["Group"][];
            byCity: components["schemas"]["Group"][];
            byGender: components["schemas"]["Group"][];
            /** Format: int64 */
            consentingViewers: number;
            /** Format: int32 */
            consentPercent: number;
            /** Format: int32 */
            minGroupSize: number;
            /** Format: int64 */
            reportableQuestions: number;
            /** Format: int64 */
            viewers: number;
        };
        PayCampaignResponse: {
            campaign: components["schemas"]["CampaignDto"];
            payment: components["schemas"]["PaymentDto"];
        };
        PaymentDto: {
            /** Format: double */
            amount: number;
            /** Format: int64 */
            campaignId: number;
            campaignTitle: string;
            /** Format: date-time */
            createdAt: string;
            /** Format: int64 */
            id: number;
            /** Format: date-time */
            paidAt: string | null;
            /** @enum {string} */
            provider: "SIMULATED" | "QPAY" | "BANK_TRANSFER";
            reference: string;
            /** @enum {string} */
            status: "PAID" | "FAILED" | "REFUNDED";
        };
        PayoutDto: {
            accountName: string;
            accountNumber: string;
            /** Format: double */
            amount: number;
            bank: string;
            /** Format: date-time */
            decidedAt: string | null;
            /** Format: int64 */
            id: number;
            isFirstPayout: boolean;
            rejectReason: string | null;
            /** Format: date-time */
            requestedAt: string;
            /** @enum {string} */
            status: "PENDING" | "APPROVED" | "REJECTED";
            /** Format: int64 */
            userId: number;
            userPhone: string;
        };
        PhoneVerificationStartedRes: {
            displayInstruction: string;
            /** Format: date-time */
            expiresAt: string;
            phoneNumber: string;
            shortcode: string;
            smsText: string;
            smsUri: string;
            /** @enum {string} */
            status: "PENDING" | "VERIFIED" | "EXPIRED";
            /** Format: uuid */
            verificationId: string;
        };
        PhoneVerificationStateRes: {
            /** Format: date-time */
            expiresAt: string;
            /** @enum {string} */
            status: "PENDING" | "VERIFIED" | "EXPIRED";
            /** Format: uuid */
            verificationId: string;
        };
        PlatformSettingsDto: {
            /** Format: int32 */
            commissionPercent: number;
            /** Format: int32 */
            minRewardPerViewer: number;
            /** Format: int32 */
            surveyCommissionPercent: number;
            /** Format: date-time */
            updatedAt: string;
        };
        QuestionBreakdown: {
            /** Format: int64 */
            answered: number;
            options: components["schemas"]["Slice"][];
            prompt: string;
            /** Format: int64 */
            questionId: number;
            type: string;
        };
        QuestionDto: {
            /** Format: int64 */
            id: number;
            options: string[];
            /** Format: int32 */
            position: number;
            prompt: string;
            required: boolean;
            type: string;
        };
        QuestionSummary: {
            companyName: string;
            prompt: string;
            /** Format: int64 */
            questionId: number;
            reportable: boolean;
            /** Format: int64 */
            respondents: number;
            surveyTitle: string;
            type: string;
        };
        QuizCheckResult: {
            correct: boolean;
        };
        RegisterDeviceReq: {
            /** @enum {string} */
            platform: "ANDROID" | "IOS";
            token: string;
        };
        RegisterViewerReq: {
            /** Format: date */
            birthDate: string;
            city: string;
            district?: string;
            firstName: string;
            /** @enum {string} */
            gender: "MALE" | "FEMALE";
            lastName: string;
            password: string;
            phoneNumber?: string;
            /** Format: uuid */
            verificationId: string;
        };
        ResetPasswordReq: {
            newPassword: string;
            phoneNumber: string;
            /** Format: uuid */
            verificationId: string;
        };
        RewardResult: {
            /** Format: double */
            newBalance: number;
            /** Format: double */
            rewardPaid: number;
        };
        SegmentBreakdown: {
            options: components["schemas"]["OptionBySegment"][];
            prompt: string;
            /** Format: int64 */
            questionId: number;
            segments: components["schemas"]["Slice"][];
        };
        SegmentRow: {
            dimension: string;
            label: string;
            /** Format: int64 */
            people: number | null;
            shares: components["schemas"]["OptionShare"][];
            suppressed: boolean;
        };
        Segments: {
            options: string[];
            prompt: string;
            /** Format: int64 */
            questionId: number;
            rows: components["schemas"]["SegmentRow"][];
        };
        SetViewerNameReq: {
            firstName: string;
            lastName: string;
        };
        Slice: {
            /** Format: int64 */
            count: number;
            label: string;
        };
        StartPhoneVerificationReq: {
            phoneNumber: string;
            /** @enum {string} */
            purpose?: "REGISTER" | "PASSWORD_RESET" | "ADMIN_LOGIN" | "COMPANY_LOGIN";
        };
        StatisticsConsentDto: {
            /** Format: date-time */
            decidedAt: string | null;
            /** @enum {string} */
            status: "UNASKED" | "GRANTED" | "DECLINED";
            version: string;
        };
        SubmitSurveyReq: {
            answers: components["schemas"]["Answer"][];
        };
        Totals: {
            /** Format: int32 */
            activeCount: number;
            /** Format: int32 */
            campaignCount: number;
            /** Format: double */
            costPerResponse: number | null;
            /** Format: int64 */
            responses: number;
            /** Format: double */
            rewardsPaid: number;
            /** Format: double */
            spent: number;
        };
        UpdatePlatformSettingsReq: {
            /** Format: int32 */
            commissionPercent?: number;
            /** Format: int32 */
            minRewardPerViewer?: number;
            /** Format: int32 */
            surveyCommissionPercent?: number;
        };
        UserDto: {
            /** Format: int32 */
            age: number | null;
            /** Format: double */
            balance: number;
            city: string | null;
            companyName: string | null;
            /** Format: date-time */
            createdAt: string;
            /** @enum {string|null} */
            gender: "MALE" | "FEMALE" | null;
            /** Format: int64 */
            id: number;
            isVerified: boolean;
            phoneNumber: string;
            /** @enum {string} */
            role: "VIEWER" | "COMPANY" | "ADMIN";
        };
        ViewHistoryItemDto: {
            /** Format: int64 */
            campaignId: number;
            companyName: string;
            /** Format: double */
            rewardPaid: number;
            title: string;
            /** Format: date-time */
            watchedAt: string;
        };
    };
    responses: never;
    parameters: never;
    requestBodies: never;
    headers: never;
    pathItems: never;
};
export type $defs = Record<string, never>;
export interface operations {
    list_2: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["AdminAccountDto"][];
                };
            };
        };
    };
    create_2: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["CreateAdminReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["AdminAccountDto"];
                };
            };
        };
    };
    listCampaigns: {
        parameters: {
            query?: {
                companyId?: number;
                status?: "AWAITING_PAYMENT" | "PENDING" | "ACTIVE" | "PAUSED" | "COMPLETED" | "REJECTED";
            };
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDto"][];
                };
            };
        };
    };
    getCampaign: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDetailDto"];
                };
            };
        };
    };
    upload_1: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "multipart/form-data": {
                    /** Format: binary */
                    file: string;
                };
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["ImageResponse"];
                };
            };
        };
    };
    remove_1: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["ImageResponse"];
                };
            };
        };
    };
    moderate: {
        parameters: {
            query: {
                commissionPercent?: number;
                decision: "AWAITING_PAYMENT" | "PENDING" | "ACTIVE" | "PAUSED" | "COMPLETED" | "REJECTED";
            };
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDto"];
                };
            };
        };
    };
    list_1: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CompanyAccountDto"][];
                };
            };
        };
    };
    create_1: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["CreateCompanyReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CompanyAccountDto"];
                };
            };
        };
    };
    accessLog: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["AccessLogEntry"][];
                };
            };
        };
    };
    overview: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["Overview"];
                };
            };
        };
    };
    questions_1: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["QuestionSummary"][];
                };
            };
        };
    };
    distribution: {
        parameters: {
            query?: {
                ageBand?: string;
                city?: string;
                gender?: string;
            };
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["Distribution"];
                };
            };
        };
    };
    export: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": string;
                };
            };
        };
    };
    segments: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["Segments"];
                };
            };
        };
    };
    pending: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PayoutDto"][];
                };
            };
        };
    };
    decide_1: {
        parameters: {
            query: {
                decision: "PENDING" | "APPROVED" | "REJECTED";
                reason?: string;
            };
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PayoutDto"];
                };
            };
        };
    };
    history_1: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PayoutDto"][];
                };
            };
        };
    };
    update: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["UpdatePlatformSettingsReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PlatformSettingsDto"];
                };
            };
        };
    };
    stats: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["AdminStats"];
                };
            };
        };
    };
    listUsers: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["UserDto"][];
                };
            };
        };
    };
    getUser: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["UserDto"];
                };
            };
        };
    };
    forget: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content?: never;
            };
        };
    };
    verify_1: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["UserDto"];
                };
            };
        };
    };
    login: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["LoginReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": Record<string, never>;
                };
            };
        };
    };
    verify: {
        parameters: {
            query?: never;
            header?: {
                "User-Agent"?: string;
            };
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["ConsoleLoginVerifyReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["ConsoleLoginVerifiedRes"];
                };
            };
        };
    };
    reset: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["ResetPasswordReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content?: never;
            };
        };
    };
    start: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["StartPhoneVerificationReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PhoneVerificationStartedRes"];
                };
            };
        };
    };
    check_1: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                verificationId: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PhoneVerificationStateRes"];
                };
            };
        };
    };
    receive: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                sessionId: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content?: never;
            };
        };
    };
    registerViewer: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["RegisterViewerReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["AuthResponse"];
                };
            };
        };
    };
    get_2: {
        parameters: {
            query?: {
                campaignId?: number;
                days?: number;
            };
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["AnalyticsResponse"];
                };
            };
        };
    };
    list: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDto"][];
                };
            };
        };
    };
    create: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["CreateCampaignReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDto"];
                };
            };
        };
    };
    get_1: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDto"];
                };
            };
        };
    };
    upload: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "multipart/form-data": {
                    /** Format: binary */
                    file: string;
                };
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["ImageResponse"];
                };
            };
        };
    };
    remove: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["ImageResponse"];
                };
            };
        };
    };
    pay: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PayCampaignResponse"];
                };
            };
        };
    };
    setStatus: {
        parameters: {
            query: {
                status: "AWAITING_PAYMENT" | "PENDING" | "ACTIVE" | "PAUSED" | "COMPLETED" | "REJECTED";
            };
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["CampaignDto"];
                };
            };
        };
    };
    payments: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PaymentDto"][];
                };
            };
        };
    };
    get: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PlatformSettingsDto"];
                };
            };
        };
    };
    image: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": string;
                };
            };
        };
    };
    feed_1: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["FeedItemDto"][];
                };
            };
        };
    };
    questions: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["QuestionDto"][];
                };
            };
        };
    };
    check: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
                questionId: number;
            };
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["CheckQuizAnswerReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["QuizCheckResult"];
                };
            };
        };
    };
    submit: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: number;
            };
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["SubmitSurveyReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["RewardResult"];
                };
            };
        };
    };
    current: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["StatisticsConsentDto"];
                };
            };
        };
    };
    decide: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["DecideStatisticsConsentReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["StatisticsConsentDto"];
                };
            };
        };
    };
    register: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["RegisterDeviceReq"];
            };
        };
        responses: {
            /** @description No Content */
            204: {
                headers: {
                    [name: string]: unknown;
                };
                content?: never;
            };
        };
    };
    unregister: {
        parameters: {
            query: {
                token: string;
            };
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description No Content */
            204: {
                headers: {
                    [name: string]: unknown;
                };
                content?: never;
            };
        };
    };
    feed: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["FeedItemDto"][];
                };
            };
        };
    };
    history: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["ViewHistoryItemDto"][];
                };
            };
        };
    };
    me: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["Me"];
                };
            };
        };
    };
    delete: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["DeleteAccountReq"];
            };
        };
        responses: {
            /** @description No Content */
            204: {
                headers: {
                    [name: string]: unknown;
                };
                content?: never;
            };
        };
    };
    set: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["SetViewerNameReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["Me"];
                };
            };
        };
    };
    mine: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PayoutDto"][];
                };
            };
        };
    };
    request: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["CreatePayoutReq"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "*/*": components["schemas"]["PayoutDto"];
                };
            };
        };
    };
}
