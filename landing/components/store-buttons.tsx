import { Apple, Play } from "lucide-react";
import { ButtonLink, Button } from "@uziy/ui";
import type { SiteLinks } from "@/lib/links";

export const COMING_SOON_LABEL = "Удахгүй";

interface StoreButtonProps {
  label: string;
  store: string;
  href: string | null;
  icon: React.ReactNode;
}

/** A live link once the store URL is configured, a disabled 'Удахгүй' button before that. */
function StoreButton({ label, store, href, icon }: StoreButtonProps) {
  const content = (
    <span className="flex flex-col items-start leading-tight">
      <span className="text-[10px] font-medium opacity-70">
        {href ? label : COMING_SOON_LABEL}
      </span>
      <span className="text-sm">{store}</span>
    </span>
  );
  return href ? (
    <ButtonLink
      href={href}
      variant="secondary"
      size="lg"
      className="h-12"
      leftIcon={icon}
    >
      {content}
    </ButtonLink>
  ) : (
    <Button
      variant="secondary"
      size="lg"
      className="h-12"
      leftIcon={icon}
      disabled
    >
      {content}
    </Button>
  );
}

export function StoreButtons({
  links,
}: {
  links: Pick<SiteLinks, "appStore" | "playStore">;
}) {
  return (
    <div className="flex flex-wrap gap-3">
      <StoreButton
        label="Татаж авах"
        store="App Store"
        href={links.appStore}
        icon={<Apple size={20} aria-hidden />}
      />
      <StoreButton
        label="Татаж авах"
        store="Google Play"
        href={links.playStore}
        icon={<Play size={18} aria-hidden />}
      />
    </div>
  );
}
