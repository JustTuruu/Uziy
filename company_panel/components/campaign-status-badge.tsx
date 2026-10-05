import { Badge } from "@/components/ui/badge";
import type { CampaignStatus } from "@/lib/api";
import { campaignStatusLabel, campaignStatusTone } from "@/lib/campaign-status";

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
