import { ImageUploadCard } from "@uziy/ui";
import { adminApi, mediaUrl } from "@admin/lib/api";

/** The admin's cover editor for any survey: the shared card wired to the admin routes. */
export function CampaignImageEditor({
  campaignId,
  thumbnailUrl,
  onSaved,
}: {
  campaignId: number;
  thumbnailUrl?: string | null;
  onSaved: (url: string | null) => void;
}) {
  return (
    <ImageUploadCard
      className="mt-6"
      inputId={`cover-${campaignId}`}
      imageUrl={thumbnailUrl ? mediaUrl(thumbnailUrl) : null}
      onUpload={async (file) =>
        onSaved((await adminApi.uploadImage(campaignId, file)).thumbnailUrl)
      }
      onRemove={async () => {
        await adminApi.removeImage(campaignId);
        onSaved(null);
      }}
    />
  );
}
