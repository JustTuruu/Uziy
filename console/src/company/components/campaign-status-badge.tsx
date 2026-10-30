import { Badge } from "@uziy/ui";
import type { CampaignStatus } from "@company/lib/api";
import { campaignStatusLabel, campaignStatusTone } from "@company/lib/campaign-status";

export function CampaignStatusBadge({
  status,
  className,
}: {
  status: CampaignStatus;
  className?: string;
}) {
  return (
    <Badge tone={campaignStatusTone(status)} className={className}>
      {campaignStatusLabel(status)}
    </Badge>
  );
}
