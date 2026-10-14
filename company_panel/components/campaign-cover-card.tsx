"use client";

import { ImageUploadCard } from "@uziy/ui";
import { companyApi, mediaUrl, type Campaign } from "@/lib/api";
import { canEditCover } from "@/lib/campaign-status";

export const COVER_LOCKED_NOTE =
  "Судалгаа батлагдсан тул зургийг өөрчлөх боломжгүй. Өөрчлөх шаардлагатай бол бидэнтэй холбогдоно уу.";

/**
 * The company's cover image for its own survey: editable until the admin
 * approves it, then shown read-only.
 */
export function CampaignCoverCard({
  campaign,
  onSaved,
  className,
}: {
  campaign: Campaign;
  onSaved: (thumbnailUrl: string | null) => void;
  className?: string;
}) {
  const url = campaign.thumbnailUrl;
  return (
    <ImageUploadCard
      className={className}
      inputId={`cover-${campaign.id}`}
      imageUrl={url ? mediaUrl(url) : null}
      lockedNote={canEditCover(campaign.status) ? undefined : COVER_LOCKED_NOTE}
      description="Аппын судалгааны карт дээр харагдах зураг (заавал биш). JPG, PNG · 5 MB хүртэл · 16:9 харьцаа тохиромжтой. Батлагдахаас өмнө сольж болно."
      onUpload={async (file) =>
        onSaved((await companyApi.uploadImage(campaign.id, file)).thumbnailUrl)
      }
      onRemove={async () => {
        await companyApi.removeImage(campaign.id);
        onSaved(null);
      }}
    />
  );
}
