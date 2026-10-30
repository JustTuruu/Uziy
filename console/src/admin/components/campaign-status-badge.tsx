import { Badge } from "@uziy/ui";
import type { CampaignStatus } from "@admin/lib/api";
import { campaignStatusLabel, campaignStatusTone } from "@admin/lib/campaign-status";

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
